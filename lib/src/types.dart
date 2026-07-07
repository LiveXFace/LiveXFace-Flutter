/// Data models returned by the FR-APIaaS API.

// ---------------------------------------------------------------------------
// Face Collection
// ---------------------------------------------------------------------------

class FaceCollection {
  final String id;
  final String organizationId;
  final String name;
  final String description;
  final int faceCount;
  final int? retentionDays;
  final DateTime createdAt;

  const FaceCollection({
    required this.id,
    required this.organizationId,
    required this.name,
    required this.description,
    required this.faceCount,
    this.retentionDays,
    required this.createdAt,
  });

  factory FaceCollection.fromJson(Map<String, dynamic> json) => FaceCollection(
        id: json['id'] as String,
        organizationId: json['organization_id'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        faceCount: json['face_count'] as int? ?? 0,
        retentionDays: json['retention_days'] as int?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// Face
// ---------------------------------------------------------------------------

class Face {
  final String id;
  final String collectionId;
  final String externalId;
  final Map<String, dynamic>? metadata;
  final String? imageUrl;
  final DateTime createdAt;

  const Face({
    required this.id,
    required this.collectionId,
    required this.externalId,
    this.metadata,
    this.imageUrl,
    required this.createdAt,
  });

  factory Face.fromJson(Map<String, dynamic> json) => Face(
        id: json['id'] as String,
        collectionId: json['collection_id'] as String,
        externalId: json['external_id'] as String? ?? '',
        metadata: json['metadata'] as Map<String, dynamic>?,
        imageUrl: json['image_url'] as String?,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

// ---------------------------------------------------------------------------
// Verification
// ---------------------------------------------------------------------------

class VerifyResult {
  final bool match;
  final double confidence;
  final double thresholdUsed;
  final String? faceId;

  const VerifyResult({
    required this.match,
    required this.confidence,
    required this.thresholdUsed,
    this.faceId,
  });

  factory VerifyResult.fromJson(Map<String, dynamic> json) => VerifyResult(
        match: json['match'] as bool,
        confidence: (json['confidence'] as num).toDouble(),
        thresholdUsed: (json['threshold_used'] as num).toDouble(),
        faceId: json['face_id'] as String?,
      );
}

// ---------------------------------------------------------------------------
// Identification
// ---------------------------------------------------------------------------

class IdentifyMatch {
  final String faceId;
  final String externalId;
  final double confidence;
  final Map<String, dynamic>? metadata;

  const IdentifyMatch({
    required this.faceId,
    required this.externalId,
    required this.confidence,
    this.metadata,
  });

  factory IdentifyMatch.fromJson(Map<String, dynamic> json) => IdentifyMatch(
        faceId: json['face_id'] as String,
        externalId: json['external_id'] as String? ?? '',
        confidence: (json['confidence'] as num).toDouble(),
        metadata: json['metadata'] as Map<String, dynamic>?,
      );
}

class IdentifyResult {
  final List<IdentifyMatch> matches;
  final int queryTimeMs;

  const IdentifyResult({required this.matches, required this.queryTimeMs});

  factory IdentifyResult.fromJson(Map<String, dynamic> json) => IdentifyResult(
        matches: (json['matches'] as List<dynamic>)
            .map((e) => IdentifyMatch.fromJson(e as Map<String, dynamic>))
            .toList(),
        queryTimeMs: json['query_time_ms'] as int? ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Liveness
// ---------------------------------------------------------------------------

class LivenessResult {
  final bool isLive;
  final double livenessScore;
  final bool faceDetected;
  final int faceCount;

  const LivenessResult({
    required this.isLive,
    required this.livenessScore,
    required this.faceDetected,
    required this.faceCount,
  });

  factory LivenessResult.fromJson(Map<String, dynamic> json) => LivenessResult(
        isLive: json['is_live'] as bool,
        livenessScore: (json['liveness_score'] as num).toDouble(),
        faceDetected: json['face_detected'] as bool,
        faceCount: json['face_count'] as int? ?? 0,
      );
}

// ---------------------------------------------------------------------------
// Face Attributes
// ---------------------------------------------------------------------------

class FaceAttributes {
  final bool faceDetected;
  final int faceCount;
  final int? age;
  final String? gender;

  const FaceAttributes({
    required this.faceDetected,
    required this.faceCount,
    this.age,
    this.gender,
  });

  factory FaceAttributes.fromJson(Map<String, dynamic> json) {
    final primary = json['primary'] as Map<String, dynamic>?;
    return FaceAttributes(
      faceDetected: json['face_detected'] as bool,
      faceCount: json['face_count'] as int? ?? 0,
      age: primary?['age'] as int?,
      gender: primary?['gender'] as String?,
    );
  }
}

// ---------------------------------------------------------------------------
// Paginated list helper
// ---------------------------------------------------------------------------

class PagedList<T> {
  final List<T> items;

  const PagedList(this.items);
}
