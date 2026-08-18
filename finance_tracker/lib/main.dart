import "package:finance_tracker/src/core/database/database_init.dart";
import 'package:finance_tracker/src/features/dashboard/presentation/dashboard_screen.dart';
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:finance_tracker/src/core/database/turso_client.dart";
import "package:finance_tracker/src/features/transactions/data/recurring_checker.dart";
import "package:finance_tracker/src/core/security/lock_screen.dart";
import "package:finance_tracker/src/core/security/security_service.dart";
import "package:finance_tracker/src/core/security/app_lifecycle_observer.dart";
import "package:finance_tracker/src/core/network/network_status_provider.dart";

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initDatabase();
  final recurringChecker = RecurringChecker(TursoClient());
  await recurringChecker.checkAndRunDueTransactions();

  runApp(const ProviderScope(child: FinanceTrackerApp()));
}

class FinanceTrackerApp extends ConsumerWidget {
  const FinanceTrackerApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(networkStatusProvider);

    return MaterialApp(
      title: "Finance Tracker",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      home: AppLifecycleObserver(child: const _InitialScreen()),
    );
  }
}

class _InitialScreen extends ConsumerStatefulWidget {
  const _InitialScreen();

  @override
  ConsumerState<_InitialScreen> createState() => _InitialScreenState();
}

class _InitialScreenState extends ConsumerState<_InitialScreen> {
  bool _isLoading = true;
  bool _shouldLock = false;

  @override
  void initState() {
    super.initState();
    _checkSecurity();
  }

  Future<void> _checkSecurity() async {
    final securityService = ref.read(securityServiceProvider);
    final pinConfigured = await securityService.isPinConfigured();
    final biometricAvailable = await securityService.canCheckBiometrics();

    if (mounted) {
      setState(() {
        // Kunci jika PIN sudah diatur atau biometrik tersedia
        _shouldLock = pinConfigured || biometricAvailable;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_shouldLock) {
      return const LockScreen();
    }

    return const DashboardScreen();
  }
}
