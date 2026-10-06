# 1.6.1

- Corrige Flutter atual: `ThemeData.cardTheme` usa `CardThemeData`.
- Configuração estrutural passa a ser LOCAL no app, sem `--dart-define` e sem depender do bootstrap para identidade.
- Adiciona `tooling/mobile_app_config.json` + `lib/core/config/generated_app_config.dart`.
- API base, nome, package, tema inicial, cores, Google Client ID público e identidade Google Pay ficam no build local.
- Tema escolhido pelo usuário continua persistido localmente e prevalece sobre o tema inicial.
- Bootstrap continua somente para licença, disponibilidade e regras comerciais/operacionais.
- `run_android`, `build_apk` e `build_aab` passam a aplicar a configuração local automaticamente.
- `google_sign_in` atualizado dentro da linha 6.x e `package_info_plus` para 9.x, evitando migração major desnecessária nesta correção.
