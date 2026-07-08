/// Serupa — Official Flutter/Dart SDK
///
/// Usage:
/// ```dart
/// import 'package:serupa/serupa.dart';
///
/// final client = SerupaClient(apiKey: 'srp_live_xxxxxxxx');
///
/// final result = await client.faces.verify(
///   collectionId: 'col_id',
///   image: imageBytes,
/// );
/// ```
library serupa;

export 'src/client.dart';
export 'src/types.dart';
export 'src/exceptions.dart';
