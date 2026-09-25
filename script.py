import os

base_dir = "c:/Users/mie/Documents/UNIVERSIDAD/9-SEMESTRE/MOVILES/flutter_front_end/lib"

directories = [
    "domain/entities",
    "domain/repositories",
    "domain/use_cases",
    "data/models",
    "data/data_sources",
    "data/repositories",
    "core/network"
]

for d in directories:
    os.makedirs(os.path.join(base_dir, d), exist_ok=True)

files = {}

files["domain/entities/enums.dart"] = """
enum MaterialCondition { NEW, LIKE_NEW, GOOD, FAIR }
enum MaterialStatus { AVAILABLE, RESERVED, SOLD }
enum MaterialCategory { BOOKS, CALCULATORS, LAB_EQUIPMENT, FURNITURE, OTHER }
enum MeetingZoneType { LIBRARY, STUDENT_CENTER, BUILDING_LOBBY, PLAZA }
enum NotificationType { SMART_MATCH, OTHER }
enum AnalyticsEventType { LISTING_VIEW, SEARCH, CONTACT_SELLER, WISHLIST_ADD, WISHLIST_REMOVE, NOTIFICATION_SENT, NOTIFICATION_OPENED }
"""

files["domain/entities/user.dart"] = """
class User {
  final String id;
  final String email;
  final String fullName;
  final String major;
  final String? faculty;
  final double rating;
  final DateTime createdAt;

  User({
    required this.id,
    required this.email,
    required this.fullName,
    required this.major,
    this.faculty,
    required this.rating,
    required this.createdAt,
  });
}
"""

files["domain/entities/material.dart"] = """
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
"""

files["domain/entities/chat.dart"] = """
import 'user.dart';
import 'material.dart';

class ChatRoom {
  final String id;
  final String materialId;
  final String buyerId;
  final String sellerId;
  final DateTime createdAt;
  final User? buyer;
  final MaterialEntity? material;
  final User? seller;
  final List<Message>? messages;

  ChatRoom({
    required this.id,
    required this.materialId,
    required this.buyerId,
    required this.sellerId,
    required this.createdAt,
    this.buyer,
    this.material,
    this.seller,
    this.messages,
  });
}

class Message {
  final String id;
  final String chatRoomId;
  final String senderId;
  final String content;
  final bool isRead;
  final DateTime createdAt;
  final User? sender;

  Message({
    required this.id,
    required this.chatRoomId,
    required this.senderId,
    required this.content,
    required this.isRead,
    required this.createdAt,
    this.sender,
  });
}
"""

files["domain/entities/exchange.dart"] = """
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
"""

files["data/models/user_model.dart"] = """
import '../../domain/entities/user.dart';

class UserModel extends User {
  UserModel({
    required super.id,
    required super.email,
    required super.fullName,
    required super.major,
    super.faculty,
    required super.rating,
    required super.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      fullName: json['fullName'],
      major: json['major'],
      faculty: json['faculty'],
      rating: (json['rating'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'fullName': fullName,
      'major': major,
      'faculty': faculty,
      'rating': rating,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
"""

files["data/models/material_model.dart"] = """
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
"""

files["core/network/api_client.dart"] = """
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final http.Client client;

  ApiClient({required this.baseUrl, required this.client});

  Future<dynamic> get(String endpoint) async {
    final response = await client.get(Uri.parse('$baseUrl$endpoint'));
    return _processResponse(response);
  }

  Future<dynamic> post(String endpoint, {Map<String, dynamic>? body}) async {
    final response = await client.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: {'Content-Type': 'application/json'},
      body: body != null ? jsonEncode(body) : null,
    );
    return _processResponse(response);
  }

  dynamic _processResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isNotEmpty) {
        return jsonDecode(response.body);
      }
      return null;
    } else {
      throw Exception('API Error: ${response.statusCode} ${response.body}');
    }
  }
}
"""

files["data/data_sources/remote_data_source.dart"] = """
import '../../core/network/api_client.dart';
import '../models/user_model.dart';
import '../models/material_model.dart';

abstract class RemoteDataSource {
  Future<UserModel> getUser(String id);
  Future<List<MaterialModel>> getMaterials();
  Future<MaterialModel> createMaterial(MaterialModel material);
}

class RemoteDataSourceImpl implements RemoteDataSource {
  final ApiClient apiClient;

  RemoteDataSourceImpl({required this.apiClient});

  @override
  Future<UserModel> getUser(String id) async {
    final response = await apiClient.get('/users/$id');
    return UserModel.fromJson(response);
  }

  @override
  Future<List<MaterialModel>> getMaterials() async {
    final response = await apiClient.get('/materials');
    return (response as List).map((json) => MaterialModel.fromJson(json)).toList();
  }
  
  @override
  Future<MaterialModel> createMaterial(MaterialModel material) async {
    final response = await apiClient.post('/materials', body: material.toJson());
    return MaterialModel.fromJson(response);
  }
}
"""

files["domain/repositories/repositories.dart"] = """
import '../entities/user.dart';
import '../entities/material.dart';

abstract class UserRepository {
  Future<User> getUser(String id);
}

abstract class MaterialRepository {
  Future<List<MaterialEntity>> getMaterials();
  Future<MaterialEntity> createMaterial(MaterialEntity material);
}
"""

files["data/repositories/repositories_impl.dart"] = """
import '../../domain/repositories/repositories.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/material.dart';
import '../data_sources/remote_data_source.dart';

class UserRepositoryImpl implements UserRepository {
  final RemoteDataSource remoteDataSource;

  UserRepositoryImpl({required this.remoteDataSource});

  @override
  Future<User> getUser(String id) async {
    return await remoteDataSource.getUser(id);
  }
}

class MaterialRepositoryImpl implements MaterialRepository {
  final RemoteDataSource remoteDataSource;

  MaterialRepositoryImpl({required this.remoteDataSource});

  @override
  Future<List<MaterialEntity>> getMaterials() async {
    return await remoteDataSource.getMaterials();
  }

  @override
  Future<MaterialEntity> createMaterial(MaterialEntity material) async {
    // We assume casting or converting Entity to Model here
    // In a real app we would map Entity -> Model, but for simplicity we rely on duck typing if they share the same structure, 
    // or we implement a mapper.
    throw UnimplementedError('Mapper needed for Entity to Model');
  }
}
"""

files["domain/use_cases/use_cases.dart"] = """
import '../repositories/repositories.dart';
import '../entities/user.dart';
import '../entities/material.dart';

class GetUserUseCase {
  final UserRepository repository;

  GetUserUseCase(this.repository);

  Future<User> execute(String id) {
    return repository.getUser(id);
  }
}

class GetMaterialsUseCase {
  final MaterialRepository repository;

  GetMaterialsUseCase(this.repository);

  Future<List<MaterialEntity>> execute() {
    return repository.getMaterials();
  }
}
"""

for filepath, content in files.items():
    full_path = os.path.join(base_dir, filepath)
    with open(full_path, "w", encoding="utf-8") as f:
        f.write(content.strip() + "\\n")
    print(f"Created {full_path}")

print("All files generated successfully!")
