# Soft Ecommerce Mobile Android 1.6.26

Build: 184

## Base

- Base direta: Android 1.6.25+183 estavel.
- Preserva correcoes de Pedidos e leitor de codigo de barras.
- Nao reaproveita a paginacao/snapshot/startup das versoes 1.6.19 a 1.6.24.

## Catalogo Read Model

- Requer servidor com Catalog Read Model v1.0.4 ativo e contexto READY.
- Loja inicia exibindo somente 20 produtos.
- Usa o lote ja retornado por `home.php` para os primeiros 20, evitando uma requisicao extra na abertura.
- `Carregar mais 20 produtos` consulta `/store/products.php?page=N&limit=20`.
- A-Z, Z-A, preco e departamento reiniciam na pagina 1 e mantem a mesma ordenacao nas paginas seguintes.
- Resultados adicionados sao deduplicados por ID.
- Nao existe preload automatico, loop de pagina, snapshot local ou reconstrucao de catalogo pelo app.
- Categorias/listas de departamento tambem usam 20 + 20.

## Estrategia deste build

O carregamento adicional e manual de proposito. Este build serve para validar em producao a estabilidade do Read Model sem permitir uma rajada automatica de requisicoes ao servidor. Depois da validacao, o mesmo contrato pode ser usado por scroll incremental/lazy loading.
