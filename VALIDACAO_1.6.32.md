# Validação 1.6.32 / Mobile 1.14.3

API/PHP 7.4/MariaDB reais: email/site AM Soft corrigidos, migração idempotente e preservação de personalizados; upgrade aditivo de preferências antigas preserva dados. Contato usa empresa oficial empresa_codigo_site: telefone, WhatsApp visível, links Facebook/Instagram/YouTube; rejeita protocolos perigosos e URLs com credenciais.

Notificações: HTTP com tokens/sessões reais verifica padrão desativado, gates global/plataforma, idioma e status, opt-in, negativa, registro FCM/APNs, revogação de permissão, opt-out e isolamento por cliente/aparelho (incluindo tentativa de alterar device_id). Negativa de permissão desativa tokens, mantendo intenção do cliente. Foram simulados estados informados pelo app; não houve teste de permissão nativa em aparelho.

Idiomas: script Dart executa as 528 mensagens PT/EN/ES com placeholders e verifica IDs, URLs, nomes opacos, erros e formulários. tooling/check_localization.dart reproduz a verificação. Idioma salvo no aparelho, aplicado à interface, calendário e plugin biométrico. Catálogo e documentos da loja permanecem no idioma original; diálogos exclusivos do sistema usam idioma do aparelho.

Regressão HTTP: endereços e entrega histórica, SAC, LGPD, termos/aceites, pesáveis, dez abas Admin nas duas rotas e salvamento Sobre passaram. Instalador: autenticação Admin/CSRF, hashes, aplicação/rollback, geração 123, 38 triggers, mutex, idempotência e infraestrutura passaram.

PHP 7.4: 312 arquivos sem erros de sintaxe. Dart analyze lib/test: zero erros, 40 avisos/informações, incluindo APIs deprecated e avisos preexistentes. Quantidade/máscara SHIFT executados em Dart. Inspeção estática: manifesto, canais nativos, preservação de MainActivity no branding, plist iOS, YAML Codemagic e sintaxe bash. lib/test idênticos nos apps. Patches sobre 1.6.31+189 reproduzem os completos byte a byte e preservam assinatura privada. ZIPs íntegros; demais módulos Soft Licenças idênticos à 2.14.2.

Limites: fontes para compilação, sem APK/IPA pré-compilados. Sem build Flutter/Gradle/Xcode completo, testes de widgets, PowerShell/Windows ou execução em aparelho. Homologação deve conferir permissão real, negativa/retorno de Ajustes e seleção de idioma nos dois sistemas. Avisos automáticos de movimentações de pedidos ainda requerem provedor FCM/APNs, gestão de tokens no app e envio de eventos consultando consentimento/permissão atuais.
