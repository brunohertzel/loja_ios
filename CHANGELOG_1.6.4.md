# Soft Ecommerce Mobile Android 1.6.4

- Corrige o build no Windows quando `mobile_app_config.json` contém BOM UTF-8.
- O sincronizador grava o JSON de branding/release sem BOM.
- O Gradle também remove BOM de caches antigos antes de chamar `JsonSlurper`.
- O fluxo continua comercial e por cliente: execute `sync_android_branding.cmd URL_DA_API_MOBILE` antes de cada release.
- O Soft Licenças/Mobile não muda nesta correção.
