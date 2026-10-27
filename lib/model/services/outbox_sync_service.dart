import 'dart:async';
import 'dart:io';
import 'dart:math';

import '../../app/network/api_client.dart';
import '../../core/isolates/photo_compressor.dart';
import '../data_sources/local/outbox_store.dart';
import '../entities/pending_items.dart';
import '../repositories/connectivity_repository.dart';

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

/// How one delivery attempt ended.
enum SyncOutcome {
  /// Confirmed by the server; removed from the outbox.
  sent,

  /// No network, a 5xx or an expired session: it stays queued and the flush stops.
  retryLater,

  /// The server refused it (4xx): kept with the server's reason until the user discards it.
  refused,
}

/// Flushes the signed-in user's outbox:
/// - when the connection returns, when the app comes back to the foreground ([flush]) and on a
///   retry timer with exponential backoff while something is still waiting;
/// - one flush at a time: a second trigger while flushing waits for the running one;
/// - listings first (one `POST /uploads` per photo that is not on the server yet, then one
///   `POST /materials`), then messages, oldest first. A refused message holds back the later
///   messages of the same conversation, so they never arrive out of order;
/// - exchange steps last, the same way per exchange: a rating never goes before its completion.
///   A meeting proposal whose time has passed is refused on the phone instead of being sent.
class OutboxSyncService {
  final OutboxStore store;
  final OutboxSender sender;
  final ConnectivityRepository connectivity;

  /// First retry delay; it doubles after every flush that could not deliver everything.
  final Duration baseRetryDelay;
  final Duration maxRetryDelay;
  final DateTime Function() _now;

  OutboxSyncService({
    required this.store,
    required this.sender,
    required this.connectivity,
    this.baseRetryDelay = const Duration(seconds: 5),
    this.maxRetryDelay = const Duration(minutes: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  String? _ownerId;
  StreamSubscription<bool>? _connectivitySubscription;
  Completer<void>? _running;
  Timer? _retryTimer;
  int _failedFlushes = 0;

  /// A trigger arrived during a flush (e.g. a new item was queued): flush once more after it.
  bool _flushAgain = false;

  bool get isFlushing => _running != null;

  /// Whether an automatic retry is scheduled.
  bool get retryScheduled => _retryTimer != null;

  /// Starts syncing [ownerId]'s outbox (on login or session restore) and flushes once.
  void start(String ownerId) {
    if (_ownerId != ownerId) stop();
    _ownerId = ownerId;
    _connectivitySubscription ??= connectivity.watch().listen((online) {
      if (online) flush();
    }, onError: (_) {});
    flush();
  }

  /// Stops syncing (on logout). Queued rows stay: they belong to that user and are sent the next
  /// time they sign in on this phone.
  void stop() {
    _ownerId = null;
    _connectivitySubscription?.cancel();
    _connectivitySubscription = null;
    _retryTimer?.cancel();
    _retryTimer = null;
    _failedFlushes = 0;
    _flushAgain = false;
  }

  /// Sends everything that is waiting. While a flush is running no second one starts: this one
  /// is queued to run right after it (unless that flush ends waiting for the network), and the
  /// returned future completes when both are done.
  Future<void> flush() {
    final running = _running;
    if (running != null) {
      _flushAgain = true;
      return running.future;
    }
    final ownerId = _ownerId;
    if (ownerId == null) return Future.value();

    final completer = Completer<void>();
    _running = completer;
    _retryTimer?.cancel();
    _retryTimer = null;
    _deliverAll(ownerId).then((deliveredEverything) {
      if (_ownerId != ownerId) return;
      if (deliveredEverything) {
        _failedFlushes = 0;
      } else {
        _scheduleRetry();
      }
    }).catchError((Object _) {
      if (_ownerId == ownerId) _scheduleRetry();
    }).whenComplete(() {
      _running = null;
      if (_flushAgain && _ownerId == ownerId) {
        _flushAgain = false;
        flush().whenComplete(completer.complete);
      } else {
        _flushAgain = false;
        completer.complete();
      }
    });
    return completer.future;
  }

  /// The server could not be reached, so flushing again right away would fail too: the backoff
  /// timer takes over, including for triggers that arrived during this flush.
  void _scheduleRetry() {
    _flushAgain = false;
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
  Future<bool> _deliverAll(String ownerId) async {
    for (final listing in await store.listings(ownerId)) {
      if (listing.status != PendingStatus.waiting) continue;
      final outcome = await _attempt(PendingKind.listing, listing.id, () => _deliverListing(listing));
      if (outcome == SyncOutcome.sent) await deleteCompressedPhotos(listing.photoPaths);
      if (outcome == SyncOutcome.retryLater || _ownerId != ownerId) return false;
    }

    final messages = await store.messages(ownerId);
    final heldRooms = {
      for (final m in messages)
        if (m.status == PendingStatus.refused) m.chatRoomId,
    };
    for (final message in messages) {
      if (message.status != PendingStatus.waiting || heldRooms.contains(message.chatRoomId)) continue;
      final outcome = await _attempt(PendingKind.message, message.id, () => sender.sendMessage(message));
      if (outcome == SyncOutcome.retryLater || _ownerId != ownerId) return false;
      if (outcome == SyncOutcome.refused) heldRooms.add(message.chatRoomId);
    }

    final actions = await store.actions(ownerId);
    final heldGroups = {
      for (final a in actions)
        if (a.status == PendingStatus.refused) a.groupId,
    };
    for (final action in actions) {
      if (action.status != PendingStatus.waiting || heldGroups.contains(action.groupId)) continue;
      final startsAt = action.meetingStartsAt;
      if (startsAt != null && !startsAt.isAfter(_now())) {
        // Saved offline and the time went by: the other person could not make it anyway.
        await store.markRefused(PendingKind.action, action.id, 'That time already passed. Propose another one.');
        heldGroups.add(action.groupId);
        continue;
      }
      final outcome = await _attempt(PendingKind.action, action.id, () => sender.sendAction(action));
      if (outcome == SyncOutcome.retryLater || _ownerId != ownerId) return false;
      if (outcome == SyncOutcome.refused) heldGroups.add(action.groupId);
    }
    return true;
  }

  /// Uploads the photos that are not on the server yet, one request each, in order. Every URL is
  /// saved as soon as it arrives, so a connection that drops half way costs only the photos
  /// still missing. Then the listing itself is created.
  Future<void> _deliverListing(PendingListing listing) async {
    final urls = List<String>.of(listing.uploadedUrls);
    for (var i = urls.length; i < listing.photoPaths.length; i++) {
      urls.add(await sender.uploadPhoto(listing.photoPaths[i]));
      await store.saveUploadedUrls(listing.id, urls);
    }
    await sender.createListing({...listing.payload, 'imageUrls': urls});
  }

  Future<SyncOutcome> _attempt(PendingKind kind, String id, Future<void> Function() send) async {
    try {
      await send();
      await store.markSent(kind, id);
      return SyncOutcome.sent;
    } on NetworkException catch (e) {
      await store.markRetry(kind, id, e.message);
      return SyncOutcome.retryLater;
    } on ApiException catch (e) {
      if (_isTemporary(e.statusCode)) {
        await store.markRetry(kind, id, e.message);
        return SyncOutcome.retryLater;
      }
      await store.markRefused(kind, id, e.message);
      return SyncOutcome.refused;
    } on FileSystemException {
      // A queued photo was deleted from the phone; sending again cannot fix that.
      await store.markRefused(kind, id, 'A photo of this listing is no longer on the phone.');
      return SyncOutcome.refused;
    }
  }

  /// 401: expired session (sent after the next login); 408 / 429 / 5xx: the server may accept it later.
  static bool _isTemporary(int status) => status == 401 || status == 408 || status == 429 || status >= 500;

  void dispose() => stop();
}
