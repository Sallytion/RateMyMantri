class RatingStatistics {
  final int representativeId;
  final int totalRatings;
  final int verifiedNamedCount;
  final int verifiedAnonymousCount;
  final int unverifiedCount;
  final double avgOverallScore;
  final double avgQ1Stars;
  final double avgQ2Stars;
  final double avgQ3Stars;
  final int overallStars;
  final DateTime? latestRatingDate;
  final RepresentativeInfo? representative;

  RatingStatistics({
    required this.representativeId,
    required this.totalRatings,
    required this.verifiedNamedCount,
    required this.verifiedAnonymousCount,
    required this.unverifiedCount,
    required this.avgOverallScore,
    required this.avgQ1Stars,
    required this.avgQ2Stars,
    required this.avgQ3Stars,
    required this.overallStars,
    this.latestRatingDate,
    this.representative,
  });

  factory RatingStatistics.fromJson(Map<String, dynamic> json) {
    // Helper function to safely parse double
    double _parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty || trimmed.toLowerCase() == 'null') return 0.0;
        return double.tryParse(trimmed) ?? 0.0;
      }
      return 0.0;
    }

    // Helper function to safely parse int
    int _parseInt(dynamic value, int defaultValue) {
      if (value == null) return defaultValue;
      if (value is int) return value;
      if (value is String) {
        final trimmed = value.trim();
        if (trimmed.isEmpty || trimmed.toLowerCase() == 'null')
          return defaultValue;
        return int.tryParse(trimmed) ?? defaultValue;
      }
      return defaultValue;
    }

    // Parse representative info if available (backend now includes it in statistics)
    RepresentativeInfo? repInfo;
    if (json['name'] != null) {
      // Representative info is directly in statistics object
      repInfo = RepresentativeInfo(
        name: json['name'] as String,
        officeType: json['office_type'] as String,
        state: json['state'] as String,
        constituency: json['constituency'] as String,
        party: json['party'] as String,
      );
    } else if (json['representative'] != null) {
      repInfo = RepresentativeInfo.fromJson(json['representative']);
    }

    return RatingStatistics(
      representativeId: _parseInt(
        json['representativeId'] ?? json['representative_id'],
        0,
      ),
      totalRatings: _parseInt(json['totalRatings'] ?? json['total_ratings'], 0),
      verifiedNamedCount: _parseInt(
        json['verifiedNamedCount'] ?? json['verified_named_count'],
        0,
      ),
      verifiedAnonymousCount: _parseInt(
        json['verifiedAnonymousCount'] ?? json['verified_anonymous_count'],
        0,
      ),
      unverifiedCount: _parseInt(
        json['unverifiedCount'] ?? json['unverified_count'],
        0,
      ),
      avgOverallScore: _parseDouble(
        json['avgOverallScore'] ?? json['avg_overall_score'],
      ),
      avgQ1Stars: _parseDouble(json['avgQ1Stars'] ?? json['avg_q1_stars']),
      avgQ2Stars: _parseDouble(json['avgQ2Stars'] ?? json['avg_q2_stars']),
      avgQ3Stars: _parseDouble(json['avgQ3Stars'] ?? json['avg_q3_stars']),
      overallStars: _parseInt(json['overallStars'] ?? json['overall_stars'], 0),
      latestRatingDate:
          json['latestRatingDate'] != null || json['latest_rating_date'] != null
          ? DateTime.tryParse(
              (json['latestRatingDate'] ?? json['latest_rating_date'])
                  as String,
            )
          : null,
      representative: repInfo,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'representativeId': representativeId,
      'totalRatings': totalRatings,
      'verifiedNamedCount': verifiedNamedCount,
      'verifiedAnonymousCount': verifiedAnonymousCount,
      'unverifiedCount': unverifiedCount,
      'avgOverallScore': avgOverallScore,
      'avgQ1Stars': avgQ1Stars,
      'avgQ2Stars': avgQ2Stars,
      'avgQ3Stars': avgQ3Stars,
      'overallStars': overallStars,
      if (latestRatingDate != null)
        'latestRatingDate': latestRatingDate!.toIso8601String(),
      if (representative != null) 'representative': representative!.toJson(),
    };
  }

  // Get percentage of verified ratings
  double get verifiedPercentage {
    if (totalRatings == 0) return 0.0;
    return ((verifiedNamedCount + verifiedAnonymousCount) / totalRatings * 100);
  }

  // Check if has enough ratings to be reliable
  bool get hasEnoughRatings => totalRatings >= 5;
}

class RepresentativeInfo {
  final String name;
  final String officeType;
  final String state;
  final String constituency;
  final String party;

  RepresentativeInfo({
    required this.name,
    required this.officeType,
    required this.state,
    required this.constituency,
    required this.party,
  });

  factory RepresentativeInfo.fromJson(Map<String, dynamic> json) {
    return RepresentativeInfo(
      name: json['name'] as String,
      officeType: (json['officeType'] ?? json['office_type']) as String,
      state: json['state'] as String,
      constituency: json['constituency'] as String,
      party: json['party'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'officeType': officeType,
      'state': state,
      'constituency': constituency,
      'party': party,
    };
  }
}
