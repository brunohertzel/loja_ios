# Soft Ecommerce Mobile Android 1.6.18

## Busca e Loja
- Ao adicionar ao carrinho um item aberto a partir da busca, fecha a busca, limpa o termo e volta para a Loja.
- Novo seletor de visualização dos produtos: Grande (layout anterior), Médio e Pequeno.
- Os modos compactos reduzem proporcionalmente imagem, texto, preço, badges, espaçamentos e ações sem remover dados.
- A preferência de tamanho fica salva no aparelho.

## Produto
- Galeria consolidada em carrossel com todas as imagens.
- `video_url` entra como último item do carrossel, com ação para reprodução pelo link cadastrado.
- Indicador visual de páginas no carrossel.
- Ao tocar em “Você também pode gostar”, se o produto atual ainda não estiver no carrinho, pergunta se deve adicioná-lo antes de abrir a sugestão.

## Pedidos
- Ação “Repetir pedido” no detalhe e na barra superior.
- O app consulta novamente os produtos, preços e disponibilidade atuais antes de reconstruir o carrinho.
- Itens indisponíveis ou com configuração obrigatória que não possa ser recuperada são informados ao cliente.
- Área de rastreio mostra o status atual, código, eventos/timeline quando enviados pela API e botão para link externo.
- Exibe como o pedido foi pago; suporta um ou múltiplos meios, status, provedor, bandeira, parcelas e valores quando presentes no retorno.

## Compatibilidade
- Base: Android 1.6.17.
- Build: 176.
- Nenhuma dependência Flutter nova.
- Gerador de pacotes e fluxo de branding permanecem inalterados.

## Revisao de build
- Remove a exibicao de `True`/`False` dos scripts de configuracao/branding.
- Mantem Java/Kotlin do app em 17 e silencia somente o warning `source/target value 8 is obsolete` emitido por dependencias Android legadas.
- Nao altera dependencias nem comportamento funcional do aplicativo.

## Revisao 2 - correcao de compilacao
- Corrige promocao de nulabilidade ao restaurar a preferencia de tamanho dos cards.
- Remove uso indevido de `scale` em um `const TextStyle` da tela Minha conta.
- Mantem a versao do app em 1.6.18+176; nenhuma dependencia foi alterada.
