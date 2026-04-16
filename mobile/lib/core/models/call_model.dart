class CallHistoryModel {
  final String id;
  final String callType;
  final String status;
  final int? duration;
  final String? startedAt;
  final CallParticipant participant;

  const CallHistoryModel({
    required this.id,
    required this.callType,
    required this.status,
    this.duration,
    this.startedAt,
    required this.participant,
  });

  factory CallHistoryModel.fromJson(Map<String, dynamic> json) {
    return CallHistoryModel(
      id: json['id'] as String,
      callType: json['callType'] as String,
      status: json['status'] as String,
      duration: json['duration'] as int?,
      startedAt: json['startedAt'] as String?,
      participant: CallParticipant.fromJson(json['participant']),
    );
  }
}

class CallParticipant {
  final String id;
  final String name;
  final String? avatarUrl;

  const CallParticipant({
    required this.id,
    required this.name,
    this.avatarUrl,
  });

  factory CallParticipant.fromJson(Map<String, dynamic> json) {
    return CallParticipant(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
    );
  }
}
