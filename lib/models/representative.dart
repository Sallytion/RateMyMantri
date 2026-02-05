class Representative {
  final int id;
  final int candidateId;
  final String fullName;
  final String officeType;
  final String state;
  final String constituency;
  final String party;
  final String? selfProfession;
  final String? spouseProfession;
  final String? imageUrl;
  final int? assets;
  final int? liabilities;
  final String? education;
  final int totalCases;
  final int ipcCasesCount;
  final int bnsCasesCount;
  final double? averageRating;
  final int? totalRatings;

  Representative({
    required this.id,
    required this.candidateId,
    required this.fullName,
    required this.officeType,
    required this.state,
    required this.constituency,
    required this.party,
    this.selfProfession,
    this.spouseProfession,
    this.imageUrl,
    this.assets,
    this.liabilities,
    this.education,
    this.totalCases = 0,
    this.ipcCasesCount = 0,
    this.bnsCasesCount = 0,
    this.averageRating,
    this.totalRatings,
  });

  // Computed property for backward compatibility
  String get personId => id.toString();
  String get office => officeType;
  int? get netWorth =>
      (assets != null && liabilities != null) ? (assets! - liabilities!) : null;

  factory Representative.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse int from dynamic value
    int _parseInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    // Helper function to safely parse nullable int from dynamic value
    int? _parseNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    return Representative(
      id: _parseInt(json['id'], 0),
      candidateId: _parseInt(json['candidate_id'], 0),
      fullName: json['name']?.toString() ?? '',
      officeType: json['office_type']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      constituency: json['constituency']?.toString() ?? '',
      party: json['party']?.toString() ?? '',
      selfProfession: json['self_profession']?.toString(),
      spouseProfession: json['spouse_profession']?.toString(),
      imageUrl: json['image_url']?.toString(),
      assets: _parseNullableInt(json['assets']),
      liabilities: _parseNullableInt(json['liabilities']),
      education: json['education']?.toString(),
      totalCases: _parseInt(json['total_cases'], 0),
      ipcCasesCount: _parseInt(json['ipc_cases_count'], 0),
      bnsCasesCount: _parseInt(json['bns_cases_count'], 0),
      averageRating: json['average_rating'] != null 
          ? (json['average_rating'] is num ? (json['average_rating'] as num).toDouble() : null)
          : null,
      totalRatings: _parseNullableInt(json['total_ratings']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'candidate_id': candidateId,
      'name': fullName,
      'office_type': officeType,
      'state': state,
      'constituency': constituency,
      'party': party,
      'self_profession': selfProfession,
      'spouse_profession': spouseProfession,
      'image_url': imageUrl,
      'assets': assets,
      'liabilities': liabilities,
      'education': education,
      'total_cases': totalCases,
      'ipc_cases_count': ipcCasesCount,
      'bns_cases_count': bnsCasesCount,
      'average_rating': averageRating,
      'total_ratings': totalRatings,
    };
  }
}
