/// Idemity — Official Flutter/Dart SDK
///
/// Usage:
/// ```dart
/// import 'package:idemity/idemity.dart';
///
/// final client = IdemityClient(apiKey: 'idm_live_xxxxxxxx');
///
/// final result = await client.faces.verify(
///   collectionId: 'col_id',
///   image: imageBytes,
/// );
/// ```
library idemity;

export 'src/client.dart';
export 'src/types.dart';
export 'src/exceptions.dart';
