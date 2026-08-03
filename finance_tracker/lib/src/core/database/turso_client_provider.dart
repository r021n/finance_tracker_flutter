import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'turso_client.dart';

final tursoClientProvider = Provider<TursoClient>((ref) {
  return TursoClient();
});
