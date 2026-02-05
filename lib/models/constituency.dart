class Constituency {
  final String id;
  final String name;
  final String type;
  final String? parentId;

  Constituency({
    required this.id,
    required this.name,
    required this.type,
    this.parentId,
  });

  factory Constituency.fromJson(Map<String, dynamic> json) {
    return Constituency(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      type: json['type'] ?? '',
      parentId: json['parent_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'type': type, 'parent_id': parentId};
  }

  String get displayType {
    switch (type) {
      case 'lok_sabha_constituency':
        return 'Lok Sabha';
      case 'vidhan_sabha_constituency':
        return 'Vidhan Sabha';
      default:
        return type;
    }
  }
}
