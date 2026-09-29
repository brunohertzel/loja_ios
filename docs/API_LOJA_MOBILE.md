# API Loja Mobile 1.4.0

Catálogo:
- GET `/store/home.php`
- GET `/store/categories.php`
- GET `/store/products.php`
- GET `/store/product.php?id=ID`

Checkout autenticado:
- POST `/checkout/prepare.php`
- POST `/checkout/freight.php`

O app envia somente as linhas selecionadas do carrinho. Cada linha contém `product_id`, `quantity_visual`, `selected_variation_ids`, `number_values` e `observation`. O backend reconstrói a quantidade real, valida opcionais e recalcula campanha/preço.
