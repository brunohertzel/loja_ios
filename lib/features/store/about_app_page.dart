import '../../core/localization/localized_widgets.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'customer_care_pages.dart';
import 'store_models.dart';
import 'store_repository.dart';

class AboutAppPage extends StatefulWidget {
  const AboutAppPage({super.key, required this.repository});
  final StoreRepository repository;

  @override
  State<AboutAppPage> createState() => _AboutAppPageState();
}

class _AboutAppPageState extends State<AboutAppPage> {
  late Future<Map<String, dynamic>> _future;
  final _package = PackageInfo.fromPlatform();

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<Map<String, dynamic>> _load() => widget.repository.api.get(
        '/account/about.php',
        authenticated: false,
      );

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const LText('Sobre o App')),
        body: FutureBuilder<Map<String, dynamic>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.hasError)
              return CareError(
                error: snapshot.error,
                retry: () => setState(() => _future = _load()),
              );
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            final developer = mapValue(snapshot.data!['developer']);
            final app = mapValue(snapshot.data!['app']);
            final name = '${developer['name'] ?? ''}';
            final logo = '${developer['logo_url'] ?? ''}';
            final phone = '${developer['phone'] ?? ''}';
            final whatsapp = '${developer['whatsapp_url'] ?? ''}';
            final email = '${developer['email'] ?? ''}';
            final website = '${developer['website'] ?? ''}';
            Widget fallbackLogo() => Image.asset('assets/am_soft_logo.png',
                height: 135, fit: BoxFit.contain);
            return ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Card(
                    child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(children: [
                    LText('${app['name'] ?? ''}',
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center),
                    const SizedBox(height: 10),
                    FutureBuilder<PackageInfo>(
                        future: _package,
                        builder: (context, info) => info.hasData
                            ? LText(
                                'Versão ${info.data!.version} (${info.data!.buildNumber})')
                            : const SizedBox.shrink()),
                  ]),
                )),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16)),
                  child: logo.isEmpty
                      ? fallbackLogo()
                      : Image.network(logo,
                          height: 135,
                          fit: BoxFit.contain,
                          semanticLabel: name,
                          errorBuilder: (_, __, ___) => fallbackLogo()),
                ),
                const SizedBox(height: 20),
                LText('Desenvolvido por $name',
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 12),
                LText('${developer['description'] ?? ''}'),
                const SizedBox(height: 20),
                Card(
                    child: Column(children: [
                  if (phone.isNotEmpty)
                    ListTile(
                        leading: const Icon(Icons.phone_outlined),
                        title: const LText('Telefone'),
                        subtitle: LText(phone),
                        onTap: () => openCareLink(context,
                            'tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}')),
                  if (whatsapp.isNotEmpty)
                    ListTile(
                        leading: const Icon(Icons.chat_outlined),
                        title: const LText('WhatsApp'),
                        subtitle: LText(phone),
                        onTap: () => openCareLink(context, whatsapp)),
                  if (email.isNotEmpty)
                    ListTile(
                        leading: const Icon(Icons.email_outlined),
                        title: const LText('E-mail'),
                        subtitle: LText(email),
                        onTap: () => openCareLink(context, 'mailto:$email')),
                  if (website.isNotEmpty)
                    ListTile(
                        leading: const Icon(Icons.language),
                        title: const LText('Site'),
                        subtitle: LText(website),
                        onTap: () => openCareLink(context, website)),
                ])),
                const SizedBox(height: 12),
                TextButton(
                    onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => LegalDocumentsPage(
                                repository: widget.repository))),
                    child:
                        const LText('Termos de Uso e Política de Privacidade')),
              ],
            );
          },
        ),
      );
}
