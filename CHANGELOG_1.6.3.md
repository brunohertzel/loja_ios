# Soft Ecommerce Mobile Android 1.6.3

- Restaura o fluxo comercial de branding por cliente via `sync_android_branding.cmd URL_DA_API_MOBILE`.
- O bootstrap do cliente volta a ser a fonte de nome do app, package ID, logo/icone, cores, tema, Google Client ID e Google Pay durante a preparacao do release.
- A sincronizacao grava um cache local apenas para o build; o pacote completo nao leva identidade fixa de cliente.
- Build bloqueado quando o branding ainda nao foi sincronizado, evitando gerar APK de um cliente com dados de outro.
- Leitura do release no bootstrap: versao atual, build, versao minima, force update, store URL e versao do modulo.
- Quando versao/build validos estiverem configurados no modulo, a sincronizacao aplica `versionName/versionCode` no `pubspec.yaml`.
- `SOFT_API_BASE_URL` via `--dart-define` continua suportado e tem precedencia sobre o valor sincronizado.
- Mantem as correcoes 1.6.2 de campanhas patrocinadas, ofertas, tema claro/escuro e branding de launcher.
