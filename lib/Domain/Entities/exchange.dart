import 'user.dart';
import 'material.dart';
import 'enums.dart';

class MeetingPoint {
  final String id;
  final String name;
  final String? detail;
  final MeetingZoneType zoneType;
  final bool isMonitored;
  final double lat;
  final double lng;
  final DateTime createdAt;

  MeetingPoint({
    required this.id,
    required this.name,
    this.detail,
    required this.zoneType,
    required this.isMonitored,
    required this.lat,
    required this.lng,
    required this.createdAt,
  });
}

class Exchange {
  final String id;
  final String materialId;
  final String buyerId;
  final String sellerId;
  final double price;
  final DateTime completedAt;
  final String? meetingPointId;
  final double? lat;
  final double? lng;
  
  final MaterialEntity? material;
  final User? buyer;
  final User? seller;
  final MeetingPoint? meetingPoint;

  Exchange({
    required this.id,
    required this.materialId,
    required this.buyerId,
    required this.sellerId,
    required this.price,
    required this.completedAt,
    this.meetingPointId,
    this.lat,
    this.lng,
    this.material,
    this.buyer,
    this.seller,
    this.meetingPoint,
  });
}