# Soft Ecommerce Mobile Android 1.6.25

Build: 183

## Base

Esta versao foi reconstruida diretamente sobre a base estavel 1.6.18+176 REV2, confirmada em teste sem travar o site.
Nao incorpora a paginacao, snapshots, preload de catalogo ou alteracoes de startup das versoes 1.6.19 a 1.6.24.

## Pedidos

- Reaplica somente as correcoes resilientes do detalhe de pedidos.
- Aceita variacoes de campos `id/order_id/pedido_id`, `order/pedido/data`, `items/itens`, `payment/pagamento`, entrega e rastreio.
- Mantem os dados do card quando o endpoint de detalhe retorna payload parcial.
- Corrige a tela branca do detalhe causada por constraint vertical no primeiro card.
- Preserva filtros Todos/Pendentes/Em andamento/Finalizados/Cancelados, repetir pedido, pagamento e rastreio.

## Busca por codigo de barras

- Adiciona botao de camera na busca.
- Usa `mobile_scanner ^6.0.11`.
- Consulta endpoint dedicado `/store/barcode.php` por igualdade exata do codigo, retornando somente um produto.
- Nao percorre o catalogo nem aciona paginacao.

## Protecao da base estavel

- Nenhuma alteracao em Home, carregamento inicial, produtos gerais, carrinho ou checkout.
- `StoreRepository.products()` permanece exatamente com a logica da 1.6.18 REV2.
