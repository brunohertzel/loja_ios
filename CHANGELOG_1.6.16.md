# Soft Ecommerce Mobile Android 1.6.16

Correção pontual da 1.6.15.

- Ficha técnica HTML: tratamento seguro de `element.localName == null`.
- `apply_build_config.ps1`: somente grava arquivos se o conteúdo realmente mudou.
- `MainActivity.kt`: não é mais removido/recriado em todo build quando o package é o mesmo.
- `sync_android_branding.ps1`: cache JSON também evita escrita desnecessária.
- Soft Licenças permanece 2.9.5.
- Mobile permanece 1.9.9.
