import '../../Domain/Entities/chat_room_entity.dart';
import '../../Domain/Entities/exchange_entity.dart';
import '../../Domain/Entities/material_entity.dart';
import '../../Domain/Entities/meetup_entities.dart';
import '../../Domain/Entities/notification_entity.dart';
import '../../Domain/Entities/user_summary.dart';
import '../../Domain/Entities/wishlist_item_entity.dart';

// JSON → domain mapping for what the NestJS backend returns.
// Prisma `Decimal` fields (price) arrive as strings such as "18.00"; enum values match the Dart enum names.

typedef Json = Map<String, dynamic>;

double _toDouble(Object? value) => value is num ? value.toDouble() : double.parse(value.toString());

T? _optional<T>(Object? value, T Function(Json) parse) => value == null ? null : parse(value as Json);

DateTime? _optionalDate(Object? value) => value == null ? null : DateTime.parse(value as String);

/// Enum value by name, or [fallback] for a value this app version doesn't know yet.
T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) =>
    values.where((v) => v.name == name).firstOrNull ?? fallback;

UserSummary userSummaryFromJson(Json json) => UserSummary(
      id: json['id'] as String,
      fullName: json['fullName'] as String,
      major: json['major'] as String,
      faculty: json['faculty'] as String?,
      rating: _toDouble(json['rating']),
    );

MaterialEntity materialFromJson(Json json) => MaterialEntity(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      courseCode: json['courseCode'] as String?,
      price: _toDouble(json['price']),
      condition: json['condition'] == null
          ? null
          : MaterialConditionEnum.values.byName(json['condition'] as String),
      status: MaterialStatusEnum.values.byName(json['status'] as String),
      edition: json['edition'] as String?,
      model: json['model'] as String?,
      imageUrls: (json['imageUrls'] as List<dynamic>).cast<String>(),
      sellerId: json['sellerId'] as String,
      seller: _optional(json['seller'], userSummaryFromJson),
      category: MaterialCategoryEnum.values.byName(json['category'] as String),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );

MessageEntity messageFromJson(Json json) => MessageEntity(
      id: json['id'] as String,
      chatRoomId: json['chatRoomId'] as String,
      senderId: json['senderId'] as String,
      content: json['content'] as String,
      type: _enumByName(MessageTypeEnum.values, json['type'], MessageTypeEnum.TEXT),
      meetingProposal: _optional(json['meetingProposal'], meetingProposalFromJson),
      isRead: json['isRead'] as bool,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

ChatRoomEntity chatRoomFromJson(Json json) {
  final messages = ((json['messages'] as List<dynamic>?) ?? const [])
      .map((m) => messageFromJson(m as Json))
      .toList();
  // The list endpoint sends only the newest message; the detail endpoint sends all of them.
  final last = messages.isEmpty
      ? null
      : messages.reduce((a, b) => a.createdAt.isAfter(b.createdAt) ? a : b);
  final counts = json['_count'] as Json?;

  return ChatRoomEntity(
    id: json['id'] as String,
    materialId: json['materialId'] as String,
    buyerId: json['buyerId'] as String,
    sellerId: json['sellerId'] as String,
    createdAt: DateTime.parse(json['createdAt'] as String),
    material: _optional(json['material'], materialFromJson),
    buyer: _optional(json['buyer'], userSummaryFromJson),
    seller: _optional(json['seller'], userSummaryFromJson),
    lastMessage: last,
    unreadCount: (counts?['messages'] as int?) ?? 0,
  );
}

ExchangeEntity exchangeFromJson(Json json) => ExchangeEntity(
      id: json['id'] as String,
      orderNumber: json['orderNumber'] as int,
      materialId: json['materialId'] as String,
      buyerId: json['buyerId'] as String,
      sellerId: json['sellerId'] as String,
      price: _toDouble(json['price']),
      status: ExchangeStatusEnum.values.byName(json['status'] as String),
      createdAt: _optionalDate(json['createdAt']),
      completedAt: _optionalDate(json['completedAt']),
      receivedCondition: json['receivedCondition'] == null
          ? null
          : MaterialConditionEnum.values.byName(json['receivedCondition'] as String),
      meetingPointId: json['meetingPointId'] as String?,
      meetingPoint: _optional(json['meetingPoint'], meetingPointFromJson),
      meetingStartsAt: _optionalDate(json['meetingStartsAt']),
      meetingEndsAt: _optionalDate(json['meetingEndsAt']),
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
      material: _optional(json['material'], materialFromJson),
      buyer: _optional(json['buyer'], userSummaryFromJson),
      seller: _optional(json['seller'], userSummaryFromJson),
    );

WishlistItemEntity wishlistItemFromJson(Json json) => WishlistItemEntity(
      id: json['id'] as String,
      userId: json['userId'] as String,
      materialId: json['materialId'] as String,
      material: _optional(json['material'], materialFromJson),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );

NotificationEntity notificationFromJson(Json json) => NotificationEntity(
      id: json['id'] as String,
      userId: json['userId'] as String,
      materialId: json['materialId'] as String?,
      type: _enumByName(NotificationTypeEnum.values, json['type'], NotificationTypeEnum.OTHER),
      sentAt: DateTime.parse(json['sentAt'] as String),
      openedAt: json['openedAt'] == null ? null : DateTime.parse(json['openedAt'] as String),
      material: _optional(json['material'], materialFromJson),
    );

MeetingPointEntity meetingPointFromJson(Json json) => MeetingPointEntity(
      id: json['id'] as String,
      name: json['name'] as String,
      detail: json['detail'] as String?,
      zoneType: MeetingZoneTypeEnum.values.byName(json['zoneType'] as String),
      isMonitored: json['isMonitored'] as bool,
      location: GeoPoint(_toDouble(json['lat']), _toDouble(json['lng'])),
    );

MeetingProposalEntity meetingProposalFromJson(Json json) => MeetingProposalEntity(
      id: json['id'] as String,
      chatRoomId: json['chatRoomId'] as String,
      proposerId: json['proposerId'] as String,
      meetingPoint: _optional(json['meetingPoint'], meetingPointFromJson),
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      status: MeetingProposalStatusEnum.values.byName(json['status'] as String),
    );

FreeSlot freeSlotFromJson(Json json) => FreeSlot(
      startsAt: DateTime.parse(json['startsAt'] as String),
      endsAt: DateTime.parse(json['endsAt'] as String),
      sharedBreak: json['sharedBreak'] as bool,
    );

MeetingSuggestions meetingSuggestionsFromJson(Json json) => MeetingSuggestions(
      slots: parseList(json['slots'], freeSlotFromJson),
      suggested: _optional(json['suggested'], freeSlotFromJson),
      callerHasSchedule: json['callerHasSchedule'] as bool,
      otherHasSchedule: json['otherHasSchedule'] as bool,
    );

ScheduleBlockEntity scheduleBlockFromJson(Json json) => ScheduleBlockEntity(
      id: json['id'] as String,
      dayOfWeek: json['dayOfWeek'] as int,
      startMinute: json['startMinute'] as int,
      endMinute: json['endMinute'] as int,
      label: json['label'] as String?,
    );

List<T> parseList<T>(Object? response, T Function(Json) parse) =>
    (response as List<dynamic>).map((item) => parse(item as Json)).toList();
