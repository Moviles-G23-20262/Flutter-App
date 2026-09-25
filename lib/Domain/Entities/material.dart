import 'enums.dart';
import 'user.dart';

class MaterialEntity {
  final String id;
  final String title;
  final String description;
  final String? courseCode;
  final double price;
  final MaterialCondition? condition;
  final MaterialStatus status;
  final String? edition;
  final String? model;
  final List<String> imageUrls;
  final String sellerId;
  final User? seller;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MaterialCategory category;

  MaterialEntity({
    required this.id,
    required this.title,
    required this.description,
    this.courseCode,
    required this.price,
    this.condition,
    required this.status,
    this.edition,
    this.model,
    required this.imageUrls,
    required this.sellerId,
    this.seller,
    required this.createdAt,
    required this.updatedAt,
    required this.category,
  });
}