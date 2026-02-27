class Constituency {
  final String id;
  final String name;    // localised name in user's language
  final String nameEn;  // canonical English name — use for API calls
  final String type;
  final String? parentId;

  Constituency({
    required this.id,
    required this.name,
    required this.nameEn,
    required this.type,
    this.parentId,
  });

  factory Constituency.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String? ?? '';
    final nameEn = json['name_en'] as String? ?? name; // fallback to name if backend omits name_en
    return Constituency(
      id: json['id'] ?? '',
      name: name,
      nameEn: nameEn,
      type: json['type'] ?? '',
      parentId: json['parent_id'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'name_en': nameEn, 'type': type, 'parent_id': parentId};
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
