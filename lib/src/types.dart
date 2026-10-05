/// Data models returned by the LiveXFace API.
library;

import 'dart:typed_data';

// ---------------------------------------------------------------------------
// Face Collection
// ---------------------------------------------------------------------------

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

class CrossCollectionSearchMatch extends IdentifyMatch {
  final String collectionId;

  const CrossCollectionSearchMatch({
    required super.faceId,
    required super.externalId,
    required super.confidence,
    super.metadata,
    required this.collectionId,
  });

  factory CrossCollectionSearchMatch.fromJson(Map<String, dynamic> json) =>
      CrossCollectionSearchMatch(
        faceId: json['faceId'] as String,
        externalId: json['externalId'] as String? ?? '',
        confidence: (json['confidence'] as num).toDouble(),
        metadata: json['metadata'] as Map<String, dynamic>?,
        collectionId: json['collectionId'] as String? ?? '',
      );
}

class SkippedCollection {
  final String id;
  final String name;
  final String reason;

  const SkippedCollection(
      {required this.id, required this.name, required this.reason});

  factory SkippedCollection.fromJson(Map<String, dynamic> json) =>
      SkippedCollection(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        reason: json['reason'] as String? ?? '',
      );
}

class CrossCollectionSearchResult {
  final List<CrossCollectionSearchMatch> matches;
  final int queryTimeMs;
  final int collectionsSearched;
  final List<SkippedCollection> skippedCollections;

  const CrossCollectionSearchResult(
      {required this.matches,
      required this.queryTimeMs,
      required this.collectionsSearched,
      required this.skippedCollections});

  factory CrossCollectionSearchResult.fromJson(Map<String, dynamic> json) =>
      CrossCollectionSearchResult(
        matches: (json['matches'] as List<dynamic>? ?? [])
            .map((e) =>
                CrossCollectionSearchMatch.fromJson(e as Map<String, dynamic>))
            .toList(),
        queryTimeMs: json['queryTimeMs'] as int? ?? 0,
        collectionsSearched: json['collectionsSearched'] as int? ?? 0,
        skippedCollections: (json['skippedCollections'] as List<dynamic>? ?? [])
            .map((e) => SkippedCollection.fromJson(e as Map<String, dynamic>))
            .toList(),
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
// Active liveness
// ---------------------------------------------------------------------------

/// Outcome of one active-liveness challenge. [metrics] keeps every key the
/// server sent, including challenge-specific measurements.
class LivenessChallenge {
  /// `null` when the challenge could not be evaluated.
  final bool? passed;
  final bool available;
  final Map<String, dynamic> metrics;

  const LivenessChallenge({
    this.passed,
    required this.available,
    this.metrics = const {},
  });

  factory LivenessChallenge.fromJson(Map<String, dynamic> json) =>
      LivenessChallenge(
        passed: json['passed'] as bool?,
        available: json['available'] as bool? ?? false,
        metrics: Map<String, dynamic>.from(json),
      );
}

class LivenessChallenges {
  final LivenessChallenge blink;
  final LivenessChallenge headTurn;
  final LivenessChallenge passiveAntispoof;

  const LivenessChallenges({
    required this.blink,
    required this.headTurn,
    required this.passiveAntispoof,
  });

  factory LivenessChallenges.fromJson(Map<String, dynamic> json) {
    LivenessChallenge parse(String key) => LivenessChallenge.fromJson(
        json[key] as Map<String, dynamic>? ?? const {});
    return LivenessChallenges(
      blink: parse('blink'),
      headTurn: parse('headTurn'),
      passiveAntispoof: parse('passiveAntispoof'),
    );
  }
}

/// The verdict of the stateless active-liveness check. It never carries a
/// liveness token: only a completed [LivenessSession] earns one.
class ActiveLivenessResult {
  final bool isLive;
  final double overallScore;
  final int framesAnalyzed;
  final int framesWithFace;
  final LivenessChallenges challenges;

  const ActiveLivenessResult({
    required this.isLive,
    required this.overallScore,
    required this.framesAnalyzed,
    required this.framesWithFace,
    required this.challenges,
  });

  factory ActiveLivenessResult.fromJson(Map<String, dynamic> json) =>
      ActiveLivenessResult(
        isLive: json['isLive'] as bool? ?? false,
        overallScore: (json['overallScore'] as num? ?? 0).toDouble(),
        framesAnalyzed: json['framesAnalyzed'] as int? ?? 0,
        framesWithFace: json['framesWithFace'] as int? ?? 0,
        challenges: LivenessChallenges.fromJson(
            json['challenges'] as Map<String, dynamic>? ?? const {}),
      );
}

// ---------------------------------------------------------------------------
// Liveness sessions
// ---------------------------------------------------------------------------

/// A liveness session: the steps the person must perform, in order, before
/// [expiresAt] (60 seconds after creation by default).
class LivenessSession {
  final String sessionId;

  /// Step types in order: `blink`, `turn_left` or `turn_right`. Left and
  /// right are the person's own, whatever the preview shows.
  final List<String> challenges;
  final DateTime expiresAt;

  const LivenessSession({
    required this.sessionId,
    required this.challenges,
    required this.expiresAt,
  });

  factory LivenessSession.fromJson(Map<String, dynamic> json) =>
      LivenessSession(
        sessionId: json['sessionId'] as String,
        challenges: [
          for (final c in json['challenges'] as List<dynamic>? ?? const [])
            (c as Map<String, dynamic>)['type'] as String,
        ],
        expiresAt: DateTime.parse(json['expiresAt'] as String),
      );
}

/// One step of a completed session and whether it was seen, in order.
class LivenessStep {
  final String type;
  final bool passed;

  const LivenessStep({required this.type, required this.passed});

  factory LivenessStep.fromJson(Map<String, dynamic> json) => LivenessStep(
        type: json['type'] as String? ?? '',
        passed: json['passed'] as bool? ?? false,
      );
}

/// The verdict on a liveness session: the active-liveness fields plus
/// [steps], and a token when it passed.
class LivenessSessionResult extends ActiveLivenessResult {
  final List<LivenessStep> steps;

  /// Single-use enrolment token, present only when the session passed. Valid
  /// for 5 minutes and bound to the session's collection.
  final String? livenessToken;
  final DateTime? livenessTokenExpiresAt;

  const LivenessSessionResult({
    required super.isLive,
    required super.overallScore,
    required super.framesAnalyzed,
    required super.framesWithFace,
    required super.challenges,
    required this.steps,
    this.livenessToken,
    this.livenessTokenExpiresAt,
  });

  factory LivenessSessionResult.fromJson(Map<String, dynamic> json) {
    final base = ActiveLivenessResult.fromJson(json);
    final expiresAt = json['livenessTokenExpiresAt'] as String?;
    return LivenessSessionResult(
      isLive: base.isLive,
      overallScore: base.overallScore,
      framesAnalyzed: base.framesAnalyzed,
      framesWithFace: base.framesWithFace,
      challenges: base.challenges,
      steps: [
        for (final s in json['steps'] as List<dynamic>? ?? const [])
          LivenessStep.fromJson(s as Map<String, dynamic>),
      ],
      livenessToken: json['livenessToken'] as String?,
      livenessTokenExpiresAt:
          expiresAt != null ? DateTime.parse(expiresAt) : null,
    );
  }
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

// ---------------------------------------------------------------------------
// Batch registration
// ---------------------------------------------------------------------------

/// One face to enroll in a batch (sync or async) registration request.
class BatchRegisterItem {
  final String externalId;
  final Uint8List image;
  final Map<String, dynamic>? metadata;
  final String? filename;

  /// Token from `FacesApi.completeLivenessSession`; required by collections
  /// that require liveness.
  final String? livenessToken;

  const BatchRegisterItem({
    required this.externalId,
    required this.image,
    this.metadata,
    this.filename,
    this.livenessToken,
  });
}

/// Outcome for one item of a synchronous batch registration: [face] when it
/// was enrolled, else [error].
class BatchFaceResult {
  final String externalId;
  final Face? face;
  final String? error;

  const BatchFaceResult({required this.externalId, this.face, this.error});

  factory BatchFaceResult.fromJson(Map<String, dynamic> json) =>
      BatchFaceResult(
        externalId: json['externalId'] as String? ?? '',
        face: json['face'] == null
            ? null
            : Face.fromJson(json['face'] as Map<String, dynamic>),
        error: json['error'] as String?,
      );
}

/// The result of a synchronous batch registration.
class BatchResponse {
  final int succeeded;
  final int failed;
  final List<BatchFaceResult> results;

  const BatchResponse({
    required this.succeeded,
    required this.failed,
    required this.results,
  });

  factory BatchResponse.fromJson(Map<String, dynamic> json) => BatchResponse(
        succeeded: json['succeeded'] as int? ?? 0,
        failed: json['failed'] as int? ?? 0,
        results: (json['results'] as List<dynamic>? ?? const [])
            .map((r) => BatchFaceResult.fromJson(r as Map<String, dynamic>))
            .toList(),
      );
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
