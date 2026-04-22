class LessonQuestion {
  final String id;
  final String lessonId;
  final String text;
  final String type;
  final List<String> options;
  final String? explanation;
  final int points;
  final bool isActive;
  final int order;
  final String? createdAt;

  const LessonQuestion({
    required this.id,
    required this.lessonId,
    required this.text,
    required this.type,
    required this.options,
    this.explanation,
    required this.points,
    required this.isActive,
    required this.order,
    this.createdAt,
  });

  factory LessonQuestion.fromJson(Map<String, dynamic> json) {
    final optionsRaw = json['options'];
    final options = optionsRaw is List
        ? optionsRaw.map((e) => e.toString()).toList()
        : const <String>[];

    return LessonQuestion(
      id: (json['id'] ?? '').toString(),
      lessonId: (json['lessonId'] ?? json['lesson_id'] ?? '').toString(),
      text: (json['text'] ?? '').toString(),
      type: (json['type'] ?? 'multiple-choice').toString(),
      options: options,
      explanation: json['explanation']?.toString(),
      points: _asInt(json['points']) ?? 1,
      isActive: _asBool(json['isActive'] ?? json['is_active']) ?? true,
      order: _asInt(json['order']) ?? 0,
      createdAt: json['createdAt']?.toString() ?? json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'lessonId': lessonId,
      'text': text,
      'type': type,
      'options': options,
      'explanation': explanation,
      'points': points,
      'isActive': isActive,
      'order': order,
      if (createdAt != null) 'createdAt': createdAt,
    };
  }
}

int? _asInt(dynamic v) {
  if (v == null) return null;
  if (v is int) return v;
  if (v is num) return v.toInt();
  return int.tryParse(v.toString());
}

bool? _asBool(dynamic v) {
  if (v == null) return null;
  if (v is bool) return v;
  final s = v.toString().toLowerCase();
  if (s == 'true' || s == '1') return true;
  if (s == 'false' || s == '0') return false;
  return null;
}
