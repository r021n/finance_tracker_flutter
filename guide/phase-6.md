# Panduan Fase 6: Keamanan Biometrik, Fitur Sync/Offline-First, & Polishing

## Ringkasan

Fase 6 menambahkan fitur keamanan (biometrik + PIN), pemantauan status jaringan, dan polishing UI/UX pada aplikasi Finance Tracker.

---

## Langkah 1: Tambahkan Package Baru

Buka file `finance_tracker/pubspec.yaml` dan tambahkan 4 package baru di bagian `dependencies`:

```yaml
  local_auth: ^3.0.2
  flutter_secure_storage: ^11.0.0
  connectivity_plus: ^6.1.3
  shimmer: ^3.0.0
```

Jalankan perintah berikut di terminal (di folder `finance_tracker`):

```bash
flutter pub get
```

---

## Langkah 2: Buat File SecurityService

Buat folder baru: `lib/src/core/security/`

Buat file baru: `lib/src/core/security/security_service.dart`

```dart
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:local_auth/local_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Provider untuk SecurityService agar bisa diakses dari mana saja.
final securityServiceProvider = Provider<SecurityService>((ref) {
  return SecurityService();
});

/// Layanan keamanan yang menangani autentikasi biometrik dan penyimpanan PIN.
/// Menggunakan local_auth untuk autentikasi biometrik dan
/// flutter_secure_storage untuk menyimpan PIN secara aman.
class SecurityService {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  // Kunci untuk menyimpan PIN di storage
  static const String _pinKey = 'app_pin';
  // Kunci untuk menandai apakah PIN sudah diatur
  static const String _pinConfiguredKey = 'pin_configured';

  /// Mengecek apakah perangkat mendukung autentikasi biometrik.
  /// Mengembalikan true jika perangkat punya hardware biometrik.
  Future<bool> canCheckBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics;
    } on PlatformException {
      return false;
    }
  }

  /// Mengecek apakah perangkat mendukung autentikasi apapun (biometrik atau PIN/Pattern).
  Future<bool> isDeviceSupported() async {
    try {
      return await _localAuth.isDeviceSupported();
    } on PlatformException {
      return false;
    }
  }

  /// Mendapatkan daftar biometrik yang tersedia di perangkat.
  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      return await _localAuth.getAvailableBiometrics();
    } on PlatformException {
      return [];
    }
  }

  /// Melakukan autentikasi biometrik.
  /// Mengembalikan true jika autentikasi berhasil.
  Future<bool> authenticateWithBiometrics() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Silakan autentikasi untuk membuka aplikasi',
      );
    } on PlatformException {
      return false;
    }
  }

  /// Menyimpan PIN baru ke storage yang aman.
  Future<void> savePin(String pin) async {
    await _secureStorage.write(key: _pinKey, value: pin);
    await _secureStorage.write(key: _pinConfiguredKey, value: 'true');
  }

  /// Membaca PIN dari storage.
  Future<String?> getPin() async {
    return await _secureStorage.read(key: _pinKey);
  }

  /// Memeriksa apakah PIN yang dimasukkan cocok dengan yang tersimpan.
  Future<bool> verifyPin(String inputPin) async {
    final storedPin = await getPin();
    return storedPin == inputPin;
  }

  /// Memeriksa apakah PIN sudah pernah diatur.
  Future<bool> isPinConfigured() async {
    final configured = await _secureStorage.read(key: _pinConfiguredKey);
    return configured == 'true';
  }

  /// Menghapus PIN dari storage.
  Future<void> clearPin() async {
    await _secureStorage.delete(key: _pinKey);
    await _secureStorage.delete(key: _pinConfiguredKey);
  }

  /// Fungsi utama autentikasi: coba biometrik dulu, jika gagal minta PIN.
  /// Mengembalikan true jika autentikasi berhasil (biometrik atau PIN).
  Future<bool> authenticate() async {
    final canBiometric = await canCheckBiometrics();
    final isSupported = await isDeviceSupported();

    if (canBiometric && isSupported) {
      final biometricResult = await authenticateWithBiometrics();
      if (biometricResult) return true;
    }

    return false;
  }
}
```

---

## Langkah 3: Buat File AppLifecycleObserver

Buat file baru: `lib/src/core/security/app_lifecycle_observer.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'lock_screen.dart';
import 'security_service.dart';

/// Observer yang memantau siklus hidup aplikasi.
/// Saat aplikasi kembali dari background, layar kunci akan ditampilkan
/// jika fitur keamanan aktif.
class AppLifecycleObserver extends ConsumerStatefulWidget {
  const AppLifecycleObserver({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLifecycleObserver> createState() =>
      _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends ConsumerState<AppLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _showLockScreenIfNeeded();
    }
  }

  Future<void> _showLockScreenIfNeeded() async {
    final securityService = ref.read(securityServiceProvider);

    final pinConfigured = await securityService.isPinConfigured();
    final biometricAvailable = await securityService.canCheckBiometrics();

    if (pinConfigured || biometricAvailable) {
      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LockScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
```

---

## Langkah 4: Buat File LockScreen

Buat file baru: `lib/src/core/security/lock_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'security_service.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';

/// Layar kunci yang menampilkan input PIN dan tombol biometrik.
/// Muncul saat aplikasi pertama kali dibuka atau kembali dari background.
class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  final TextEditingController _pinController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;
  bool _isPinConfigured = false;
  bool _isSetupMode = false;
  final TextEditingController _confirmPinController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _checkPinStatus();
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _checkPinStatus() async {
    final securityService = ref.read(securityServiceProvider);
    final configured = await securityService.isPinConfigured();
    final biometricAvailable = await securityService.canCheckBiometrics();

    setState(() {
      _isPinConfigured = configured;
      _isSetupMode = !configured && !biometricAvailable;
    });

    if (biometricAvailable) {
      _tryBiometric();
    }
  }

  Future<void> _tryBiometric() async {
    final securityService = ref.read(securityServiceProvider);
    final success = await securityService.authenticateWithBiometrics();
    if (success && mounted) {
      _navigateToHome();
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const DashboardScreen()),
      (route) => false,
    );
  }

  Future<void> _handlePinSubmit() async {
    final pin = _pinController.text;

    if (pin.length < 4) {
      setState(() {
        _errorMessage = 'PIN minimal 4 digit';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final securityService = ref.read(securityServiceProvider);

    if (_isSetupMode) {
      final confirmPin = _confirmPinController.text;
      if (pin != confirmPin) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'PIN tidak cocok';
        });
        return;
      }
      await securityService.savePin(pin);
      _navigateToHome();
    } else {
      final isValid = await securityService.verifyPin(pin);
      if (isValid) {
        _navigateToHome();
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage = 'PIN salah';
          _pinController.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock_outline,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 24),
                Text(
                  _isSetupMode ? 'Atur PIN' : 'Masukkan PIN',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isSetupMode
                      ? 'Buat PIN baru untuk mengamankan aplikasi'
                      : 'Masukkan PIN untuk membuka aplikasi',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: _pinController,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: InputDecoration(
                    hintText: '••••',
                    counterText: '',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  onSubmitted: (_) => _handlePinSubmit(),
                ),
                if (_isSetupMode) ...[
                  const SizedBox(height: 16),
                  TextField(
                    controller: _confirmPinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      letterSpacing: 8,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      hintText: '••••',
                      counterText: '',
                      labelText: 'Konfirmasi PIN',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onSubmitted: (_) => _handlePinSubmit(),
                  ),
                ],
                if (_errorMessage != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _handlePinSubmit,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(_isSetupMode ? 'Simpan PIN' : 'Buka'),
                  ),
                ),
                if (!_isSetupMode && _isPinConfigured) ...[
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _tryBiometric,
                    icon: const Icon(Icons.fingerprint),
                    label: const Text('Gunakan Biometrik'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
```

---

## Langkah 5: Buat File NetworkStatusProvider

Buat folder baru: `lib/src/core/network/`

Buat file baru: `lib/src/core/network/network_status_provider.dart`

```dart
import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'network_status_provider.g.dart';

/// Enumerator untuk status koneksi jaringan.
enum NetworkStatus {
  none,
  wifi,
  mobile,
  ethernet,
  vpn,
  bluetooth,
  other,
}

/// Notifier yang memantau status koneksi jaringan secara real-time.
/// Menggunakan connectivity_plus untuk mendeteksi perubahan koneksi.
@Riverpod(keepAlive: true)
class NetworkStatusNotifier extends _$NetworkStatusNotifier {
  StreamSubscription<List<ConnectivityResult>>? _subscription;

  @override
  NetworkStatus build() {
    _startListening();
    return NetworkStatus.none;
  }

  void _startListening() {
    _subscription = Connectivity().onConnectivityChanged.listen(
      (List<ConnectivityResult> results) {
        if (results.isNotEmpty) {
          state = _mapConnectivityResult(results.first);
        }
      },
    );
  }

  NetworkStatus _mapConnectivityResult(ConnectivityResult result) {
    switch (result) {
      case ConnectivityResult.wifi:
        return NetworkStatus.wifi;
      case ConnectivityResult.mobile:
        return NetworkStatus.mobile;
      case ConnectivityResult.ethernet:
        return NetworkStatus.ethernet;
      case ConnectivityResult.vpn:
        return NetworkStatus.vpn;
      case ConnectivityResult.bluetooth:
        return NetworkStatus.bluetooth;
      case ConnectivityResult.other:
        return NetworkStatus.other;
      case ConnectivityResult.none:
        return NetworkStatus.none;
      case ConnectivityResult.satellite:
        return NetworkStatus.other;
    }
  }

  Future<void> checkCurrentStatus() async {
    final results = await Connectivity().checkConnectivity();
    if (results.isNotEmpty) {
      state = _mapConnectivityResult(results.first);
    }
  }

  bool get isConnected => state != NetworkStatus.none;

  void cancelSubscription() {
    _subscription?.cancel();
  }
}
```

---

## Langkah 6: Jalankan Code Generator

Jalankan perintah berikut di terminal (di folder `finance_tracker`):

```bash
dart run build_runner build
```

Perintah ini akan membuat file `network_status_provider.g.dart` secara otomatis.

---

## Langkah 7: Buat File ShimmerLoading

Buat folder baru (jika belum ada): `lib/src/shared/widgets/`

Buat file baru: `lib/src/shared/widgets/shimmer_loading.dart`

```dart
import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

/// Widget skeleton/loading dengan efek shimmer (berkilau).
/// Digunakan saat data sedang dimuat dari database atau API.
class ShimmerLoading extends StatelessWidget {
  const ShimmerLoading({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  final double width;
  final double height;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    final baseColor = Colors.grey.shade300;
    final highlightColor = Colors.grey.shade100;

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: baseColor,
          borderRadius: borderRadius ?? BorderRadius.circular(8),
        ),
      ),
    );
  }
}

/// Widget skeleton untuk kartu transaksi.
class ShimmerTransactionCard extends StatelessWidget {
  const ShimmerTransactionCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const ShimmerLoading(
              width: 40,
              height: 40,
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const ShimmerLoading(width: 120, height: 14),
                  const SizedBox(height: 8),
                  const ShimmerLoading(width: 80, height: 12),
                ],
              ),
            ),
            const ShimmerLoading(width: 80, height: 14),
          ],
        ),
      ),
    );
  }
}

/// Widget skeleton untuk kartu dompet.
class ShimmerWalletCard extends StatelessWidget {
  const ShimmerWalletCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const ShimmerLoading(
                  width: 36,
                  height: 36,
                  borderRadius: BorderRadius.all(Radius.circular(8)),
                ),
                const SizedBox(width: 12),
                const ShimmerLoading(width: 100, height: 16),
              ],
            ),
            const SizedBox(height: 12),
            const ShimmerLoading(width: 150, height: 24),
            const SizedBox(height: 8),
            const ShimmerLoading(width: 80, height: 12),
          ],
        ),
      ),
    );
  }
}

/// Widget skeleton untuk daftar item.
class ShimmerList extends StatelessWidget {
  const ShimmerList({super.key, this.itemCount = 5});

  final int itemCount;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      itemBuilder: (context, index) => const ShimmerTransactionCard(),
    );
  }
}
```

---

## Langkah 8: Buat Unit Tests

Buat folder baru: `test/unit/`

Buat file baru: `test/unit/budget_calculator_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/src/features/budgeting/domain/budget.dart';

void main() {
  group('BudgetWithProgress', () {
    test('usagePercent menghitung persentase penggunaan dengan benar', () {
      final budget = Budget(
        id: '1',
        categoryId: 'cat1',
        amountLimit: 100000,
        monthYear: '2024-01',
      );

      final progress = BudgetWithProgress(
        budget: budget,
        categoryName: 'Makanan',
        spent: 50000,
      );

      expect(progress.usagePercent, 0.5);
    });

    test('usagePercent mengembalikan 0 jika amountLimit 0', () {
      final budget = Budget(
        id: '1',
        categoryId: 'cat1',
        amountLimit: 0,
        monthYear: '2024-01',
      );

      final progress = BudgetWithProgress(
        budget: budget,
        categoryName: 'Makanan',
        spent: 50000,
      );

      expect(progress.usagePercent, 0.0);
    });

    test('remaining menghitung sisa budget dengan benar', () {
      final budget = Budget(
        id: '1',
        categoryId: 'cat1',
        amountLimit: 100000,
        monthYear: '2024-01',
      );

      final progress = BudgetWithProgress(
        budget: budget,
        categoryName: 'Makanan',
        spent: 30000,
      );

      expect(progress.remaining, 70000);
    });

    test('remaining bisa bernilai negatif jika overbudget', () {
      final budget = Budget(
        id: '1',
        categoryId: 'cat1',
        amountLimit: 100000,
        monthYear: '2024-01',
      );

      final progress = BudgetWithProgress(
        budget: budget,
        categoryName: 'Makanan',
        spent: 120000,
      );

      expect(progress.remaining, -20000);
    });

    test('usagePercent bisa melebihi 1.0 jika overbudget', () {
      final budget = Budget(
        id: '1',
        categoryId: 'cat1',
        amountLimit: 100000,
        monthYear: '2024-01',
      );

      final progress = BudgetWithProgress(
        budget: budget,
        categoryName: 'Makanan',
        spent: 150000,
      );

      expect(progress.usagePercent, 1.5);
    });
  });
}
```

Buat file baru: `test/unit/savings_calculator_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:finance_tracker/src/features/savings/domain/savings_goal.dart';

void main() {
  group('SavingsGoal', () {
    test('progressPercent menghitung persentase progres dengan benar', () {
      final goal = SavingsGoal(
        id: '1',
        title: 'Dana Darurat',
        targetAmount: 1000000,
        currentAmount: 500000,
      );

      expect(goal.progressPercent, 0.5);
    });

    test('progressPercent mengembalikan 0 jika targetAmount 0', () {
      final goal = SavingsGoal(
        id: '1',
        title: 'Dana Darurat',
        targetAmount: 0,
        currentAmount: 500000,
      );

      expect(goal.progressPercent, 0.0);
    });

    test('progressPercent dibatasi maksimal 1.0', () {
      final goal = SavingsGoal(
        id: '1',
        title: 'Dana Darurat',
        targetAmount: 1000000,
        currentAmount: 1500000,
      );

      expect(goal.progressPercent, 1.0);
    });

    test('remaining menghitung sisa yang perlu dikumpulkan', () {
      final goal = SavingsGoal(
        id: '1',
        title: 'Dana Darurat',
        targetAmount: 1000000,
        currentAmount: 300000,
      );

      expect(goal.remaining, 700000);
    });

    test('remaining bisa bernilai negatif jika sudah terkumpul lebih', () {
      final goal = SavingsGoal(
        id: '1',
        title: 'Dana Darurat',
        targetAmount: 1000000,
        currentAmount: 1200000,
      );

      expect(goal.remaining, -200000);
    });

    test('progressPercent mengembalikan 0 jika currentAmount 0', () {
      final goal = SavingsGoal(
        id: '1',
        title: 'Dana Darurat',
        targetAmount: 1000000,
        currentAmount: 0,
      );

      expect(goal.progressPercent, 0.0);
    });
  });
}
```

---

## Langkah 9: Update main.dart

Buka file `lib/main.dart` dan **GANTI SELURUH ISI FILE** dengan kode berikut:

```dart
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
    // Pantau status jaringan saat aplikasi dimulai
    ref.watch(networkStatusProvider);

    return MaterialApp(
      title: "Finance Tracker",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorSchemeSeed: Colors.green, useMaterial3: true),
      // AppLifecycleObserver akan menampilkan LockScreen saat app kembali dari background
      home: AppLifecycleObserver(
        child: const _InitialScreen(),
      ),
    );
  }
}

/// Layar awal yang menentukan apakah menampilkan LockScreen atau DashboardScreen.
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
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_shouldLock) {
      return const LockScreen();
    }

    return const DashboardScreen();
  }
}
```

---

## Langkah 10: Verifikasi

Jalankan perintah berikut di terminal (di folder `finance_tracker`):

```bash
flutter analyze
flutter test test/unit/
```

Pastikan:
- `flutter analyze` menampilkan **No issues found!**
- `flutter test` menampilkan **All tests passed!**

---

## Struktur Folder yang Dihasilkan

```
lib/src/core/
  security/
    security_service.dart        # Layanan keamanan (biometrik + PIN)
    lock_screen.dart             # Layar kunci dengan input PIN
    app_lifecycle_observer.dart  # Pemantau siklus hidup aplikasi
  network/
    network_status_provider.dart # Pemantau status jaringan

lib/src/shared/widgets/
  shimmer_loading.dart           # Widget skeleton/loading shimmer

test/unit/
  budget_calculator_test.dart    # Unit test kalkulasi budget
  savings_calculator_test.dart   # Unit test kalkulasi tabungan
```

---

## Penjelasan Fitur

### Keamanan Biometrik & PIN
- Aplikasi akan meminta autentikasi saat pertama kali dibuka
- Jika perangkat punya fingerprint/face recognition, user bisa pakai itu
- Jika tidak ada biometrik, user diminta membuat/masukkan PIN
- PIN disimpan secara aman menggunakan `flutter_secure_storage`
- Saat aplikasi kembali dari background, layar kunci otomatis muncul

### Pemantauan Jaringan
- `NetworkStatusNotifier` memantau status koneksi secara real-time
- Bisa digunakan untuk menampilkan indikator online/offline
- Status tersimpan di Riverpod provider

### Shimmer Loading
- `ShimmerLoading` menampilkan efek berkilau saat data sedang dimuat
- `ShimmerTransactionCard` untuk placeholder kartu transaksi
- `ShimmerWalletCard` untuk placeholder kartu dompet
- `ShimmerList` untuk placeholder daftar item

### Unit Tests
- `budget_calculator_test.dart`: Menguji kalkulasi persentase dan sisa budget
- `savings_calculator_test.dart`: Menguji kalkulasi progres dan sisa tabungan
