# App 1.6.32+190 / Mobile 1.14.3

Atualize primeiro a API da loja. Em Admin > Mobile > Android/iOS configure a versão e o build desejados (sugestão 1.6.32 / 190). O build lê a API, identidade, branding, versão e build do servidor antes de compilar.

Android no PowerShell: `.\COMPILAR_ANDROID.cmd https://domlevi.com.br/api/mobile/v1`

iOS no Terminal do Mac: `bash tooling/build_ipa.sh https://domlevi.com.br/api/mobile/v1` (certificados/perfil de produção necessários).

Em Conta > Configurações Locais e Segurança > Idioma escolha Português (Brasil), English ou Español. A escolha fica salva no aparelho e aplica-se à interface do app, formulários, menus, calendário e mensagens do plugin biométrico. Diálogos e teclado exclusivos do Android/iOS seguem o idioma do sistema. Nomes de produtos, setores, opções, descrições, campanhas e documentos legais continuam conforme a loja; não há tradução automática do catálogo nesta versão. Moeda continua BRL e quantidades seguem as regras brasileiras da loja.

Notificações: desativadas por padrão para novo cadastro de preferência. Ao ativar, solicita permissão nativa Android 13+/iOS; respeita bloqueio da loja, negativa do sistema e mudança feita em Ajustes. Retornar ao app atualiza o status na API. A escolha fica por cliente/plataforma/aparelho, com idioma e permissão; desligar desativa os tokens já registrados desse aparelho. API só aceita registrar token FCM/APNs com preferência ativa, permissão e habilitação do módulo/plataforma. É preparação de consentimento e permissão: envio automático de movimentações NÃO está implementado. Requer configurar um projeto/provedor FCM/APNs, integrar geração/renovação dos tokens e implementar o envio de eventos de pedidos com consulta do consentimento atual. Não contém credenciais Firebase/Apple nem faz polling em segundo plano.

Fale com a Loja: telefone e WhatsApp com número visível, atalhos Facebook, Instagram, X/Twitter, YouTube, TikTok e LinkedIn somente se cadastrados na empresa oficial em web_empresas (empresa_codigo_site). Não usa contatos da AM Soft nessa tela. AM Soft em Sobre o App: (41) 3263-4580, vendas@softmanutencoes.com.br e https://www.softmanutencoes.com.br; configuráveis na aba Sobre do módulo.

Assinatura de produção preservada: nunca envie/android/key.properties, keystore ou senhas ao servidor. Pacotes são projetos fonte, sem APK/IPA pré-compilados. Patches partem da 1.6.31+189; para outra base use completo preservando seus arquivos locais de assinatura. Fluxos de pedidos, endereço histórico, LGPD, SAC e pesáveis da versão anterior preservados.
