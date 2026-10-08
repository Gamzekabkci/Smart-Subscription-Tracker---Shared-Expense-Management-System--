import 'dart:convert';

class SharedMember {
  final String name;
  final String phone;

  SharedMember({
    required this.name,
    required this.phone,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
    };
  }

  factory SharedMember.fromMap(Map<String, dynamic> map) {
    return SharedMember(
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
    );
  }
}

class Subscription {
  int? id;

  String? userId;

  String name;
  double price;
  String currency;
  String category;
  DateTime billingDate;
  int personCount;
  String? packageName;
  bool isShared;
  bool isTrial;

  String? sharedMembersJson;

  Subscription({
    this.id,
    this.userId,
    required this.name,
    required this.price,
    this.currency = 'TL',
    required this.category,
    required this.billingDate,
    this.personCount = 1,
    this.packageName,
    this.isShared = false,
    this.isTrial = false,
    this.sharedMembersJson,
  });

  List<SharedMember> get sharedMembers {
    if (sharedMembersJson == null || sharedMembersJson!.trim().isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(sharedMembersJson!);

      if (decoded is List) {
        return decoded
            .map((item) => SharedMember.fromMap(Map<String, dynamic>.from(item)))
            .toList();
      }

      return [];
    } catch (_) {
      return [];
    }
  }

  static String encodeMembers(List<SharedMember> members) {
    return jsonEncode(members.map((member) => member.toMap()).toList());
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'name': name,
      'price': price,
      'currency': currency,
      'category': category,
      'billingDate': billingDate.toIso8601String(),
      'personCount': personCount,
      'packageName': packageName,
      'isShared': isShared ? 1 : 0,
      'isTrial': isTrial ? 1 : 0,
      'sharedMembersJson': sharedMembersJson,
    };
  }

  factory Subscription.fromMap(Map<String, dynamic> map) {
    return Subscription(
      id: map['id'],
      userId: map['userId']?.toString(),
      name: map['name'] ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0.0,
      currency: map['currency'] ?? 'TL',
      category: map['category'] ?? 'Diğer',
      billingDate: DateTime.parse(map['billingDate']),
      personCount: map['personCount'] ?? 1,
      packageName: map['packageName'],
      isShared: map['isShared'] == 1 || map['isShared'] == true,
      isTrial: map['isTrial'] == 1 || map['isTrial'] == true,
      sharedMembersJson: map['sharedMembersJson']?.toString(),
    );
  }
}