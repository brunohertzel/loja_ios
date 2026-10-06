# Versão atual: 1.6.28 (186) — produção

Leia `README_IOS_PRODUCAO.md` para a geração de release. As instruções históricas abaixo se referem às versões anteriores.


## 1.3.1
- Checkout renova access token automaticamente ao expirar, usando o refresh token.
- App sempre inicia na Home da loja.
- Opções de corte/tempero/embalagem e quantidade foram movidas para antes da ficha técnica.
- Identidade visual continua vindo do bootstrap do módulo Mobile.
# Soft Ecommerce Mobile — Loja Android 1.6.18

Aplicativo Android da **loja para o cliente final**. O painel administrativo continua no ecommerce web.

## Fluxo comercial de release — 1.6.18

A identidade do cliente **nao fica fixa no source**. Antes de cada compilacao comercial, sincronize o cliente pela URL da API Mobile:

```powershell
.\tooling\sync_android_branding.cmd http://CLIENTE/ecommerce/api/mobile/v1
flutter clean
flutter pub get
flutter build apk --release --dart-define=SOFT_API_BASE_URL=http://CLIENTE/ecommerce/api/mobile/v1
```

O sync consulta `bootstrap.php` daquele cliente e grava apenas um cache local de build com nome, Package ID, icone/logo, cores, tema, Google/Google Pay e dados do release. O build bloqueia se esse sync nao tiver sido executado.

O `--dart-define=SOFT_API_BASE_URL` continua aceito e tem precedencia para a URL em runtime; normalmente use a mesma URL passada ao sync.


## Implementado nesta versão

### Ajustes 1.6.18

- Após adicionar um produto vindo da busca, a pesquisa é limpa e o app retorna para a Loja.
- A Loja permite escolher cards/fotos em tamanho Grande, Médio ou Pequeno, preservando descrição, preço, badges e ação de carrinho.
- A galeria do produto mantém todas as imagens e inclui o `video_url` como item do carrossel.
- Ao abrir uma sugestão, o app pergunta se deve adicionar o produto atual antes de continuar quando ele ainda não estiver no carrinho.
- Meus Pedidos passa a permitir repetir o pedido, consultando preço/disponibilidade atuais e reconstruindo o carrinho com os itens válidos.
- O detalhe do pedido exibe rastreio/andamento e abre link externo quando o backend enviar URL de rastreamento.
- O histórico/detalhe exibe a forma de pagamento, inclusive múltiplos meios, bandeira, parcelas, provedor e situação quando disponíveis na API.
- Não há nova dependência Flutter e o gerador de pacotes permanece inalterado.

- identidade visual recebida do módulo Mobile/loja: cor primária, secundária, logo, ícone Android e splash;
- Home com carrossel automático de banners, ofertas, busca e produtos; categorias ficam somente na aba própria da barra inferior;
- detalhe completo do produto com galeria, código, marca, departamento, opções/quantidade antes da ficha técnica e observações;
- opcionais/variações vindos do ecommerce;
- quantidade com o mesmo comportamento da loja web:
  - B2C inteiro e mínimo 1;
  - B2B até 3 casas decimais e mínimo 0,001;
  - variações que afetam quantidade, como pacote 500 g / 1 kg, transformam quantidade visual em quantidade real;
  - campanhas SIMPLES, QTDE_MINIMA e LEVE_X_PAGUE_Y calculadas pela mesma regra;
- carrinho persistente no aparelho;
- todos os itens entram selecionados por padrão;
- item pode ser desmarcado e ficar guardado no carrinho para outra compra;
- somente itens selecionados entram no subtotal e são enviados ao checkout;
- checkout inicial com endereço, entrega/retirada, agendamento, pedido mínimo, frete e meios de pagamento recalculados pelo servidor;
- sessão validada antes do checkout, com renovação automática por refresh token; compatibilidade com servidores que não encaminham o header Authorization ao PHP por meio de fallback `X-Soft-Access-Token`.

> Na versão 1.6.1, a confirmação do pedido já usa o backend Mobile; PIX/cartão seguem o HUB configurado e Google Pay aparece separadamente somente quando o driver do HUB estiver preparado para processar o token da carteira.

## Executar

```powershell
flutter pub get
powershell -ExecutionPolicy Bypass -File .\tooling\apply_local_config.ps1
flutter run
```

Para produção use HTTPS com certificado válido para o domínio.



## Conta, checkout e cadastro (V1.3.8)

- A aba Conta sincroniza a sessão atual quando é aberta; login realizado pelo checkout aparece imediatamente na conta.
- Seleção de endereço em blocos, com endereços elegíveis destacados e endereços fora da cobertura desabilitados.
- Calendário de entrega/retirada em pt-BR usando apenas dias aceitos pela regra do servidor.
- Campo de cupom no checkout com recálculo no servidor.
- Cadastro manual B2C e entrada/cadastro com Google quando habilitados pelo módulo Mobile.
- Patch 1.3.8 é cumulativo e inclui as correções de autenticação/cores e splash/branding das versões anteriores.

## Splash e branding Android (V1.3.5)

O splash nativo do Android acontece antes de o Flutter conseguir consultar a API. Por isso o projeto agora possui duas etapas:

1. `sync_android_branding.ps1` baixa o `icon_android_url` (com fallback para `logo_url`) do bootstrap e o embute no splash/icone nativo Android.
2. Assim que o Flutter inicia, ele exibe o `splash_url` configurado no modulo; se nao houver splash, usa o logo e depois o icone Android.

Para sincronizar manualmente:

```powershell
.\tooling\sync_android_branding.cmd https://cliente.exemplo.com/api/mobile/v1
```

Depois rode normalmente:

```powershell
powershell -ExecutionPolicy Bypass -File .\tooling\apply_local_config.ps1
flutter run
```

Ou use:

```powershell
.\tooling\run_android.cmd https://cliente.exemplo.com/api/mobile/v1
```

O `run_android.cmd`, `run_android.ps1`, `build_aab.ps1` e o F5 do VS Code executam a sincronizacao de branding antes do build.


## Ícone do launcher Android

O ícone configurado no módulo Mobile deve ser PNG. Antes de executar/gerar o AAB, use `tooling\sync_android_branding.cmd URL_API` ou `tooling\run_android.cmd URL_API`. O script gera ícones legacy, redondo e adaptive. Se o launcher mantiver o ícone anterior por cache, desinstale o app uma vez e instale novamente.


## 1.4.2
Perfil consolidado em /profile.php, resumo antes do pagamento, finalização idempotente e preferência de notificações.



## 1.6.2

- `flutter build apk --release` aplica automaticamente `tooling/mobile_app_config.json` via Gradle.
- Nome do launcher, package ID, API e identidade local não dependem do bootstrap.
- O ícone Android é regenerado a partir do ícone configurado no módulo Mobile; se não houver ícone exclusivo, usa o logo da loja.
- Campanhas `DESTAQUE_PRODUTO` são entregues como campanhas patrocinadas agrupadas e exibidas logo abaixo do banner principal.
- Para trocar a identidade do cliente, baixe novamente `mobile_app_config.json` em **Mobile > Build**, substitua o arquivo em `tooling/` e recompile.

## 1.6.1
- Navegação: Ofertas, Categorias, Loja (centro), Carrinho e Conta.
- Prioridade comercial Oferta > Favorito > demais e ordenações A-Z, Z-A, preço e departamento.
- Cards alinhados, skin de Oferta/Patrocinado e bloco patrocinado compacto abaixo do banner principal.
- Preço por peso igual ao site: PRECO_CHEIO, CHEIO_E_MENOR e PRECO_MENOR.
- Tema Sistema/Claro/Escuro, persistido no aparelho.
- Nome, package Android, ícone e splash sincronizados do módulo antes de run/build.
- Pagar.me usa a Public Key para tokenização direta no app e a Secret Key já configurada no servidor.
- Google Pay é uma opção separada do cartão e depende de configuração/driver compatível do HUB.
- HUB e pagamentos offline são mutuamente exclusivos.


## Configuração local - 1.6.1

A identidade estrutural do aplicativo não vem mais do endpoint `bootstrap.php`.
Edite/substitua `tooling/mobile_app_config.json` (preferencialmente baixado na aba **Mobile > Build** do ecommerce) e execute:

```powershell
powershell -ExecutionPolicy Bypass -File .\tooling\apply_local_config.ps1
flutter build apk --release
```

Para o ambiente de teste desta entrega, a API já está localmente definida como:
`https://cliente.exemplo.com/api/mobile/v1`.

Não é necessário usar `--dart-define=SOFT_API_BASE_URL=...`.

O bootstrap permanece para regras que realmente são de servidor: licença da plataforma, atualização mínima, meios de pagamento efetivamente disponíveis, produtos, ofertas, favoritos, estoque, campanhas, checkout e demais regras comerciais.
