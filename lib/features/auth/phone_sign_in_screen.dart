import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/widgets/edged_logo.dart';
import '../../data/services/auth_service.dart';
import '../../providers/app_providers.dart';

class PhoneSignInScreen extends ConsumerStatefulWidget {
  const PhoneSignInScreen({super.key});

  @override
  ConsumerState<PhoneSignInScreen> createState() => _PhoneSignInScreenState();
}

class _PhoneSignInScreenState extends ConsumerState<PhoneSignInScreen> {
  final _codeController = TextEditingController(text: '+1');
  final _phoneController = TextEditingController();
  bool _isSending = false;
  String? _error;
  List<CountryCode> _suggestions = [];

  @override
  void dispose() {
    _codeController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  void _onCodeChanged(String value) {
    final query = value.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _suggestions = []);
      return;
    }
    final matches = AuthService.allCountries
        .where(
          (c) =>
              c.code.toLowerCase().contains(query) ||
              c.name.toLowerCase().contains(query),
        )
        .take(6)
        .toList();
    setState(() => _suggestions = matches);
  }

  void _openCountryPicker() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        var filter = '';
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final filtered = AuthService.allCountries.where((c) {
              if (filter.isEmpty) return true;
              final q = filter.toLowerCase();
              return c.name.toLowerCase().contains(q) ||
                  c.code.toLowerCase().contains(q);
            }).toList();

            return DraggableScrollableSheet(
              expand: false,
              initialChildSize: 0.65,
              maxChildSize: 0.9,
              builder: (_, scrollCtrl) => Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: TextField(
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.search),
                        hintText: 'Search country or code...',
                      ),
                      onChanged: (v) => setModalState(() => filter = v),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollCtrl,
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final country = filtered[i];
                        return ListTile(
                          leading: Text(
                            country.flag,
                            style: const TextStyle(fontSize: 22),
                          ),
                          title: Text(country.name),
                          trailing: Text(
                            country.code,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          onTap: () {
                            _codeController.text = country.code;
                            setState(() => _suggestions = []);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _sendCode() async {
    final code = _codeController.text.trim();
    final phone = _phoneController.text.trim();

    if (!code.startsWith('+') || code.length < 2) {
      setState(() => _error = 'Enter a valid country code (e.g. +1).');
      return;
    }
    if (phone.isEmpty || phone.length < 4) {
      setState(() => _error = 'Enter your phone number.');
      return;
    }

    setState(() {
      _error = null;
      _isSending = true;
    });

    try {
      final fullPhone = '$code $phone';
      final otp = await ref.read(authServiceProvider).sendOtp(fullPhone);
      if (!mounted) return;
      context.push('/auth/otp', extra: {'phone': fullPhone, 'otp': otp});
    } catch (e) {
      setState(() => _error = 'Failed to send code: $e');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(child: EdgedLogo(size: 84, borderRadius: 22)),
                  const SizedBox(height: 18),
                  Text(
                    'Edged',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your private, offline AI assistant',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 36),
                  Text(
                    'Enter your phone number',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "We'll send a one-time code to verify your identity.",
                    style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 108,
                        child: TextField(
                          controller: _codeController,
                          keyboardType: TextInputType.phone,
                          onChanged: _onCodeChanged,
                          decoration: InputDecoration(
                            hintText: '+1',
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.arrow_drop_down),
                              onPressed: _openCountryPicker,
                              tooltip: 'Pick country',
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _sendCode(),
                          decoration: const InputDecoration(
                            hintText: 'Phone number',
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_suggestions.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Card(
                      child: Column(
                        children: _suggestions
                            .map(
                              (c) => ListTile(
                                dense: true,
                                title: Text(c.displayLabel),
                                onTap: () {
                                  _codeController.text = c.code;
                                  setState(() => _suggestions = []);
                                },
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _isSending ? null : _sendCode,
                    child: _isSending
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Send Code'),
                  ),
                  const SizedBox(height: 28),
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'About Edged',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Edged is an early MVP — a private, fully offline AI assistant.\n'
                    'In active development towards a full product.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(color: muted),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Built by Sambeet Das',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
