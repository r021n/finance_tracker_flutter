import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:libsql_dart/libsql_dart.dart";
import "turso_client.dart";

final tursoClientProvider = Provider<LibsqlClient>((ref) {
  return TursoClient.client;
});
