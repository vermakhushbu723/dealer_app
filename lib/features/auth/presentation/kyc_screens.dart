import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/contact_launcher.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../domain/dealer.dart';
import 'auth_providers.dart';

const kycDocuments = ['GST certificate', 'PAN card', 'FSSAI licence', 'Shop or trade licence'];
const businessTypes = [
  'Distributor',
  'Retail shop',
  'Restaurant / Hotel',
  'Caterer',
  'Bar / Cafe',
  'Fish / Meat seller',
  'Other',
];

class BusinessFields extends StatelessWidget {
  const BusinessFields({super.key, required this.controllers, required this.businessType, required this.onTypeChanged});

  final Map<String, TextEditingController> controllers;
  final String? businessType;
  final ValueChanged<String?> onTypeChanged;

  Widget _field(
    String key,
    String label, {
    String? Function(String?)? validator = Validators.required,
    TextInputType? keyboard,
    int? maxLength,
    bool upper = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LabeledField(
        label: label,
        child: TextFormField(
          controller: controllers[key],
          validator: validator,
          keyboardType: keyboard,
          maxLength: maxLength,
          textCapitalization: upper ? TextCapitalization.characters : TextCapitalization.words,
          inputFormatters: upper ? [_UpperCaseFormatter()] : null,
          decoration: InputDecoration(hintText: enterHint(label), counterText: ''),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _field('owner', 'Dealer name'),
        _field('business', 'Business name'),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: LabeledField(
            label: 'Business type',
            child: DropdownButtonFormField<String>(
              isExpanded: true,
              style: Theme.of(context).textTheme.bodyLarge,
              initialValue: businessTypes.contains(businessType) ? businessType : null,
              decoration: InputDecoration(hintText: selectHint('Business type')),
              items: [for (final t in businessTypes) DropdownMenuItem(value: t, child: Text(t))],
              validator: Validators.required,
              onChanged: onTypeChanged,
            ),
          ),
        ),
        _field('email', 'Email (optional)', validator: Validators.email, keyboard: TextInputType.emailAddress),
        _field('gstin', 'GSTIN', validator: Validators.gstin, maxLength: 15, upper: true),
        _field('pan', 'PAN', validator: Validators.pan, maxLength: 10, upper: true),
        _field('fssai', 'FSSAI number', validator: Validators.fssai, keyboard: TextInputType.number, maxLength: 14),
        _field('address', 'Shop address'),
        _field('city', 'City'),
        _field('pincode', 'PIN code', validator: Validators.pincode, keyboard: TextInputType.number, maxLength: 6),
      ],
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

Map<String, TextEditingController> businessControllers(Dealer d) => {
  'owner': TextEditingController(text: d.ownerName),
  'business': TextEditingController(text: d.businessName),
  'email': TextEditingController(text: d.email),
  'gstin': TextEditingController(text: d.gstin),
  'pan': TextEditingController(text: d.pan),
  'fssai': TextEditingController(text: d.fssai),
  'address': TextEditingController(text: d.addressLine),
  'city': TextEditingController(text: d.city),
  'pincode': TextEditingController(text: d.pincode),
};

Dealer applyBusinessFields(Dealer d, Map<String, TextEditingController> c, String? type) => d.copyWith(
  ownerName: c['owner']!.text.trim(),
  businessName: c['business']!.text.trim(),
  businessType: type,
  email: c['email']!.text.trim(),
  gstin: c['gstin']!.text.trim(),
  pan: c['pan']!.text.trim(),
  fssai: c['fssai']!.text.trim(),
  addressLine: c['address']!.text.trim(),
  city: c['city']!.text.trim(),
  pincode: c['pincode']!.text.trim(),
);

/// Lets the dealer pick a photo for each document in [kycDocuments].
class DocumentPicker extends StatelessWidget {
  const DocumentPicker({super.key, required this.documents, required this.onChanged});

  final Map<String, String> documents;
  final ValueChanged<Map<String, String>> onChanged;

  Future<void> _pick(BuildContext context, String name) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final XFile? file;
    try {
      file = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1600);
    } on PlatformException {
      if (context.mounted) {
        showMessage(
          context,
          'Please allow camera access for this app in your phone settings, then try again.',
          isError: true,
        );
      }
      return;
    }
    if (file != null) onChanged({...documents, name: file.path});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final name in kycDocuments)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              onTap: () => _pick(context, name),
              child: Row(
                children: [
                  Icon(
                    documents.containsKey(name) ? Icons.check_circle : Icons.upload_file_outlined,
                    color: documents.containsKey(name) ? AppColors.green600 : AppColors.sky600,
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(name)),
                  Text(documents.containsKey(name) ? 'Replace' : 'Upload'),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class KycScreen extends ConsumerStatefulWidget {
  const KycScreen({super.key});

  @override
  ConsumerState<KycScreen> createState() => _KycScreenState();
}

class _KycScreenState extends ConsumerState<KycScreen> {
  final _formKey = GlobalKey<FormState>();
  late final Dealer _dealer = ref.read(currentDealerProvider);
  late final _controllers = businessControllers(_dealer);
  late String? _type = _dealer.businessType;
  late Map<String, String> _documents = _dealer.documents;
  bool _loading = false;

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (kycDocuments.any((d) => !_documents.containsKey(d))) {
      showMessage(context, 'Please upload all the documents', isError: true);
      return;
    }
    setState(() => _loading = true);
    await ref
        .read(authControllerProvider.notifier)
        .submitKyc(applyBusinessFields(_dealer, _controllers, _type).copyWith(documents: _documents));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Business registration'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.page,
          children: [
            if (_dealer.kycStatus == KycStatus.rejected) ...[
              NoticeBanner('Your application was rejected: ${_dealer.rejectionReason}', color: AppColors.red600),
              const SizedBox(height: 12),
            ],
            BusinessFields(
              controllers: _controllers,
              businessType: _type,
              onTypeChanged: (v) => setState(() => _type = v),
            ),
            const SectionTitle('Documents'),
            DocumentPicker(documents: _documents, onChanged: (d) => setState(() => _documents = d)),
            const SizedBox(height: 12),
            LoadingButton(label: 'Submit for approval', loading: _loading, onPressed: _submit),
          ],
        ),
      ),
    );
  }
}

class KycPendingScreen extends ConsumerStatefulWidget {
  const KycPendingScreen({super.key});

  @override
  ConsumerState<KycPendingScreen> createState() => _KycPendingScreenState();
}

class _KycPendingScreenState extends ConsumerState<KycPendingScreen> {
  bool _loading = false;

  Future<void> _check() async {
    setState(() => _loading = true);
    await ref.read(authControllerProvider.notifier).refreshKycStatus();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Application status'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            child: const Text('Sign out'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(Icons.hourglass_top_rounded, size: 64, color: AppColors.sky400),
            const SizedBox(height: 12),
            Text(
              'Application under review',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Our team is checking your details. You can start ordering as soon as your account is approved.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            const NoticeBanner(
              'Demo: checking the status approves the application, because the admin panel is not built yet.',
            ),
            const SizedBox(height: 24),
            LoadingButton(label: 'Check status', loading: _loading, onPressed: _check),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: () => ContactLauncher.call(AppConstants.supportPhone),
              child: const Text('Call support'),
            ),
          ],
        ),
      ),
    );
  }
}
