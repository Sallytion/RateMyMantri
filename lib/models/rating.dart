class Rating {
  final String id;
  final int representativeId;
  final String
  ratingType; // 'unverified', 'verified-named', 'verified-anonymous'
  final int question1Stars;
  final int question2Stars;
  final int question3Stars;
  final int overallScore;
  final String? reviewText;
  final String? userName; // Only for verified-named
  final String? userProfileImage; // Only for verified-named
  final DateTime createdAt;
  final DateTime updatedAt;

  // For user's own ratings - additional representative info
  final String? representativeName;
  final String? representativeImage;
  final String? officeType;
  final String? state;
  final String? constituency;
  final String? party;

  Rating({
    required this.id,
    required this.representativeId,
    required this.ratingType,
    required this.question1Stars,
    required this.question2Stars,
    required this.question3Stars,
    required this.overallScore,
    this.reviewText,
    this.userName,
    this.userProfileImage,
    required this.createdAt,
    required this.updatedAt,
    this.representativeName,
    this.representativeImage,
    this.officeType,
    this.state,
    this.constituency,
    this.party,
  });

  factory Rating.fromJson(Map<String, dynamic> json) {
    try {
      final createdAtStr = json['createdAt'] as String;
      final updatedAtStr = json['updatedAt'] as String?;

      // representativeId might be missing in some endpoints
      int? repId;
      if (json['representativeId'] != null) {
        repId = json['representativeId'] is int
            ? json['representativeId']
            : int.tryParse(json['representativeId'].toString());
      }

      return Rating(
        id: json['id'] as String,
        representativeId: repId ?? 0, // Default to 0 if missing
        ratingType: json['ratingType'] as String,
        question1Stars: json['question1Stars'] as int,
        question2Stars: json['question2Stars'] as int,
        question3Stars: json['question3Stars'] as int,
        overallScore: json['overallScore'] is int
            ? json['overallScore']
            : (json['overallScore'] as double).round(),
        reviewText: json['reviewText'] as String?,
        userName: json['userName'] as String?,
        userProfileImage: json['userProfileImage'] as String?,
        createdAt: DateTime.parse(createdAtStr),
        updatedAt: updatedAtStr != null
            ? DateTime.parse(updatedAtStr)
            : DateTime.parse(createdAtStr),
        representativeName: json['representativeName'] as String?,
        representativeImage: json['representativeImage'] as String?,
        officeType: json['officeType'] as String?,
        state: json['state'] as String?,
        constituency: json['constituency'] as String?,
        party: json['party'] as String?,
      );
    } catch (e) {
      rethrow;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'representativeId': representativeId,
      'ratingType': ratingType,
      'question1Stars': question1Stars,
      'question2Stars': question2Stars,
      'question3Stars': question3Stars,
      'overallScore': overallScore,
      'reviewText': reviewText,
      'userName': userName,
      'userProfileImage': userProfileImage,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      if (representativeName != null) 'representativeName': representativeName,
      if (representativeImage != null)
        'representativeImage': representativeImage,
      if (officeType != null) 'officeType': officeType,
      if (state != null) 'state': state,
      if (constituency != null) 'constituency': constituency,
      if (party != null) 'party': party,
    };
  }

  // Convert stars to display format
  double get overallStars {
    if (overallScore <= 20) return 1.0;
    if (overallScore <= 40) return 2.0;
    if (overallScore <= 60) return 3.0;
    if (overallScore <= 80) return 4.0;
    return 5.0;
  }

  // Check if rating is anonymous
  bool get isAnonymous => ratingType == 'verified-anonymous';

  // Check if rating is verified
  bool get isVerified => ratingType.startsWith('verified');

  Rating copyWith({
    String? id,
    int? representativeId,
    String? ratingType,
    int? question1Stars,
    int? question2Stars,
    int? question3Stars,
    int? overallScore,
    String? reviewText,
    String? userName,
    String? userProfileImage,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? representativeName,
    String? representativeImage,
    String? officeType,
    String? state,
    String? constituency,
    String? party,
  }) {
    return Rating(
      id: id ?? this.id,
      representativeId: representativeId ?? this.representativeId,
      ratingType: ratingType ?? this.ratingType,
      question1Stars: question1Stars ?? this.question1Stars,
      question2Stars: question2Stars ?? this.question2Stars,
      question3Stars: question3Stars ?? this.question3Stars,
      overallScore: overallScore ?? this.overallScore,
      reviewText: reviewText ?? this.reviewText,
      userName: userName ?? this.userName,
      userProfileImage: userProfileImage ?? this.userProfileImage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      representativeName: representativeName ?? this.representativeName,
      representativeImage: representativeImage ?? this.representativeImage,
      officeType: officeType ?? this.officeType,
      state: state ?? this.state,
      constituency: constituency ?? this.constituency,
      party: party ?? this.party,
    );
  }
}
