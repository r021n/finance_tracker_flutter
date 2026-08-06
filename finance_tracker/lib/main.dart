import "package:finance_tracker/src/core/database/database_init.dart";
import 'package:finance_tracker/src/features/wallets/presentation/wallet_list_screen.dart';
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initDatabase();

  runApp(const ProviderScope(child: FinanceTrackerApp()));
}

class FinanceTrackerApp extends StatelessWidget {
  const FinanceTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Finance Tracker",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: const WalletListScreen(),
    );
  }
}
