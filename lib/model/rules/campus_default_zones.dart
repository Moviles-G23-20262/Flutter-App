/// The safe zones bundled with the app (`assets/campus_zones.json`) carry local ids with this
/// prefix. The server's ids are random per database, so these zones can be shown offline but
/// never sent in a proposal.
class CampusDefaultZones {
  const CampusDefaultZones._();

  static const String idPrefix = 'campus-default-';

  static bool isBundled(String meetingPointId) => meetingPointId.startsWith(idPrefix);
}
