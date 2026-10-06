# 1.6.0

Veja CHANGELOG_1.6.0.md.

## 1.4.2

- Pagamento em dinheiro com opção de troco e valor informado pelo cliente.
- Observações do pedido no fim do checkout.
- Depois de adicionar ao carrinho, o detalhe fecha e retorna à listagem.
- Integração com Mobile 1.7.1 para validação do troco no servidor.

## 1.3.8

- Pedidos, perfil, biometria e launcher adaptativo.
- Fundação de notificações push no módulo Mobile.

# Soft Ecommerce Loja Mobile Android

## 1.3.4

- Corrige loop login -> checkout -> login: nao invalida token recem emitido antes do checkout.
- Envia access token tambem no JSON autenticado como fallback para Apache/XAMPP.
- Se access/refresh antigos forem realmente recusados, limpa a sessao e abre o login uma unica vez.
- `me.php` passa a usar POST autenticado.
- Aplica as cores primaria e secundaria exatas do bootstrap, sem paleta Material gerada por seed.
- AppBar/botoes usam a primaria; navegacao/badges usam a secundaria.

## 1.3.3
- Home não repete mais Categorias; acesso fica somente na barra inferior.
- Corrigido fluxo login -> checkout para não validar duas vezes a sessão recém-criada.
- API Client envia Authorization e fallback X-Soft-Access-Token para Apache/XAMPP/CGI.
- Endpoints públicos da vitrine não carregam token antigo da sessão.

# Changelog

## 1.6.18
- Busca limpa e retorna para a Loja após adicionar o produto ao carrinho.
- Tamanhos Grande/Médio/Pequeno para os cards da Loja, com preferência persistida no aparelho.
- Carrossel de mídia do produto inclui imagens e vídeo (`video_url`).
- Sugestões perguntam se o produto atual deve ser adicionado antes da navegação.
- Meus Pedidos ganha Repetir pedido, rastreio/andamento e detalhamento da forma de pagamento.
- Repetição consulta o catálogo atual e informa itens indisponíveis ou que exigem configuração não recuperável.
- Sem alteração do gerador de pacotes e sem dependências novas.

## 1.6.17
- Ficha técnica usa o HTML real enviado pelo Mobile, preservando títulos, listas e tabelas.
- Produto passa a exibir recomendações cadastradas no ecommerce.
- Aba Ofertas ganha filtros também para campanhas normais ativas pelo nome da campanha (ex.: 1/1, 2/2).
- Mantém filtros Todas e Patrocinadas e todas as rotinas já estáveis da 1.6.16.
- Compatível com Mobile 1.10.0 / Soft Licenças 2.9.6.

## 1.6.16
- Corrige compilação da ficha técnica HTML: `element.localName` pode ser nulo.
- Scripts de branding/configuração deixam de regravar arquivos idênticos durante o Gradle build.
- Evita a mensagem `File modified during build. Build must be rerun` quando a configuração já foi sincronizada.
- Alteração exclusiva do app; Soft Licenças permanece 2.9.5 e Mobile permanece 1.9.9.

## 1.6.15
- Mantém o comportamento Android/build estável da 1.6.13.
- Remove da linha comercial as alterações experimentais de assinatura/rede da 1.6.14.
- Corrige o erro PowerShell causado pelo uso da variável reservada `$Host`.
- Aba Ofertas com filtros: Todas, Patrocinadas e campanha/patrocinador específico.
- Ficha técnica passa a renderizar o HTML do ecommerce em layout nativo Flutter.
- Alteração exclusiva do app; Soft Licenças permanece 2.9.5 e Mobile permanece 1.9.9.

## 1.6.13
- Corrige a aba Ofertas para sempre exibir as ofertas normais quando nenhum filtro patrocinado estiver ativo.
- Consolida ofertas do payload `offers` com produtos promocionais presentes na Home.
- Campanha patrocinada passa a ser apenas um filtro temporário da aba Ofertas.
- Adiciona chip visível `Patrocinada: ...` com remoção rápida para voltar a `Todas as ofertas`.
- Alteração exclusiva do app; Mobile permanece 1.9.9 e Soft Licenças 2.9.5.

## 1.6.12
- Restaura as ofertas normais mesmo quando uma patrocinada foi aberta.
- Tocar na aba Ofertas sempre volta para a listagem normal; o CTA da campanha abre o contexto patrocinado.
- Dentro de uma campanha patrocinada, as ofertas normais continuam abaixo em "Outras ofertas".
- Hero/logo/wallpaper tentam todos os assets reais enviados pelo Mobile, com fallback de rede por asset.
- Mantidos AGP 8.9.2, Gradle 8.11.1, carrinho, SOFIE e preço fracionado.

## 1.6.11
- Campanha patrocinada passa a preservar a arte principal (hero), logo do patrocinador e background como assets separados.
- Home Mobile exibe a arte real da campanha em vez de reconstruir um quadro genérico.
- Tela interna de Ofertas patrocinadas usa a arte e o background da campanha, com fallback visual entre hero/logo.
- Mantidos preço fracionado, SOFIE, carrinho e toolchain Android já estabilizados.

## 1.6.10
- Corrige erro de compilação da 1.6.9 causado pela ausência do widget `_SkinBadge`.
- Nenhuma alteração no Mobile 1.9.7, Soft Licenças 2.9.3, branding ou toolchain Android.

## 1.6.9
- Identidade patrocinada real, SOFIE com ícone/configuração Mobile e preço fracionado alinhado à vitrine WEB.

## 1.6.8
- Campanhas patrocinadas 2.0: logo/cores reais e navegação interna para a aba Ofertas.
- Ofertas patrocinadas ganham layout próprio no app.
- Carrinho Mobile usa o mesmo carrinho mais recente que a SOFIE.
- SOFIE sobe acima da navegação do Android e o chat respeita SafeArea/teclado.
- Pedidos 2.0: cor real do status, filtros rápidos e busca.

## 1.6.7
- Corrige build Android com dependências AndroidX atuais: AGP 8.9.2 + Gradle 8.11.1.
- `prepare_android.ps1` passa a manter o mesmo toolchain e não rebaixa mais para AGP 8.6.1.
- Bootstrap/branding é lido em bytes e decodificado explicitamente como UTF-8 no Windows PowerShell 5.1.
- Leitura do cache `mobile_app_config.json` também passa a ser UTF-8 explícito.
- Nenhuma alteração no servidor/Mobile 1.9.5 é necessária.

## 1.6.6
- UX de patrocinadas, foto de perfil, recuperação de senha, UTF-8, carrinho sincronizado e SOFIE circular.

## 1.3.2
- Checkout valida a sessão antes de abrir; access token expirado tenta refresh automaticamente e, se necessário, abre o login em vez de exibir apenas "Sessão expirada".
- Home continua sendo a tela inicial, mesmo com sessão salva/expirada.
- Detalhe do produto: opcionais, quantidade e observações ficam definitivamente antes de Informações/Ficha técnica.
- Categorias da Home redesenhadas como cards horizontais clicáveis, com imagem quando disponível.
- Banners agora são carrossel real com swipe, autoplay e indicadores; título/subtítulo não ficam mais sobre a arte quando existe imagem.


## 1.2.1
- Corrigida inferência `num` no carrinho (`step`/`quantity`) que impedia o build Flutter.
- `total` do carrinho agora usa `fold<double>(0.0, ...)`.

## 1.2.0
- Corrigida a finalidade do aplicativo: agora é a loja para o cliente final, não um painel administrativo.
- Navegação pública sem login obrigatório.
- Home/vitrine, banners, categorias, ofertas, busca, produto e carrinho.
- Login/biometria movidos para Minha Conta/checkout.
- Gradle 8.7, AGP 8.6.1 e Kotlin 2.1.20 na base Android.
- Manifest de debug corrigido para HTTP local.
- Launch configuration do VS Code incluída.

## 1.1.2
- Correção de usesCleartextTraffic no manifest de debug.

## 1.3.0+4
- Identidade visual sincronizada com o módulo Mobile/loja.
- Produto completo com variações e regras de quantidade iguais ao site.
- Campanhas por quantidade e Leve X Pague Y no detalhe/carrinho.
- Carrinho persistente com seleção/desseleção de itens para comprar depois.
- Checkout de preparação: endereço, entrega/retirada, agendamento, mínimo, frete e meios de pagamento.


## 1.5.0
Favoritos, aba Ofertas, Loja central, branding inicial limpo, nome do app no build e Pagar.me Mobile corrigido.

## 1.6.4

- Corrige falha de build no Windows causada por BOM UTF-8 no `tooling/mobile_app_config.json`.
- `sync_android_branding.ps1` passa a gravar o cache JSON em UTF-8 sem BOM, inclusive no Windows PowerShell 5.1.
- `build.gradle.kts` remove `U+FEFF` antes de interpretar o JSON, mantendo compatibilidade com caches já gerados pela 1.6.3.
- Mantém o fluxo comercial por cliente: `sync_android_branding.cmd URL_DA_API_MOBILE` continua sendo a fonte de branding/release antes do build.
- Nenhuma alteração no módulo/Soft Licenças é necessária.

## 1.6.3
- Branding/release novamente sincronizados por cliente antes da compilacao.
- Sem identidade fixa no pacote comercial.
- Trava contra build sem sincronizacao e leitura de release/package/icone/nome pelo bootstrap Mobile.

## 1.6.5

- Patrocinadas via Marketing & Analytics, SOFIE nativa, contraste escuro adaptativo e preço fracionado conforme parâmetros da loja.
