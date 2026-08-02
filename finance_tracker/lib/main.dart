import "package:finance_tracker/src/core/database/database_init.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initDatabase();

  runApp(const ProviderScope(child: FinanceTrackerApp()));
}
