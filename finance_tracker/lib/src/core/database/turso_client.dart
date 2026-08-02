import "package:flutter_dotenv/flutter_dotenv.dart";
import "package:libsql_dart/libsql_dart.dart";

class TursoClient {
  static LibsqlClient? _instance;

  static String get _databaseUrl =>
      dotenv.env["TURSO_DATABASE_URL"] ??
      (throw StateError("TURSO_DATABASE_URL tidak di-set di .env"));

  static String get _authToken =>
      dotenv.env["TURSO_AUTH_TOKEN"] ??
      (throw StateError("TURSO_AUTH_TOKEN tidak di-set di .env"));

  static LibsqlClient get client {
    _instance ??= LibsqlClient.remote(_databaseUrl, authToken: _authToken);
    return _instance!;
  }
}
