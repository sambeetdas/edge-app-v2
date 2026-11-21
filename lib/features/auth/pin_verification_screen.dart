import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/edged_logo.dart';
import '../../providers/app_providers.dart';

class PinVerificationScreen extends ConsumerStatefulWidget {
  final String phoneNumber;
  final bool hasPin;

  const PinVerificationScreen({
    super.key,
    required this.phoneNumber,
    required this.hasPin,
  });

  @override
  ConsumerState<PinVerificationScreen> createState() =>
      _PinVerificationScreenState();
}

class _PinVerificationScreenState extends ConsumerState<PinVerificationScreen> {
  final _pinController = TextEditingController();
  final _confirmPinController = TextEditingController();
  late bool _hasPin = widget.hasPin;
  bool _obscurePin = true;
  bool _isSubmitting = false;
  String? _error;

  @override
  void dispose() {
    _pinController.dispose();
    _confirmPinController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinController.text.trim();
    if (!RegExp(r'^\d{4,6}$').hasMatch(pin)) {
      setState(() => _error = 'Enter a 4 to 6-digit numeric PIN.');
      return;
    }

    if (!_hasPin) {
      final confirm = _confirmPinController.text.trim();
      if (pin != confirm) {
        setState(() => _error = 'PINs do not match.');
        return;
      }
    }

    setState(() {
      _error = null;
      _isSubmitting = true;
    });

    try {
      final auth = ref.read(authServiceProvider);
      if (_hasPin) {
        final ok = await auth.verifyPin(pin);
        if (!mounted) return;
        if (!ok) {
          setState(() {
            _isSubmitting = false;
            _error = 'Incorrect PIN. Please try again.';
          });
          return;
        }
      } else {
        await auth.setupPin(widget.phoneNumber, pin);
        if (!mounted) return;
      }

      await ref.read(downloadedModelProvider.notifier).refresh();
      if (!mounted) return;
      context.go('/home');
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _error = 'Authentication failed: $e';
      });
    }
  }

  Future<void> _resetPin() async {
    await ref.read(authServiceProvider).resetPin();
    if (!mounted) return;
    _pinController.clear();
    _confirmPinController.clear();
    setState(() {
      _hasPin = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_hasPin ? 'Enter PIN' : 'Create PIN')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: EdgedLogo(size: 64, borderRadius: 16)),
                  const SizedBox(height: 20),
                  Text(
                    _hasPin ? 'Enter your PIN' : 'Create your PIN',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _hasPin
                        ? 'Unlock Edged for ${widget.phoneNumber}'
                        : 'Set a 4 to 6-digit PIN for ${widget.phoneNumber}',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  TextField(
                    controller: _pinController,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    obscureText: _obscurePin,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      letterSpacing: 8,
                      fontWeight: FontWeight.w700,
                    ),
                    decoration: InputDecoration(
                      labelText: _hasPin ? 'PIN' : 'New PIN',
                      hintText: '••••••',
                      counterText: '',
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePin
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                        onPressed: () =>
                            setState(() => _obscurePin = !_obscurePin),
                      ),
                    ),
                    onSubmitted: (_) {
                      if (_hasPin) _submit();
                    },
                  ),
                  if (!_hasPin) ...[
                    const SizedBox(height: 16),
                    TextField(
                      controller: _confirmPinController,
                      keyboardType: TextInputType.number,
                      maxLength: 6,
                      obscureText: _obscurePin,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(
                        letterSpacing: 8,
                        fontWeight: FontWeight.w700,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Confirm PIN',
                        hintText: '••••••',
                        counterText: '',
                      ),
                      onSubmitted: (_) => _submit(),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(
                            _hasPin
                                ? 'Unlock & Continue'
                                : 'Save PIN & Continue',
                          ),
                  ),
                  if (_hasPin) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _isSubmitting ? null : _resetPin,
                      child: const Text('Forgot PIN? Reset'),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
