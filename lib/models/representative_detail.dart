class RepresentativeDetail {
  final int id;
  final int candidateId;
  final String name;
  final String officeType;
  final String state;
  final String constituency;
  final String party;
  final String? term;
  final String? selfProfession;
  final String? spouseProfession;
  final String? imageUrl;
  final int? assets;
  final int? liabilities;
  final String? education;
  final Map<String, int>? selfItr;
  final Map<String, int>? spouseItr;
  final List<String>? ipcCases;
  final List<String>? bnsCases;
  final int totalCases;
  final int ipcCasesCount;
  final int bnsCasesCount;

  // Computed properties
  int? get netWorth =>
      (assets != null && liabilities != null) ? (assets! - liabilities!) : null;
  Person get person => Person(
    id: id.toString(),
    fullName: name,
    education: education,
    imageUrl: imageUrl,
  );
  CurrentRole? get currentRole => CurrentRole(
    office: officeType,
    constituency: constituency,
    state: state,
    party: party,
    term: term,
  );
  Statistics? get statistics => null; // V2 API doesn't have this

  RepresentativeDetail({
    required this.id,
    required this.candidateId,
    required this.name,
    required this.officeType,
    required this.state,
    required this.constituency,
    required this.party,
    this.term,
    this.selfProfession,
    this.spouseProfession,
    this.imageUrl,
    this.assets,
    this.liabilities,
    this.education,
    this.selfItr,
    this.spouseItr,
    this.ipcCases,
    this.bnsCases,
    this.totalCases = 0,
    this.ipcCasesCount = 0,
    this.bnsCasesCount = 0,
  });

  factory RepresentativeDetail.fromJson(Map<String, dynamic> json) {
    // Helper to parse int from string or int
    int _parseInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    int? _parseNullableInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      return null;
    }

    // Parse ITR data (year -> amount)
    Map<String, int>? _parseItr(dynamic itrData) {
      if (itrData == null) return null;
      if (itrData is! Map) return null;
      final Map<String, int> result = {};
      itrData.forEach((key, value) {
        final amount = _parseNullableInt(value);
        if (amount != null) {
          result[key.toString()] = amount;
        }
      });
      return result.isEmpty ? null : result;
    }

    // Parse case arrays
    List<String>? _parseCases(dynamic casesData) {
      if (casesData == null) return null;
      if (casesData is! List) return null;
      final List<String> result = casesData
          .where((item) => item != null)
          .map((item) => item.toString())
          .toList();
      return result.isEmpty ? null : result;
    }

    final ipcCases = _parseCases(json['ipc_cases']);
    final bnsCases = _parseCases(json['bns_cases']);

    return RepresentativeDetail(
      id: _parseInt(json['id'], 0),
      candidateId: _parseInt(json['candidate_id'], 0),
      name: json['name']?.toString() ?? '',
      officeType: json['office_type']?.toString() ?? '',
      state: json['state']?.toString() ?? '',
      constituency: json['constituency']?.toString() ?? '',
      party: json['party']?.toString() ?? '',
      term: json['term']?.toString(),
      selfProfession: json['self_profession']?.toString(),
      spouseProfession: json['spouse_profession']?.toString(),
      imageUrl: json['image_url']?.toString(),
      assets: _parseNullableInt(json['assets']),
      liabilities: _parseNullableInt(json['liabilities']),
      education: json['education']?.toString(),
      selfItr: _parseItr(json['self_itr']),
      spouseItr: _parseItr(json['spouse_itr']),
      ipcCases: ipcCases,
      bnsCases: bnsCases,
      // Calculate counts from arrays if not provided
      totalCases: _parseInt(
        json['total_cases'],
        (ipcCases?.length ?? 0) + (bnsCases?.length ?? 0),
      ),
      ipcCasesCount: _parseInt(json['ipc_cases_count'], ipcCases?.length ?? 0),
      bnsCasesCount: _parseInt(json['bns_cases_count'], bnsCases?.length ?? 0),
    );
  }
}

class Person {
  final String id;
  final String fullName;
  final String? education;
  final String? imageUrl;

  Person({
    required this.id,
    required this.fullName,
    this.education,
    this.imageUrl,
  });
}

class CurrentRole {
  final String office;
  final String constituency;
  final String state;
  final String party;
  final String? term;

  CurrentRole({
    required this.office,
    required this.constituency,
    required this.state,
    required this.party,
    this.term,
  });
}

class Statistics {
  final String? attendancePercent;
  final String? attendanceStateAvg;
  final int? questionsAsked;
  final String? questionsStateAvg;
  final int? debatesParticipated;
  final String? debatesStateAvg;

  Statistics({
    this.attendancePercent,
    this.attendanceStateAvg,
    this.questionsAsked,
    this.questionsStateAvg,
    this.debatesParticipated,
    this.debatesStateAvg,
  });

  factory Statistics.fromJson(Map<String, dynamic> json) {
    return Statistics(
      attendancePercent: json['attendance_percent'],
      attendanceStateAvg: json['attendance_state_avg'],
      questionsAsked: json['questions_asked'],
      questionsStateAvg: json['questions_state_avg'],
      debatesParticipated: json['debates_participated'],
      debatesStateAvg: json['debates_state_avg'],
    );
  }
}
