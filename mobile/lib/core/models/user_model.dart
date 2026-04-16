class UserModel {
  final String id;
  final String? publicId;
  final String? name;
  final String? phone;
  final String? username;
  final String? aiName;
  final String? avatarUrl;
  final String? bio;
  final bool? isOnline;
  final bool? isBot;
  final String? lastSeenAt;

  const UserModel({
    required this.id,
    this.publicId,
    this.name,
    this.phone,
    this.username,
    this.aiName,
    this.avatarUrl,
    this.bio,
    this.isOnline,
    this.isBot,
    this.lastSeenAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      publicId: json['publicId'] as String?,
      name: json['name'] as String?,
      phone: json['phone'] as String?,
      username: json['username'] as String?,
      aiName: json['aiName'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      bio: json['bio'] as String?,
      isOnline: json['isOnline'] as bool?,
      isBot: json['isBot'] as bool?,
      lastSeenAt: json['lastSeenAt'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'publicId': publicId,
    'name': name,
    'phone': phone,
    'username': username,
    'aiName': aiName,
    'avatarUrl': avatarUrl,
    'bio': bio,
    'isOnline': isOnline,
    'isBot': isBot,
    'lastSeenAt': lastSeenAt,
  };

  UserModel copyWith({
    String? id,
    String? publicId,
    String? name,
    String? phone,
    String? username,
    String? aiName,
    String? avatarUrl,
    String? bio,
    bool? isOnline,
    bool? isBot,
    String? lastSeenAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      publicId: publicId ?? this.publicId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      username: username ?? this.username,
      aiName: aiName ?? this.aiName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      bio: bio ?? this.bio,
      isOnline: isOnline ?? this.isOnline,
      isBot: isBot ?? this.isBot,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}
