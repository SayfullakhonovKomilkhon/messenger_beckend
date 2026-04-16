class BotModel {
  final String id;
  final String userId;
  final String name;
  final String? username;
  final String? description;
  final String? avatarUrl;
  final String? token;
  final String? webhookUrl;
  final bool isActive;
  final String? createdAt;

  const BotModel({
    required this.id,
    required this.userId,
    required this.name,
    this.username,
    this.description,
    this.avatarUrl,
    this.token,
    this.webhookUrl,
    this.isActive = true,
    this.createdAt,
  });

  factory BotModel.fromJson(Map<String, dynamic> json) {
    return BotModel(
      id: json['id'] as String,
      userId: json['userId'] as String,
      name: json['name'] as String,
      username: json['username'] as String?,
      description: json['description'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      token: json['token'] as String?,
      webhookUrl: json['webhookUrl'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: json['createdAt'] as String?,
    );
  }

  BotModel copyWith({
    String? name,
    String? username,
    String? description,
    String? avatarUrl,
    String? token,
    String? webhookUrl,
    bool? isActive,
  }) {
    return BotModel(
      id: id,
      userId: userId,
      name: name ?? this.name,
      username: username ?? this.username,
      description: description ?? this.description,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      token: token ?? this.token,
      webhookUrl: webhookUrl ?? this.webhookUrl,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
