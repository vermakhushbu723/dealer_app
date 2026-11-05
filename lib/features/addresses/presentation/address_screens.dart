import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/common_widgets.dart';
import '../domain/address.dart';
import 'address_providers.dart';

class AddressesScreen extends ConsumerWidget {
  const AddressesScreen({super.key});

  Future<void> _edit(BuildContext context, [Address? address]) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AddressFormScreen(address: address)));

  Future<void> _delete(BuildContext context, WidgetRef ref, Address address) async {
    final confirmed = await confirmDialog(
      context,
      title: 'Delete address?',
      message: address.singleLine,
      confirmLabel: 'Delete',
    );
    if (!confirmed) return;
    try {
      await ref.read(addressRepositoryProvider).delete(address.id);
      ref.invalidate(addressesProvider);
    } catch (e) {
      if (context.mounted) showMessage(context, '$e', isError: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Delivery addresses')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: const Text('Add address'),
      ),
      body: AsyncBody(
        value: ref.watch(addressesProvider),
        builder: (items) => items.isEmpty
            ? const EmptyState(icon: Icons.location_off_outlined, title: 'No addresses yet')
            : ListView.separated(
                padding: AppSpacing.pageWithFab,
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final a = items[i];
                  return AppCard(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(a.label, style: Theme.of(context).textTheme.titleSmall)),
                            if (a.isDefault) const StatusChip('Default'),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(a.singleLine),
                        Text('${a.contactName} · ${a.phone}'),
                        if (a.instructions.isNotEmpty) Text(a.instructions),
                        Row(
                          children: [
                            TextButton(onPressed: () => _edit(context, a), child: const Text('Edit')),
                            TextButton(onPressed: () => _delete(context, ref, a), child: const Text('Delete')),
                            if (!a.isDefault)
                              TextButton(
                                onPressed: () async {
                                  await ref.read(addressRepositoryProvider).setDefault(a.id);
                                  ref.invalidate(addressesProvider);
                                },
                                child: const Text('Make default'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
      ),
    );
  }
}

class AddressFormScreen extends ConsumerStatefulWidget {
  const AddressFormScreen({super.key, this.address});

  final Address? address;

  @override
  ConsumerState<AddressFormScreen> createState() => _AddressFormScreenState();
}

class _AddressFormScreenState extends ConsumerState<AddressFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _label = TextEditingController(text: widget.address?.label);
  late final _contact = TextEditingController(text: widget.address?.contactName);
  late final _phone = TextEditingController(text: widget.address?.phone);
  late final _line = TextEditingController(text: widget.address?.line);
  late final _city = TextEditingController(text: widget.address?.city);
  late final _pincode = TextEditingController(text: widget.address?.pincode);
  late final _instructions = TextEditingController(text: widget.address?.instructions);
  late bool _isDefault = widget.address?.isDefault ?? false;

  @override
  void dispose() {
    for (final c in [_label, _contact, _phone, _line, _city, _pincode, _instructions]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    await ref
        .read(addressRepositoryProvider)
        .save(
          Address(
            id: widget.address?.id ?? 'addr-${DateTime.now().millisecondsSinceEpoch}',
            label: _label.text.trim(),
            contactName: _contact.text.trim(),
            phone: _phone.text.trim(),
            line: _line.text.trim(),
            city: _city.text.trim(),
            pincode: _pincode.text.trim(),
            instructions: _instructions.text.trim(),
            isDefault: _isDefault,
          ),
        );
    ref.invalidate(addressesProvider);
    if (mounted) Navigator.pop(context);
  }

  Widget _field(
    TextEditingController c,
    String label, {
    String? Function(String?)? validator = Validators.required,
    TextInputType? keyboard,
    int? maxLength,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: LabeledField(
        label: label,
        child: TextFormField(
          controller: c,
          validator: validator,
          keyboardType: keyboard,
          maxLength: maxLength,
          maxLines: maxLines,
          inputFormatters: keyboard == TextInputType.phone || keyboard == TextInputType.number
              ? [FilteringTextInputFormatter.digitsOnly]
              : null,
          decoration: InputDecoration(hintText: enterHint(label), counterText: ''),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.address == null ? 'Add address' : 'Edit address')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: AppSpacing.page,
          children: [
            _field(_label, 'Label, for example Andheri outlet'),
            _field(_contact, 'Contact person'),
            _field(_phone, 'Contact number', validator: Validators.phone, keyboard: TextInputType.phone, maxLength: 10),
            _field(_line, 'Address', maxLines: 2),
            _field(_city, 'City'),
            _field(_pincode, 'PIN code', validator: Validators.pincode, keyboard: TextInputType.number, maxLength: 6),
            _field(_instructions, 'Delivery instructions (optional)', validator: null),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use as default address'),
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
            ),
            const SizedBox(height: 8),
            FilledButton(onPressed: _save, child: const Text('Save address')),
          ],
        ),
      ),
    );
  }
}
