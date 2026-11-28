import 'dart:async';
import 'dart:developer' as developer;
import 'dart:io';
import 'dart:math';

import '../../app/network/api_client.dart';
import '../../core/isolates/photo_compressor.dart';
import '../data_sources/local/outbox_store.dart';
import '../entities/pending_items.dart';
import '../repositories/connectivity_repository.dart';
import '../repositories/mobile_data_preference_repository.dart';

/// Sends one queued item to the server. Throws [NetworkException] / [ApiException] like the
/// remote data sources, so the sync service can tell "try later" from "refused".
abstract class OutboxSender {
  /// `POST /uploads` for one photo file; returns its URL on the server.
  Future<String> uploadPhoto(String path);

  /// `POST /materials`: [body] already has the `imageUrls` of the uploaded photos.
  Future<void> createListing(Map<String, dynamic> body);

  Future<void> sendMessage(PendingMessage message);
  Future<void> sendAction(PendingAction action);
}

/// Resolves a proposal that may have reached the server before its time passed.
abstract interface class MeetingProposalLookup implements OutboxSender {
  Future<bool> wasMeetingProposalDelivered(PendingAction action);
}

/// The action depends on a change by the other participant and is still valid.
class OutboxActionDeferred implements Exception {
  const OutboxActionDeferred();
}

/// How one delivery attempt ended.
enum SyncOutcome {
  /// Confirmed by the server; removed from the outbox.
  sent,

  /// No network, a 5xx or an expired session: it stays queued and the flush stops.
  retryLater,
  deferred,

  /// The server refused it (4xx): kept with the server's reason until the user discards it.
  refused,
}

/// Flushes the signed-in user's outbox:
/// - when the connection returns, when the app comes back to the foreground ([flush]) and on a
///   retry timer with exponential backoff while something is still waiting;
/// - one flush at a time: a second trigger while flushing waits for the running one;
/// - respects `allow_mobile_data` when [transport] and [mobileDataPreference] are provided, pausing
///   auto-sync on cellular connections unless [flush] is called with `overMobileData: true`;
/// - listings first (one `POST /uploads` per photo that is not on the server yet, then one
///   `POST /materials`), then messages, oldest first. A refused message holds back the later
///   messages of the same conversation, so they never arrive out of order;
/// - exchange steps last, the same way per exchange: a rating never goes before its completion.
///   A meeting proposal whose time has passed is refused on the phone instead of being sent.
class OutboxSyncService {
  final OutboxStore store;
  final OutboxSender sender;
  final ConnectivityRepository connectivity;
  final NetworkTransportRepository? transport;
  final MobileDataPreferenceRepository? mobileDataPreference;

  /// First retry delay; it doubles after every flush that could not deliver everything.
  final Duration baseRetryDelay;
  final Duration maxRetryDelay;
  final DateTime Function() _now;

  OutboxSyncService({
    required this.store,
    required this.sender,
    required this.connectivity,
    this.transport,
    this.mobileDataPreference,
    this.baseRetryDelay = const Duration(seconds: 5),
    this.maxRetryDelay = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  String? _ownerId;
  int _session = 0;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<NetworkTransport>? _transportSubscription;
  StreamSubscription<void>? _storeChangesSubscription;
  Completer<void>? _running;
  Timer? _retryTimer;
  int _failedFlushes = 0;

  /// A trigger arrived during a flush (e.g. a new item was queued): flush once more after it.
  bool _flushAgain = false;
  bool _flushAgainOverMobileData = false;
  bool _connectionChangedWhileFlushing = false;

  bool _waitingForWifi = false;
  final StreamController<bool> _waitingForWifiController = StreamController<bool>.broadcast();

  bool get isFlushing => _running != null;

  /// Whether an automatic retry is scheduled.
  bool get retryScheduled => _retryTimer != null;

  /// Whether queued outbox work is paused because only mobile data is available and
  /// `allow_mobile_data` is turned off.
  bool get isWaitingForWifi => _waitingForWifi;

  Stream<bool> get waitingForWifiStream => _waitingForWifiController.stream;

  void _setWaitingForWifi(bool value) {
    if (_waitingForWifi == value) return;
    _waitingForWifi = value;
    if (!_waitingForWifiController.isClosed) {
      _waitingForWifiController.add(value);
    }
  }

  /// Starts syncing [ownerId]'s outbox (on login or session restore) and flushes once.
  void start(String ownerId) {
    if (_ownerId != ownerId) stop();
    _ownerId = ownerId;
    _connectivitySubscription ??= connectivity.watch().listen((online) {
      if (online) {
        _flushAfterConnectionChange();
      } else {
        _setWaitingForWifi(false);
      }
    }, onError: (_) {});
    final netTransport = transport;
    if (netTransport != null) {
      _transportSubscription ??= netTransport.watchTransport().listen((kind) {
        if (kind == NetworkTransport.wifi) {
          _setWaitingForWifi(false);
          _flushAfterConnectionChange();
        } else if (kind == NetworkTransport.none) {
          _setWaitingForWifi(false);
        } else {
          _flushAfterConnectionChange();
        }
      }, onError: (_) {});
    }
    _storeChangesSubscription ??= store.changes.listen((_) {
      _refreshWaitingState();
    }, onError: (_) {});
    flush();
  }

  /// Stops syncing (on logout). Queued rows stay: they belong to that user and are sent the next
  /// time they sign in on this phone.
  void stop() {
    _session++;
    _ownerId = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _transportSubscription?.cancel();
    _transportSubscription = null;
    _storeChangesSubscription?.cancel();
    _storeChangesSubscription = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _failedFlushes = 0;
    _flushAgain = false;
    _flushAgainOverMobileData = false;
    _connectionChangedWhileFlushing = false;
    _setWaitingForWifi(false);
  }

  Future<void> _refreshWaitingState() async {
    final ownerId = _ownerId;
    if (ownerId == null || _running != null) return;
    final session = _session;
    final waiting = await _hasDeliverableWaitingItems(ownerId) &&
        await _isBlockedOnMobileData();
    if (session == _session && _running == null) _setWaitingForWifi(waiting);
  }

  Future<bool> _hasDeliverableWaitingItems(String ownerId) async {
    final listings = await store.listings(ownerId);
    if (listings.any((l) => l.status == PendingStatus.waiting)) return true;

    final messages = await store.messages(ownerId);
    final heldRooms = <String>{};
    for (final m in messages) {
      if (heldRooms.contains(m.chatRoomId)) continue;
      if (m.status == PendingStatus.refused) {
        heldRooms.add(m.chatRoomId);
      } else if (m.status == PendingStatus.waiting) {
        return true;
      }
    }

    final actions = await store.actions(ownerId);
    final heldGroups = <String>{};
    for (final a in actions) {
      if (heldGroups.contains(a.groupId)) continue;
      if (a.status == PendingStatus.refused) {
        if (a.kind != PendingActionKind.proposeMeeting) heldGroups.add(a.groupId);
      } else if (a.status == PendingStatus.waiting) {
        return true;
      }
    }
    return false;
  }

  Future<bool> _isBlockedOnMobileData() async {
    final current = await transport?.currentTransport();
    if (current != NetworkTransport.mobile) return false;
    final allowed = await mobileDataPreference?.isAllowed() ?? false;
    return !allowed;
  }

  void _flushAfterConnectionChange() {
    if (_running != null) _connectionChangedWhileFlushing = true;
    flush();
  }

  Future<void> _checkBeforeSend(int session, {required bool overMobileData}) async {
    final kind = await transport?.currentTransport();
    final blocked = kind == NetworkTransport.mobile &&
        !overMobileData &&
        !(await mobileDataPreference?.isAllowed() ?? false);
    if (session != _session || kind == NetworkTransport.none || blocked) {
      throw const _SyncPaused();
    }
  }

  /// Sends everything that is waiting. While a flush is running no second one starts: this one
  /// is queued to run right after it (unless that flush ends waiting for the network), and the
  /// returned future completes when both are done.
  ///
  /// When [overMobileData] is `true`, a single flush bypasses the `allow_mobile_data == false`
  /// Wi-Fi-only guard without modifying the persisted preference.
  Future<void> flush({bool overMobileData = false}) {
    final running = _running;
    if (running != null) {
      _flushAgain = true;
      _flushAgainOverMobileData = _flushAgainOverMobileData || overMobileData;
      return running.future;
    }
    final ownerId = _ownerId;
    if (ownerId == null) return Future.value();
    final session = _session;

    final completer = Completer<void>();
    _running = completer;
    _retryTimer?.cancel();
    _retryTimer = null;
    _runFlush(ownerId, session, overMobileData: overMobileData).then((deliveredEverything) {
      if (session != _session) return;
      if (deliveredEverything) {
        _failedFlushes = 0;
      } else {
        _scheduleRetry();
      }
    }).catchError((Object _) {
      if (session == _session) _scheduleRetry();
    }).whenComplete(() {
      _running = null;
      if (_flushAgain && _ownerId != null) {
        final nextOverMobile = _flushAgainOverMobileData;
        _flushAgain = false;
        _flushAgainOverMobileData = false;
        _connectionChangedWhileFlushing = false;
        flush(overMobileData: nextOverMobile).whenComplete(completer.complete);
      } else {
        _flushAgain = false;
        _flushAgainOverMobileData = false;
        _connectionChangedWhileFlushing = false;
        completer.complete();
      }
    });
    return completer.future;
  }

  Future<bool> _runFlush(String ownerId, int session, {required bool overMobileData}) async {
    try {
      await _checkBeforeSend(session, overMobileData: overMobileData);
      _setWaitingForWifi(false);
      return await _deliverAll(ownerId, () => _checkBeforeSend(session, overMobileData: overMobileData));
    } on _SyncPaused {
      if (session == _session) {
        final waiting = await _isBlockedOnMobileData() && await _hasDeliverableWaitingItems(ownerId);
        if (session == _session) _setWaitingForWifi(waiting);
      }
      return true;
    }
  }

  /// The server could not be reached, so flushing again right away would fail too: the backoff
  /// timer takes over, including for triggers that arrived during this flush.
  void _scheduleRetry() {
    if (_flushAgainOverMobileData || _connectionChangedWhileFlushing) return;
    _flushAgain = false;
    _flushAgainOverMobileData = false;
    final delay = _retryDelay(_failedFlushes);
    _failedFlushes++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      flush();
    });
  }

  Duration _retryDelay(int failures) {
    final ms = baseRetryDelay.inMilliseconds * pow(2, min(failures, 16));
    return Duration(milliseconds: min(ms.toInt(), maxRetryDelay.inMilliseconds));
  }

  /// `false` when something has to wait for a later flush.
  Future<bool> _deliverAll(String ownerId, Future<void> Function() checkBeforeSend) async {
    for (final listing in await store.listings(ownerId)) {
      if (listing.status != PendingStatus.waiting) continue;
      final outcome = await _attempt(PendingKind.listing, listing.id, () => _deliverListing(listing, checkBeforeSend));
      if (outcome == SyncOutcome.sent) await deleteCompressedPhotos(listing.photoPaths);
      if (outcome == SyncOutcome.retryLater) return false;
    }

    final messages = await store.messages(ownerId);
    final heldRooms = <String>{};
    for (final message in messages) {
      if (heldRooms.contains(message.chatRoomId)) continue;
      if (message.status == PendingStatus.refused) {
        heldRooms.add(message.chatRoomId);
        continue;
      }
      if (message.status != PendingStatus.waiting) continue;
      await checkBeforeSend();
      final outcome = await _attempt(PendingKind.message, message.id, () => sender.sendMessage(message));
      if (outcome == SyncOutcome.retryLater) return false;
      if (outcome == SyncOutcome.refused) heldRooms.add(message.chatRoomId);
    }

    final actions = await store.actions(ownerId);
    final heldGroups = <String>{};
    var hasDeferredAction = false;
    for (final action in actions) {
      if (heldGroups.contains(action.groupId)) continue;
      if (action.status == PendingStatus.refused) {
        if (action.kind != PendingActionKind.proposeMeeting) heldGroups.add(action.groupId);
        continue;
      }
      if (action.status != PendingStatus.waiting) continue;
      await checkBeforeSend();
      final startsAt = action.meetingStartsAt;
      final expired = startsAt != null && !startsAt.isAfter(_now());
      final outcome = await _attempt(
        PendingKind.action,
        action.id,
        () => expired ? _resolveExpiredProposal(action) : sender.sendAction(action),
      );
      if (outcome == SyncOutcome.retryLater) return false;
      if (outcome == SyncOutcome.deferred) hasDeferredAction = true;
      if (outcome != SyncOutcome.sent && action.kind != PendingActionKind.proposeMeeting) {
        heldGroups.add(action.groupId);
      }
    }
    return !hasDeferredAction;
  }

  Future<void> _resolveExpiredProposal(PendingAction action) async {
    // The app may have stopped during the request, before recording any attempt.
    final lookup = sender;
    if (lookup is MeetingProposalLookup && await lookup.wasMeetingProposalDelivered(action)) return;
    throw const ApiException(400, 'That time already passed. Propose another one.');
  }

  /// Uploads the photos that are not on the server yet, one request each, in order. Every URL is
  /// saved as soon as it arrives, so a connection that drops half way costs only the photos
  /// still missing. Then the listing itself is created.
  Future<void> _deliverListing(PendingListing listing, Future<void> Function() checkBeforeSend) async {
    final urls = List<String>.of(listing.uploadedUrls);
    for (var i = urls.length; i < listing.photoPaths.length; i++) {
      await checkBeforeSend();
      urls.add(await sender.uploadPhoto(listing.photoPaths[i]));
      await store.saveUploadedUrls(listing.id, urls);
    }
    // The listing's own id is its clientId: if an earlier attempt reached the server but its answer
    // was lost, the server returns that listing instead of creating a second one.
    await checkBeforeSend();
    await sender.createListing({...listing.payload, 'clientId': listing.id, 'imageUrls': urls});
  }

  Future<SyncOutcome> _attempt(PendingKind kind, String id, Future<void> Function() send) async {
    try {
      await send();
      await store.markSent(kind, id);
      return SyncOutcome.sent;
    } on _SyncPaused {
      rethrow;
    } on OutboxActionDeferred {
      return SyncOutcome.deferred;
    } on NetworkException catch (e) {
      _log('${kind.name} $id: no answer, kept for a retry (${e.message})');
      await store.markRetry(kind, id, e.message);
      return SyncOutcome.retryLater;
    } on ApiException catch (e) {
      if (_isTemporary(e.statusCode)) {
        _log('${kind.name} $id: HTTP ${e.statusCode}, kept for a retry (${e.message})');
        await store.markRetry(kind, id, e.message);
        return SyncOutcome.retryLater;
      }
      _log('${kind.name} $id: refused with HTTP ${e.statusCode} (${e.message})');
      await store.markRefused(kind, id, e.message);
      return SyncOutcome.refused;
    } on FileSystemException {
      // A queued photo was deleted from the phone; sending again cannot fix that.
      _log('${kind.name} $id: a queued photo is missing from the phone');
      await store.markRefused(kind, id, 'A photo of this listing is no longer on the phone.');
      return SyncOutcome.refused;
    } catch (e) {
      // Anything else (a bad response body, a plugin error…) must not abort the whole flush
      // silently with the row stuck: keep the reason on the row and try again later.
      _log('${kind.name} $id: unexpected error, kept for a retry ($e)');
      await store.markRetry(kind, id, 'Unexpected error: $e');
      return SyncOutcome.retryLater;
    }
  }

  /// Why an item was not delivered, for `flutter logs` / DevTools.
  void _log(String message) => developer.log(message, name: 'OutboxSync');

  /// 401: expired session (sent after the next login); 408 / 429 / 5xx: the server may accept it later.
  static bool _isTemporary(int status) => status == 401 || status == 408 || status == 429 || status >= 500;

  void dispose() {
    stop();
    _waitingForWifiController.close();
  }
}

class _SyncPaused implements Exception {
  const _SyncPaused();
}
