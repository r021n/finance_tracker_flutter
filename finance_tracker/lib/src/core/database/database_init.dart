import "package:flutter_dotenv/flutter_dotenv.dart";
import "schema.dart";
import "turso_client.dart";

Future<void> initDatabase() async {
  await dotenv.load();

  final client = TursoClient.client;
  await client.connect();

  for (final schema in kInitSchemas) {
    await client.execute(schema);
  }
}
