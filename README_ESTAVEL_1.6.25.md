# Android 1.6.25+183 - base estavel

Base real: Android 1.6.18+176 REV2.

Alteracoes isoladas:
1. pedidos/detalhe resiliente;
2. leitura de codigo de barras pela camera na busca.

Nao foram reaplicadas as alteracoes de paginacao/snapshot/catalogo das versoes 1.6.19 a 1.6.24.

Depois de aplicar o patch:

    flutter clean
    flutter pub get
    flutter build apk --release --dart-define=SOFT_API_BASE_URL=https://domlevi.com.br/api/mobile/v1
