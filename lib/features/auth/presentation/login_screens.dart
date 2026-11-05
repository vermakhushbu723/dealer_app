import 'dart:async';
import '../../../core/network/api_client.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../data/fake_auth_repository.dart';
import 'auth_providers.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(child: Image.asset(AppConstants.logo, width: 180)),
    );
  }
}

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _usePassword = false;
  bool _loading = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    final phone = _phone.text.trim();
    if (_usePassword) {
      try {
        // The router redirects away from this screen once the dealer is set.
        await ref.read(authControllerProvider.notifier).signInWithPassword(phone, _password.text);
      } catch (e) {
        if (!mounted) return;
        setState(() => _loading = false);
        showMessage(context, '$e', isError: true);
      }
      return;
    }
    await ref.read(authRepositoryProvider).sendOtp(phone);
    if (!mounted) return;
    setState(() => _loading = false);
    context.push(Routes.otp, extra: phone);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Image.asset(AppConstants.logo, height: 110),
                    const SizedBox(height: 32),
                    Text('Dealer sign in', style: text.headlineMedium),
                    const SizedBox(height: 4),
                    const Text('Order ice for your business across ${AppConstants.serviceArea}.'),
                    const SizedBox(height: 24),
                    LabeledField(
                      label: 'Mobile number',
                      child: TextFormField(
                        controller: _phone,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        validator: Validators.phone,
                        decoration: InputDecoration(
                          hintText: enterHint('Mobile number'),
                          prefixIcon: fieldPrefix('+91'),
                          counterText: '',
                        ),
                      ),
                    ),
                    if (_usePassword) ...[
                      const SizedBox(height: 12),
                      LabeledField(
                        label: 'Password',
                        child: TextFormField(
                          controller: _password,
                          obscureText: true,
                          validator: Validators.required,
                          decoration: InputDecoration(hintText: enterHint('Password')),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    LoadingButton(label: _usePassword ? 'Sign in' : 'Send OTP', loading: _loading, onPressed: _submit),
                    TextButton(
                      onPressed: () => setState(() => _usePassword = !_usePassword),
                      child: Text(_usePassword ? 'Forgot password? Sign in with OTP' : 'Sign in with password'),
                    ),
                    const SizedBox(height: 8),
                    if (showDemoHint)
                      const NoticeBanner(
                      'Demo: use $demoPhone for a ready account (OTP $demoOtp, password $demoPassword), '
                      'or any other number to try registration.',
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: () => ContactLauncher.call(AppConstants.supportPhone),
                      icon: const Icon(Icons.call_outlined, size: 18),
                      label: const Text('Need help? Call us'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key, required this.phone});

  final String phone;

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final _otp = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 30;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  void _startTimer() {
    _secondsLeft = 30;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() => _secondsLeft--);
      if (_secondsLeft == 0) timer.cancel();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_otp.text.length != 6) {
      showMessage(context, 'Enter the 6-digit OTP', isError: true);
      return;
    }
    setState(() => _loading = true);
    try {
      // The router redirects away from this screen once the dealer is set.
      await ref.read(authControllerProvider.notifier).verifyOtp(widget.phone, _otp.text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showMessage(context, '$e', isError: true);
    }
  }

  Future<void> _resend() async {
    await ref.read(authRepositoryProvider).sendOtp(widget.phone);
    if (!mounted) return;
    setState(_startTimer);
    showMessage(context, 'OTP sent again');
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text('Enter OTP', style: text.headlineMedium),
          const SizedBox(height: 4),
          Text('We sent a 6-digit code to +91 ${widget.phone}.'),
          const SizedBox(height: 24),
          TextField(
            controller: _otp,
            autofocus: true,
            keyboardType: TextInputType.number,
            maxLength: 6,
            textAlign: TextAlign.center,
            style: text.headlineMedium?.copyWith(letterSpacing: 10),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(hintText: 'Enter OTP', counterText: ''),
            onSubmitted: (_) => _verify(),
          ),
          const SizedBox(height: 12),
          LoadingButton(label: 'Verify and continue', loading: _loading, onPressed: _verify),
          const SizedBox(height: 8),
          _secondsLeft > 0
              ? Text('Resend OTP in ${_secondsLeft}s', textAlign: TextAlign.center)
              : TextButton(onPressed: _resend, child: const Text('Resend OTP')),
        ],
      ),
    );
  }
}
