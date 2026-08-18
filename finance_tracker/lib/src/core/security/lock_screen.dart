import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'security_service.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';

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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey),
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
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
