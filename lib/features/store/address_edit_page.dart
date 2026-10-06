import '../../core/localization/locale_controller.dart';
import '../../core/localization/localized_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'store_models.dart';
import 'store_repository.dart';

class AddressEditPage extends StatefulWidget {
  const AddressEditPage({super.key, required this.repository, this.address});
  final StoreRepository repository;
  final Map<String, dynamic>? address;
  @override
  State<AddressEditPage> createState() => _AddressEditPageState();
}

class _AddressEditPageState extends State<AddressEditPage> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fields = {
      for (final key in [
        'label',
        'zip',
        'street',
        'number',
        'complement',
        'district',
        'city',
        'state'
      ])
        key: TextEditingController(
            text: key == 'zip'
                ? stringValue(widget.address?[key])
                    .replaceAll(RegExp(r'\D'), '')
                : stringValue(widget.address?[key]))
    };
  }

  @override
  void dispose() {
    for (final field in _fields.values) {
      field.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = <String, dynamic>{
        'id': widget.address?['id'] ?? 'new',
        for (final entry in _fields.entries) entry.key: entry.value.text.trim(),
      };
      await widget.repository.saveAddress(data);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(String key, String label,
          {bool required = true,
          int maxLength = 100,
          TextInputType keyboard = TextInputType.streetAddress}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: TextFormField(
          controller: _fields[key],
          enabled: !_saving,
          readOnly: key == 'label' && widget.address?['id'] == 'principal',
          decoration: LDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
              counterText: ''),
          maxLength: maxLength,
          keyboardType: keyboard,
          textCapitalization: key == 'state'
              ? TextCapitalization.characters
              : TextCapitalization.words,
          inputFormatters:
              key == 'zip' ? [FilteringTextInputFormatter.digitsOnly] : null,
          validator: (value) {
            final text = (value ?? '').trim();
            if (required && text.isEmpty) return tr('Preencha ${tr(label)}.');
            if (key == 'zip' && !RegExp(r'^\d{8}$').hasMatch(text))
              return tr('Informe os 8 dígitos do CEP.');
            if (key == 'state' &&
                !const [
                  'AC',
                  'AL',
                  'AP',
                  'AM',
                  'BA',
                  'CE',
                  'DF',
                  'ES',
                  'GO',
                  'MA',
                  'MT',
                  'MS',
                  'MG',
                  'PA',
                  'PB',
                  'PR',
                  'PE',
                  'PI',
                  'RJ',
                  'RN',
                  'RS',
                  'RO',
                  'RR',
                  'SC',
                  'SP',
                  'SE',
                  'TO'
                ].contains(text.toUpperCase()))
              return tr('Informe uma UF válida.');
            return null;
          },
        ),
      );

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: !_saving,
        child: Scaffold(
          appBar: AppBar(
              title: LText(widget.address == null
                  ? 'Novo endereço'
                  : 'Editar endereço')),
          body: Form(
              key: _form,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _field('label', 'Nome do endereço (Casa, Trabalho...)'),
                _field('zip', 'CEP',
                    maxLength: 8, keyboard: TextInputType.number),
                _field('street', 'Rua / Avenida'),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: _field('number', 'Número', maxLength: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                      child:
                          _field('complement', 'Complemento', required: false)),
                ]),
                _field('district', 'Bairro'),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(flex: 3, child: _field('city', 'Cidade')),
                  const SizedBox(width: 12),
                  Expanded(
                      child: _field('state', 'UF',
                          maxLength: 2, keyboard: TextInputType.text)),
                ]),
                if (_error != null)
                  Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: LText(_error!,
                          style: TextStyle(
                              color: Theme.of(context).colorScheme.error))),
                FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.save_outlined),
                    label: const LText('Salvar endereço')),
              ])),
        ),
      );
}
