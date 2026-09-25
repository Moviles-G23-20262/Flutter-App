import '../../domain/entities/material.dart';
import '../../domain/entities/enums.dart';
import 'user_model.dart';

class MaterialModel extends MaterialEntity {
  MaterialModel({
    required super.id,
    required super.title,
    required super.description,
    super.courseCode,
    required super.price,
    super.condition,
    required super.status,
    super.edition,
    super.model,
    required super.imageUrls,
    required super.sellerId,
    super.seller,
    required super.createdAt,
    required super.updatedAt,
    required super.category,
  });

  factory MaterialModel.fromJson(Map<String, dynamic> json) {
    return MaterialModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      courseCode: json['courseCode'],
      price: double.parse(json['price'].toString()),
      condition: json['condition'] != null ? MaterialCondition.values.firstWhere((e) => e.name == json['condition']) : null,
      status: MaterialStatus.values.firstWhere((e) => e.name == json['status'], orElse: () => MaterialStatus.AVAILABLE),
      edition: json['edition'],
      model: json['model'],
      imageUrls: List<String>.from(json['imageUrls'] ?? []),
      sellerId: json['sellerId'],
      seller: json['seller'] != null ? UserModel.fromJson(json['seller']) : null,
      createdAt: DateTime.parse(json['createdAt']),
      updatedAt: DateTime.parse(json['updatedAt']),
      category: MaterialCategory.values.firstWhere((e) => e.name == json['category']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'courseCode': courseCode,
      'price': price,
      'condition': condition?.name,
      'status': status.name,
      'edition': edition,
      'model': model,
      'imageUrls': imageUrls,
      'sellerId': sellerId,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'category': category.name,
    };
  }
}