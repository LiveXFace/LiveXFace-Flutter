/// LiveXFace — Official Flutter/Dart SDK
///
/// Usage:
/// ```dart
/// import 'package:livexface/livexface.dart';
///
/// final client = LiveXFaceClient(apiKey: 'lxf_live_xxxxxxxx');
///
/// final result = await client.faces.verify(
///   collectionId: 'col_id',
///   image: imageBytes,
///   faceId: 'face_id',
/// );
/// ```
library livexface;

export 'src/client.dart';
export 'src/types.dart';
export 'src/exceptions.dart';
