# Android 1.6.26+184 - teste controlado do Read Model

Pre-requisito no servidor:

- Read Model 1.0.4
- `status = READY`
- `full_rebuild_required = 0`
- endpoint `/api/mobile/v1/store/products.php` usando o Read Model

Teste recomendado:

1. Abra Loja e confirme os primeiros 20 produtos.
2. Troque repetidamente A-Z / Z-A / preco / departamento.
3. Pressione `Carregar mais 20 produtos` varias vezes.
4. Mantenha a loja Web aberta em paralelo.
5. Acompanhe `/api/mobile/v1/catalog_read_status.php?probe=1`.

Build local:

    flutter clean
    flutter pub get
    flutter build apk --release --dart-define=SOFT_API_BASE_URL=https://domlevi.com.br/api/mobile/v1

Este pacote nao inclui APK compilado.
