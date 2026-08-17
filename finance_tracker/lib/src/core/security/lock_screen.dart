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
    return Scaffold(backgroundColor: Theme.of(context).colorScheme.surface);
  }
}
