/// FR-APIaaS — Official Flutter/Dart SDK
///
/// Usage:
/// ```dart
/// import 'package:fr_apiaas/fr_apiaas.dart';
///
/// final client = FrApiClient(apiKey: 'fr_live_xxxxxxxx');
///
/// final result = await client.faces.verify(
///   collectionId: 'col_id',
///   image: imageBytes,
/// );
/// ```
library fr_apiaas;

export 'src/client.dart';
export 'src/types.dart';
export 'src/exceptions.dart';
