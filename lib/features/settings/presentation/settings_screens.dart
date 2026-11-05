import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../../auth/presentation/auth_providers.dart';

Future<void> confirmLogout(BuildContext context, WidgetRef ref) async {
  final confirmed = await confirmDialog(
    context,
    title: 'Log out?',
    message: 'You can sign back in with your mobile number.',
    confirmLabel: 'Log out',
  );
  if (confirmed) await ref.read(authControllerProvider.notifier).logout();
}

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: const Icon(Icons.lock_outline, color: AppColors.sky700),
            title: const Text('Change password'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.changePassword),
          ),
          ListTile(
            leading: const Icon(Icons.manage_accounts_outlined, color: AppColors.sky700),
            title: const Text('Manage account'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push(Routes.manageAccount),
          ),
          ListTile(
            leading: const Icon(Icons.logout, color: AppColors.neutral700),
            title: const Text('Logout'),
            onTap: () => confirmLogout(context, ref),
          ),
        ],
      ),
    );
  }
}

class ManageAccountScreen extends ConsumerWidget {
  const ManageAccountScreen({super.key});

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete account?',
      message: 'Your account and its order history on this device will be permanently removed.',
      confirmLabel: 'Delete account',
    );
    if (confirmed) await ref.read(authControllerProvider.notifier).deleteAccount();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget item(IconData icon, String title, String route) => ListTile(
      leading: Icon(icon, color: AppColors.sky700),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(route),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Manage account')),
      body: ListView(
        children: [
          item(Icons.storefront_outlined, 'Business profile', Routes.businessProfile),
          item(Icons.verified_user_outlined, 'KYC documents', Routes.documents),
          item(Icons.location_on_outlined, 'Delivery addresses', Routes.addresses),
          item(Icons.notifications_none, 'Notification settings', Routes.notificationSettings),
          const Divider(height: 24),
          ListTile(
            leading: const Icon(Icons.delete_outline, color: AppColors.red600),
            title: const Text('Delete account', style: TextStyle(color: AppColors.red600)),
            onTap: () => _delete(context, ref),
          ),
        ],
      ),
    );
  }
}

final _hasPasswordProvider = FutureProvider.autoDispose<bool>((ref) => ref.watch(authRepositoryProvider).hasPassword());

class ChangePasswordScreen extends ConsumerStatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  ConsumerState<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends ConsumerState<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(current: _current.text, next: _next.text);
      if (!mounted) return;
      showMessage(context, 'Password updated');
      context.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      showMessage(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Change password')),
      body: AsyncBody(
        value: ref.watch(_hasPasswordProvider),
        builder: (hasPassword) => Form(
          key: _formKey,
          child: ListView(
            padding: AppSpacing.page,
            children: [
              if (hasPassword) ...[
                LabeledField(
                  label: 'Current password',
                  child: TextFormField(
                    controller: _current,
                    obscureText: true,
                    validator: Validators.required,
                    decoration: InputDecoration(hintText: enterHint('Current password')),
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                const NoticeBanner(
                  'You have been signing in with OTP. Set a password to also sign in with your mobile number and password.',
                  color: AppColors.sky600,
                ),
                const SizedBox(height: 12),
              ],
              LabeledField(
                label: 'New password',
                child: TextFormField(
                  controller: _next,
                  obscureText: true,
                  validator: Validators.password,
                  decoration: InputDecoration(
                    hintText: enterHint('New password'),
                    helperText: 'At least 8 characters, with letters and numbers',
                  ),
                ),
              ),
              const SizedBox(height: 12),
              LabeledField(
                label: 'Confirm new password',
                child: TextFormField(
                  controller: _confirm,
                  obscureText: true,
                  validator: (v) => v == _next.text ? null : 'Passwords do not match',
                  decoration: InputDecoration(hintText: enterHint('Confirm new password')),
                ),
              ),
              const SizedBox(height: 12),
              LoadingButton(label: 'Update password', loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
