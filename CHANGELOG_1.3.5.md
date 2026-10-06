# V1.3.5 - Splash/branding Android

- Corrige o splash nativo Android 12+ que exibia o icone Android padrao.
- O splash Flutter passa a usar `splash_url`; fallback para `logo_url` e `icon_android_url`.
- Adiciona sincronizacao de branding do modulo Mobile para o build Android.
- `sync_android_branding.ps1` baixa o Icone Android/Logo do bootstrap e gera recursos do splash e launcher.
- `run_android.ps1`, `build_aab.ps1` e F5 do VS Code sincronizam o branding antes do build.
- Se o branding ainda nao tiver sido sincronizado, o splash nativo fica neutro em vez de exibir o robo Android.
