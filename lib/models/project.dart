/// A project groups notes. The special Inbox is represented by projectId == ''
/// and is not stored as a Project record.
class Project {
  final String id;
  String name;
  String description;

  /// Hex color (e.g. 0xFF7C3AED) for the project label/pin.
  int colorValue;
  bool pinned;
  final DateTime createdAt;

  Project({
    required this.id,
    required this.name,
    required this.description,
    required this.colorValue,
    required this.pinned,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'description': description,
        'colorValue': colorValue,
        'pinned': pinned,
        'createdAt': createdAt.toIso8601String(),
      };

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        name: j['name'] as String,
        description: (j['description'] as String?) ?? '',
        colorValue: (j['colorValue'] as int?) ?? 0xFF7C3AED,
        pinned: (j['pinned'] as bool?) ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
