# Mobile Android 1.6.2

- Corrige branding local: `flutter build apk --release` agora aplica automaticamente `tooling/mobile_app_config.json`.
- Nome/package lidos pelo Gradle antes do build; `generated_app_config.dart` e MainActivity são sincronizados automaticamente.
- Ícone Android/adaptive icon é regenerado a partir de `icon_android_url`, com fallback para o logo da loja.
- Adiciona fallback local de ícone para evitar launcher sem identidade.
- Home passa a exibir campanhas patrocinadas agrupadas, com banner compacto e carrossel horizontal de produtos.
- Mantém ofertas, tema claro/escuro, ordenação e preço fracionado da 1.6.1.
