import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../../dto/marketplace_models.dart';
import '../../entities/meetup_entities.dart';
import '../../rules/campus_default_zones.dart';

/// The campus safe zones shipped inside the app (`assets/campus_zones.json`): the last fallback
/// when neither the server nor the saved copy can give the list.
///
/// Their ids are local (see [CampusDefaultZones]), so a zone from this file can be shown but not
/// sent in a proposal.
class CampusZonesAssetDataSource {
  static const String assetPath = 'assets/campus_zones.json';

  final Future<String> Function() _load;

  /// [load] replaces reading the asset, e.g. in tests.
  CampusZonesAssetDataSource({Future<String> Function()? load})
      : _load = load ?? (() => rootBundle.loadString(assetPath));

  /// The bundled zones, or an empty list when the file is missing or unreadable.
  Future<List<MeetingPointEntity>> getMeetingPoints() async {
    try {
      return parseList(jsonDecode(await _load()), meetingPointFromJson);
    } catch (_) {
      return const [];
    }
  }
}
