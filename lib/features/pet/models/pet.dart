class Pet {
  final String id;
  final String name;
  final double weight;
  final int age;
  final bool isFemale;
  final String? deviceKey;
  final String userId;
  final DateTime createdAt;
  final DateTime updatedAt;

  Pet({
    required this.id,
    required this.name,
    required this.weight,
    required this.age,
    required this.isFemale,
    this.deviceKey,
    required this.userId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'],
      name: json['name'],
      weight: json['weight'].toDouble(),
      age: json['age'],
      isFemale: json['is_female'],
      deviceKey: json['device_key'],
      userId: json['user_id'],
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'weight': weight,
      'age': age,
      'is_female': isFemale,
      'device_key': deviceKey,
      'user_id': userId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Pet copyWith({
    String? id,
    String? name,
    double? weight,
    int? age,
    bool? isFemale,
    String? deviceKey,
    String? userId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Pet(
      id: id ?? this.id,
      name: name ?? this.name,
      weight: weight ?? this.weight,
      age: age ?? this.age,
      isFemale: isFemale ?? this.isFemale,
      deviceKey: deviceKey ?? this.deviceKey,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 