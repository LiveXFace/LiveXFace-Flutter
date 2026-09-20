/// Data models returned by the LiveXFace API.
library;

import 'dart:typed_data';

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
        organizationId: json['organizationId'] as String,
        name: json['name'] as String,
        description: json['description'] as String? ?? '',
        faceCount: json['faceCount'] as int? ?? 0,
        retentionDays: json['retentionDays'] as int?,
        createdAt: DateTime.parse(json['createdAt'] as String),
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
        collectionId: json['collectionId'] as String,
        externalId: json['externalId'] as String? ?? '',
        metadata: json['metadata'] as Map<String, dynamic>?,
        imageUrl: json['imageUrl'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String),
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
        thresholdUsed: (json['thresholdUsed'] as num).toDouble(),
        faceId: json['faceId'] as String?,
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
        faceId: json['faceId'] as String,
        externalId: json['externalId'] as String? ?? '',
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
        queryTimeMs: json['queryTimeMs'] as int? ?? 0,
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
        isLive: json['isLive'] as bool,
        livenessScore: (json['livenessScore'] as num).toDouble(),
        faceDetected: json['faceDetected'] as bool,
        faceCount: json['faceCount'] as int? ?? 0,
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
      faceDetected: json['faceDetected'] as bool,
      faceCount: json['faceCount'] as int? ?? 0,
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

// ---------------------------------------------------------------------------
// Async batch registration
// ---------------------------------------------------------------------------

/// One face to enroll in a batch (sync or async) registration request.
class BatchRegisterItem {
  final String externalId;
  final Uint8List image;
  final Map<String, dynamic>? metadata;
  final String? filename;

  const BatchRegisterItem({
    required this.externalId,
    required this.image,
    this.metadata,
    this.filename,
  });
}

/// Outcome for one image of an async batch job.
class BatchJobResult {
  final int index;
  final String externalId;
  final String? faceId;
  final String? error;

  const BatchJobResult({
    required this.index,
    required this.externalId,
    this.faceId,
    this.error,
  });

  factory BatchJobResult.fromJson(Map<String, dynamic> json) => BatchJobResult(
        index: json['index'] as int? ?? 0,
        externalId: json['externalId'] as String? ?? '',
        faceId: json['faceId'] as String?,
        error: json['error'] as String?,
      );
}

/// An asynchronous batch registration job.
/// [status] is one of: `queued`, `processing`, `done`, `failed`.
class BatchJob {
  final String id;
  final String collectionId;
  final String status;
  final int total;
  final int processed;
  final int succeeded;
  final int failed;
  final List<BatchJobResult> results;
  final String createdAt;
  final String updatedAt;

  const BatchJob({
    required this.id,
    required this.collectionId,
    required this.status,
    required this.total,
    required this.processed,
    required this.succeeded,
    required this.failed,
    required this.results,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isFinished => status == 'done' || status == 'failed';

  factory BatchJob.fromJson(Map<String, dynamic> json) => BatchJob(
        id: json['id'] as String,
        collectionId: json['collectionId'] as String? ?? '',
        status: json['status'] as String? ?? '',
        total: json['total'] as int? ?? 0,
        processed: json['processed'] as int? ?? 0,
        succeeded: json['succeeded'] as int? ?? 0,
        failed: json['failed'] as int? ?? 0,
        results: (json['results'] as List<dynamic>? ?? const [])
            .map((r) => BatchJobResult.fromJson(r as Map<String, dynamic>))
            .toList(),
        createdAt: json['createdAt'] as String? ?? '',
        updatedAt: json['updatedAt'] as String? ?? '',
      );
}
