import '../../core/localization/localized_widgets.dart';
import '../../core/localization/locale_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_widget_from_html_core/flutter_widget_from_html_core.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/network/api_client.dart';
import 'store_models.dart';
import 'store_repository.dart';

Future<void> openCareLink(BuildContext context, String raw) async {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || !{'https', 'http', 'tel', 'mailto'}.contains(uri.scheme))
    return;
  try {
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LText('Não foi possível abrir o contato.')),
      );
    }
  } catch (_) {
    if (context.mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LText('Não foi possível abrir o contato.')),
      );
  }
}

class StoreContactPage extends StatefulWidget {
  const StoreContactPage({super.key, required this.repository});
  final StoreRepository repository;
  @override
  State<StoreContactPage> createState() => _StoreContactPageState();
}

class _StoreContactPageState extends State<StoreContactPage> {
  late Future<Map<String, dynamic>> _future;
  @override
  void initState() {
    super.initState();
    _future = widget.repository.careGet('/account/contact.php');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const LText('Fale com a loja')),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return CareError(
                error: snapshot.error,
                retry: () => setState(
                  () => _future =
                      widget.repository.careGet('/account/contact.php'),
                ),
              );
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                StoreContactCard(
                  contact: mapValue(snapshot.data!['store_contact']),
                ),
              ],
            );
          },
        ),
      );
}

class StoreContactCard extends StatelessWidget {
  const StoreContactCard({
    super.key,
    required this.contact,
    this.orderId,
    this.requestId,
  });
  final Map<String, dynamic> contact;
  final int? orderId;
  final int? requestId;

  @override
  Widget build(BuildContext context) {
    final address = mapValue(contact['address']);
    final addressText = [
      [
        address['street'],
        address['number'],
      ].where((v) => '$v' != 'null' && '$v'.isNotEmpty).join(', '),
      address['complement'],
      address['district'],
      [
        address['city'],
        address['state'],
      ].where((v) => v != null && '$v'.isNotEmpty).join('/'),
      address['zip'],
    ].where((v) => v != null && '$v'.trim().isNotEmpty).join(' - ');
    final whatsapp = '${contact['whatsapp_url'] ?? ''}';
    final whatsappNumber =
        '${contact['whatsapp_display'] ?? contact['whatsapp'] ?? ''}';
    final socials = listValue(contact['social_links']);
    final phone = '${contact['phone'] ?? ''}';
    final email = '${contact['email'] ?? ''}';
    var message = 'Olá! Gostaria de atendimento.';
    if (orderId != null)
      message =
          'Olá! Preciso de atendimento sobre o pedido #$orderId${requestId == null ? '.' : tr(', solicitação #$requestId.')}';
    message = tr(message);
    final whatsappUrl = whatsapp.isEmpty
        ? ''
        : Uri.parse(
            whatsapp,
          ).replace(queryParameters: {'text': message}).toString();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LText(
              '${contact['name'] ?? tr('Atendimento da loja')}',
              translate: false,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if ('${contact['legal_name'] ?? ''}'.isNotEmpty)
              LText('${contact['legal_name']}'),
            if ('${contact['document'] ?? ''}'.isNotEmpty)
              LText('CNPJ: ${contact['document']}'),
            if (addressText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SelectableText(addressText),
              ),
            if ('${contact['hours'] ?? ''}'.isNotEmpty)
              LText('Atendimento: ${contact['hours']}'),
            if (whatsappUrl.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.chat_outlined),
                title: const LText('Falar com a loja no WhatsApp'),
                subtitle: whatsappNumber.isEmpty
                    ? null
                    : LText(whatsappNumber, translate: false),
                onTap: () => openCareLink(context, whatsappUrl),
              ),
            if (phone.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: LText(phone),
                onTap: () => openCareLink(
                  context,
                  'tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}',
                ),
              ),
            if (email.isNotEmpty)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.email_outlined),
                title: LText(email),
                onTap: () => openCareLink(
                  context,
                  Uri(scheme: 'mailto', path: email).toString(),
                ),
              ),
            if (socials.isNotEmpty) ...[
              const SizedBox(height: 12),
              LText('Redes sociais',
                  style: Theme.of(context).textTheme.titleMedium),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final social in socials)
                  OutlinedButton.icon(
                    onPressed: () =>
                        openCareLink(context, '${social['url'] ?? ''}'),
                    icon: Icon(social['id'] == 'facebook'
                        ? Icons.facebook
                        : social['id'] == 'instagram'
                            ? Icons.camera_alt_outlined
                            : social['id'] == 'youtube'
                                ? Icons.play_circle_outline
                                : Icons.public),
                    label: LText('${social['name'] ?? ''}', translate: false),
                  ),
              ]),
            ],
            if ('${contact['contact_url'] ?? ''}'.isNotEmpty)
              TextButton(
                onPressed: () =>
                    openCareLink(context, '${contact['contact_url']}'),
                child: const LText('Página de contato da loja'),
              ),
            if (whatsapp.isEmpty && phone.isEmpty && email.isEmpty)
              const LText(
                'A loja ainda não cadastrou os contatos de atendimento.',
              ),
          ],
        ),
      ),
    );
  }
}

class LegalDocumentsPage extends StatefulWidget {
  const LegalDocumentsPage({
    super.key,
    required this.repository,
    this.requireAcceptance = false,
    this.registration = false,
    this.onAccepted,
    this.readOnly = false,
    this.documentType,
  });
  final StoreRepository repository;
  final bool requireAcceptance;
  final bool registration;
  final VoidCallback? onAccepted;
  final bool readOnly;
  final String? documentType;
  @override
  State<LegalDocumentsPage> createState() => _LegalDocumentsPageState();
}

class _LegalDocumentsPageState extends State<LegalDocumentsPage> {
  bool _loading = true, _saving = false, _checked = false;
  String? _error;
  List<Map<String, dynamic>> _docs = [];
  bool _needsAcceptance = false;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
      _checked = false;
    });
    try {
      final data = widget.registration
          ? await widget.repository.api.get(
              '/account/legal.php',
              authenticated: false,
            )
          : await widget.repository.careGet('/account/legal.php');
      if (mounted)
        setState(() {
          _docs = listValue(data['documents']);
          if (widget.readOnly && widget.documentType != null) {
            _docs =
                _docs.where((d) => d['type'] == widget.documentType).toList();
          }
          _needsAcceptance = data['needs_acceptance'] == true;
        });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _accept() async {
    if (!_checked || _saving) return;
    final submitted = _docs
        .map(
          (d) => <String, dynamic>{
            'type': d['type'],
            'version': d['version'],
            'hash': d['hash'],
          },
        )
        .toList();
    if (widget.registration) {
      Navigator.of(context).pop(submitted);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.repository.carePost('/account/legal.php', {
        'action': 'accept',
        'accept_terms': true,
        'documents': submitted,
      });
      if (result['needs_acceptance'] == true)
        throw const ApiException(
          'Leia os documentos atualizados e confirme o aceite.',
        );
      if (!mounted) return;
      if (widget.onAccepted != null) {
        widget.onAccepted!();
      } else {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted)
        setState(() {
          _error = e.toString();
          _checked = false;
        });
      if (e is ApiException && e.code == 'LEGAL_DOCUMENTS_CHANGED')
        await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accept = !widget.readOnly &&
        (widget.requireAcceptance || widget.registration || _needsAcceptance);
    return Scaffold(
      appBar: AppBar(
          title: LText(widget.documentType == 'POLITICA_PRIVACIDADE'
              ? 'Política de Privacidade'
              : 'Termos e privacidade')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null && _docs.isEmpty
              ? CareError(error: _error, retry: _load)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: LText(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    if (_docs.isEmpty)
                      const LText(
                        'A loja ainda não publicou os documentos legais no cadastro. Consulte o atendimento da loja.',
                      ),
                    if (widget.readOnly &&
                        widget.documentType == 'POLITICA_PRIVACIDADE')
                      TextButton(
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) => LegalDocumentsPage(
                                      repository: widget.repository,
                                      readOnly: true,
                                      documentType: 'TERMOS_USO'))),
                          child: const LText('Consultar Termos de Uso')),
                    ..._docs.map(
                      (doc) => Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              LText(
                                '${doc['title'] ?? ''}',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              LText('Versão ${doc['version'] ?? ''}'),
                              const SizedBox(height: 12),
                              HtmlWidget(
                                '${doc['html'] ?? ''}',
                                onTapUrl: (url) async {
                                  await openCareLink(context, url);
                                  return true;
                                },
                              ),
                              if ('${doc['url'] ?? ''}'.isNotEmpty)
                                TextButton(
                                  onPressed: () =>
                                      openCareLink(context, '${doc['url']}'),
                                  child: const LText('Abrir documento no site'),
                                ),
                              if (doc['accepted'] == true)
                                const LText(
                                  'Esta versão já foi aceita.',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (accept && _docs.isNotEmpty)
                      CheckboxListTile(
                        value: _checked,
                        onChanged: _saving
                            ? null
                            : (v) => setState(() => _checked = v == true),
                        title: const LText(
                          'Li e aceito os termos de uso e estou ciente da política de privacidade.',
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                    if (accept && _docs.isNotEmpty)
                      FilledButton(
                        onPressed: _checked && !_saving ? _accept : null,
                        child: _saving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const LText('Confirmar e continuar'),
                      ),
                    if (widget.requireAcceptance &&
                        _docs.isEmpty &&
                        widget.onAccepted != null)
                      FilledButton(
                        onPressed: widget.onAccepted,
                        child: const LText('Continuar'),
                      ),
                    if (widget.registration && _docs.isEmpty)
                      FilledButton(
                        onPressed: () =>
                            Navigator.of(context).pop(<Map<String, dynamic>>[]),
                        child: const LText('Continuar cadastro'),
                      ),
                  ],
                ),
    );
  }
}

class PrivacyPage extends StatefulWidget {
  const PrivacyPage({super.key, required this.repository});
  final StoreRepository repository;
  @override
  State<PrivacyPage> createState() => _PrivacyPageState();
}

class _PrivacyPageState extends State<PrivacyPage> {
  static const _types = {
    'ACESSO': 'Acesso aos meus dados',
    'CORRECAO': 'Correção de dados',
    'EXCLUSAO': 'Exclusão da conta e dos dados',
    'REVOGACAO': 'Revogação de consentimento',
    'OUTRO': 'Outra solicitação',
  };
  final _message = TextEditingController();
  String _type = 'ACESSO';
  bool _loading = true, _saving = false;
  String? _error;
  Map<String, dynamic> _contact = {};
  List<Map<String, dynamic>> _requests = [];
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.repository.careGet('/account/privacy.php');
      if (mounted)
        setState(() {
          _requests = listValue(data['requests']);
          _contact = mapValue(data['store_contact']);
          _error = null;
        });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_message.text.trim().length < 5) {
      setState(() => _error = 'Descreva sua solicitação.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await widget.repository.carePost('/account/privacy.php', {
        'type': _type,
        'message': _message.text.trim(),
      });
      _message.clear();
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: LText('${result['message'] ?? 'Solicitação registrada.'}'),
          ),
        );
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const LText('Privacidade e meus dados')),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const LText(
                    'Consulte a política de privacidade ou envie à loja uma solicitação sobre seus dados pessoais.',
                  ),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            LegalDocumentsPage(repository: widget.repository),
                      ),
                    ),
                    icon: const Icon(Icons.policy_outlined),
                    label: const LText(
                        'Consultar termos e política de privacidade'),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: LText(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  DropdownButtonFormField<String>(
                    initialValue: _type,
                    decoration: const LDecoration(
                      labelText: 'Tipo de solicitação',
                    ),
                    items: _types.entries
                        .map(
                          (e) => DropdownMenuItem(
                              value: e.key, child: LText(e.value)),
                        )
                        .toList(),
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _type = v ?? 'ACESSO'),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _message,
                    maxLines: 4,
                    maxLength: 4000,
                    decoration: const LDecoration(labelText: 'Sua solicitação'),
                  ),
                  if (_type == 'EXCLUSAO')
                    const LText(
                      'A loja analisará a exclusão da conta e dos dados. Registros que precisem ser mantidos serão informados na resposta.',
                    ),
                  if (_type == 'REVOGACAO')
                    const LText('Informe qual autorização deseja revogar.'),
                  FilledButton(
                    onPressed: _saving ? null : _send,
                    child: LText(
                      _saving ? 'Enviando...' : 'Enviar solicitação à loja',
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_requests.isNotEmpty)
                    LText(
                      'Minhas solicitações',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ..._requests.map(
                    (r) => Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LText(
                                '#${r['id']} — ${_types[r['tipo']] ?? r['tipo']}'),
                            LText('Status: ${r['status']}'),
                            LText('${r['mensagem'] ?? ''}'),
                            if ('${r['resposta_loja'] ?? ''}'.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 10),
                                child: LText(
                                  'Resposta da loja: ${r['resposta_loja']}',
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_contact.isNotEmpty) StoreContactCard(contact: _contact),
                ],
              ),
      );
}

class OrderIssuePage extends StatefulWidget {
  const OrderIssuePage({
    super.key,
    required this.repository,
    required this.orderId,
  });
  final StoreRepository repository;
  final int orderId;
  @override
  State<OrderIssuePage> createState() => _OrderIssuePageState();
}

class _OrderIssuePageState extends State<OrderIssuePage> {
  static const _reasons = [
    'Desisti da compra',
    'Pedido incorreto',
    'Produto faltando',
    'Produto com problema',
    'Atraso na entrega',
    'Não reconheço o pedido',
    'Outro motivo',
  ];
  final _description = TextEditingController();
  String _type = 'RECLAMACAO';
  String? _reason, _error;
  bool _loading = true, _saving = false;
  Map<String, dynamic> _data = {};
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await widget.repository.careGet(
        '/orders/issue.php?id=${widget.orderId}',
      );
      if (mounted)
        setState(() {
          _data = data;
          _error = null;
        });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    if (_reason == null || _description.text.trim().length < 5) {
      setState(() => _error = 'Selecione o motivo e descreva o problema.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final data = await widget.repository.carePost('/orders/issue.php', {
        'order_id': widget.orderId,
        'type': _type,
        'reason': _reason,
        'description': _description.text.trim(),
      });
      if (!mounted) return;
      setState(() => _data = data);
      final contact = mapValue(data['store_contact']);
      final raw = '${contact['whatsapp_url'] ?? ''}';
      final requestId = data['request_id'];
      final talk = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: LText('Solicitação #$requestId registrada'),
          content: LText(
            raw.isEmpty
                ? 'Você pode acompanhar a resposta da loja nesta tela.'
                : 'Deseja também falar com a loja pelo WhatsApp?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const LText('Acompanhar no app'),
            ),
            if (raw.isNotEmpty)
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const LText('Falar no WhatsApp'),
              ),
          ],
        ),
      );
      if (talk == true && mounted) {
        await openCareLink(
          context,
          Uri.parse(raw).replace(
            queryParameters: {
              'text':
                  'Olá! Abri a solicitação #$requestId sobre o pedido #${widget.orderId} e gostaria de atendimento.',
            },
          ).toString(),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading)
      return Scaffold(
        appBar: AppBar(title: const LText('Atendimento do pedido')),
        body: const Center(child: CircularProgressIndicator()),
      );
    if (_data.isEmpty && _error != null)
      return Scaffold(
        appBar: AppBar(title: const LText('Atendimento do pedido')),
        body: CareError(error: _error, retry: _load),
      );
    final contact = mapValue(_data['store_contact']);
    final requests = listValue(_data['requests']);
    final types = listValue(_data['types']);
    return Scaffold(
      appBar: AppBar(title: LText('Atendimento do pedido #${widget.orderId}')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_error != null)
              LText(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (_data['available'] != true) ...[
              const LText(
                'O formulário de atendimento ainda não está disponível no app desta loja.',
              ),
              if ('${_data['web_url'] ?? ''}'.isNotEmpty)
                TextButton(
                  onPressed: () => openCareLink(context, '${_data['web_url']}'),
                  child: const LText('Abrir atendimento no site'),
                ),
            ],
            if (_data['can_create'] == true) ...[
              const LText(
                'Informe o problema à loja. Sua solicitação ficará vinculada ao pedido e ao atendimento do site.',
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: const LDecoration(labelText: 'Tipo'),
                items: types
                    .map(
                      (t) => DropdownMenuItem(
                        value: '${t['id']}',
                        child: LText('${t['label']}'),
                      ),
                    )
                    .toList(),
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _type = v ?? 'RECLAMACAO'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _reason,
                decoration: const LDecoration(labelText: 'Motivo'),
                items: _reasons
                    .map((r) => DropdownMenuItem(value: r, child: LText(r)))
                    .toList(),
                onChanged: _saving ? null : (v) => setState(() => _reason = v),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _description,
                maxLines: 5,
                maxLength: 4000,
                decoration: const LDecoration(
                  labelText: 'Conte para a loja o que aconteceu',
                ),
              ),
              FilledButton.icon(
                onPressed: _saving ? null : _send,
                icon: const Icon(Icons.send_outlined),
                label: LText(_saving ? 'Enviando...' : 'Enviar solicitação'),
              ),
            ],
            ...requests.map(
              (r) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LText(
                        'Solicitação #${r['id']} — ${r['tipo']}',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      LText('Status: ${r['status']}'),
                      LText('Motivo: ${r['motivo']}'),
                      const SizedBox(height: 8),
                      LText('${r['descricao'] ?? ''}'),
                      if ('${r['resposta_loja'] ?? ''}'.isNotEmpty) ...[
                        const Divider(),
                        const LText(
                          'Resposta da loja',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        LText('${r['resposta_loja']}'),
                      ],
                      const Divider(),
                      const LText(
                        'Histórico',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      ...listValue(r['history']).map(
                        (h) => Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: LText(
                            '${h['data_criacao']} — ${h['status_novo']}\n${h['mensagem'] ?? ''}',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (contact.isNotEmpty)
              StoreContactCard(contact: contact, orderId: widget.orderId),
          ],
        ),
      ),
    );
  }
}

class CareError extends StatelessWidget {
  const CareError({super.key, required this.error, required this.retry});
  final Object? error;
  final VoidCallback retry;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LText('$error', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                  onPressed: retry, child: const LText('Tentar novamente')),
            ],
          ),
        ),
      );
}
