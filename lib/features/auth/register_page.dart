import 'package:flutter/material.dart';

import '../../core/models/bootstrap_config.dart';
import '../../core/network/api_client.dart';
import 'auth_repository.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    required this.auth,
    required this.bootstrap,
    this.googleIdToken,
    this.prefillName,
    this.prefillEmail,
  });

  final AuthRepository auth;
  final AppBootstrap bootstrap;
  final String? googleIdToken;
  final String? prefillName;
  final String? prefillEmail;

  bool get isGoogle => googleIdToken != null && googleIdToken!.isNotEmpty;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  late final TextEditingController _name;
  final _document = TextEditingController();
  late final TextEditingController _email;
  final _phone = TextEditingController();
  final _zip = TextEditingController();
  final _street = TextEditingController();
  final _number = TextEditingController();
  final _district = TextEditingController();
  final _city = TextEditingController();
  final _state = TextEditingController();
  final _complement = TextEditingController();
  final _password = TextEditingController();
  final _password2 = TextEditingController();
  bool _accept = false;
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.prefillName ?? '');
    _email = TextEditingController(text: widget.prefillEmail ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _document,
      _email,
      _phone,
      _zip,
      _street,
      _number,
      _district,
      _city,
      _state,
      _complement,
      _password,
      _password2,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final doc = _document.text.replaceAll(RegExp(r'\D'), '');
    if (_name.text.trim().length < 3 ||
        doc.length != 11 ||
        _email.text.trim().isEmpty) {
      setState(() => _error = 'Informe nome, CPF e e-mail corretamente.');
      return;
    }
    if (_street.text.trim().isEmpty ||
        _number.text.trim().isEmpty ||
        _district.text.trim().isEmpty ||
        _city.text.trim().isEmpty ||
        _state.text.trim().length != 2 ||
        _zip.text.replaceAll(RegExp(r'\D'), '').length != 8) {
      setState(() => _error = 'Preencha o endereço principal completo.');
      return;
    }
    if (!widget.isGoogle) {
      if (_password.text.length < 6) {
        setState(() => _error = 'A senha precisa ter pelo menos 6 caracteres.');
        return;
      }
      if (_password.text != _password2.text) {
        setState(() => _error = 'As senhas não conferem.');
        return;
      }
    }
    if (!_accept) {
      setState(
        () => _error =
            'É necessário aceitar os termos e a política de privacidade.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final address = <String, String>{
        'zip': _zip.text.trim(),
        'street': _street.text.trim(),
        'number': _number.text.trim(),
        'district': _district.text.trim(),
        'city': _city.text.trim(),
        'state': _state.text.trim().toUpperCase(),
        'complement': _complement.text.trim(),
      };
      if (widget.isGoogle) {
        await widget.auth.googleLogin(
          idToken: widget.googleIdToken!,
          rememberMe: true,
          registration: <String, String>{
            'name': _name.text.trim(),
            'document': doc,
            'phone': _phone.text.trim(),
            ...address,
          },
        );
      } else {
        await widget.auth.register(
          name: _name.text.trim(),
          document: doc,
          email: _email.text.trim(),
          phone: _phone.text.trim(),
          password: _password.text,
          rememberMe: true,
          address: address,
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.isGoogle ? 'Completar cadastro Google' : 'Criar conta',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(18),
        children: [
          if (widget.isGoogle)
            const Padding(
              padding: EdgeInsets.only(bottom: 14),
              child: Text(
                'Sua conta Google foi validada. Complete os dados necessários para entrega e faturamento.',
              ),
            ),
          _field(_name, 'Nome completo', Icons.person_outline),
          _field(
            _document,
            'CPF',
            Icons.badge_outlined,
            keyboard: TextInputType.number,
          ),
          _field(
            _email,
            'E-mail',
            Icons.email_outlined,
            keyboard: TextInputType.emailAddress,
            enabled: !widget.isGoogle,
          ),
          _field(
            _phone,
            'Celular',
            Icons.phone_outlined,
            keyboard: TextInputType.phone,
          ),
          const SizedBox(height: 10),
          Text(
            'Endereço principal',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _field(
                  _zip,
                  'CEP',
                  Icons.location_on_outlined,
                  keyboard: TextInputType.number,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(child: _field(_state, 'UF', Icons.map_outlined)),
            ],
          ),
          _field(_street, 'Rua / Avenida', Icons.signpost_outlined),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _field(_number, 'Número', Icons.numbers),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 3,
                child: _field(
                  _district,
                  'Bairro',
                  Icons.location_city_outlined,
                ),
              ),
            ],
          ),
          _field(_city, 'Cidade', Icons.apartment_outlined),
          _field(_complement, 'Complemento (opcional)', Icons.notes_outlined),
          if (!widget.isGoogle) ...[
            const SizedBox(height: 10),
            TextField(
              controller: _password,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Senha',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _password2,
              obscureText: _obscure,
              decoration: const InputDecoration(
                labelText: 'Confirmar senha',
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _accept,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            title: const Text(
              'Li e aceito os Termos de Uso e a Política de Privacidade.',
            ),
            onChanged: _loading
                ? null
                : (v) => setState(() => _accept = v ?? false),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 14),
          FilledButton.icon(
            onPressed: _loading ? null : _submit,
            icon: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.person_add_alt_1),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 13),
              child: Text(
                widget.isGoogle ? 'CONCLUIR CADASTRO' : 'CRIAR MINHA CONTA',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label,
    IconData icon, {
    TextInputType? keyboard,
    bool enabled = true,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboard,
      decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
    ),
  );
}
