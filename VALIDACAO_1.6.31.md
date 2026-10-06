# Validação 1.6.31 / Mobile 1.14.2

Configuração Admin: teste HTTP/PHP 7.4 com sessão real e MariaDB reproduziu a interrupção após o título na 1.14.1. A versão corrigida renderizou até o fechamento da página nas 10 abas, tanto por admin/mobile/index.php quanto admin/config/modulos/mobile/index.php. Sobre o App salvou os dados que a API devolveu. Nenhum header/sidebar global foi alterado.

Pesáveis: testes reais com tabelas de produtos, unidades, preços, opcionais e carrinho no MariaDB e requests HTTP autenticados. Produto/carrinho consultam as regras atuais da loja; casos B2C e B2B, ativado/desativado, 1/2/3 casas, produto UN inteiro e porção de 500 g. A quantidade real enviada pelo novo app não define o peso: o servidor normaliza a quantidade visual com as regras atuais e multiplicador oficial. Checkout: normalização real rejeita digitação fracionada quando desativada e converte inteiros de porções corretamente. Payload antigo de carrinho permanece compatível. Testes Dart executados para precisão, mínimo, máscara SHIFT, porção e serialização das regras; script reproduzível tooling/check_quantity_rules.dart.

Regressão HTTP: endereços criar/editar/validar/isolamento, preservação de entrega histórica, Sobre o App, SAC, privacidade, termos e aceites passaram. Instalador: Admin/CSRF, verificação de hashes, aplicação, preservação de geração 123 e catálogo, 38 triggers, idempotência, mutex e rollback passaram.

PHP 7.4: 312 arquivos sem erros de sintaxe. Análise Dart: zero erros, 39 avisos/informações herdados. Android/iOS compartilham lib idêntica. Patches sobre 1.6.30+188 reproduzem os completos byte a byte e preservam arquivos privados de assinatura. ZIPs íntegros. Demais módulos Soft Licenças iguais à 2.14.1.

Limites: sem APK/IPA pré-compilados, build Flutter/Gradle completo, execução Windows/macOS, teste de widgets ou aparelho físico nesta máquina. Máscara de teclado deve ser conferida em aparelho na homologação. Branding/release permanecem sincronizados da API; a compilação usa a configuração do servidor. Assinatura Android preserva o fluxo de produção que já compilou no seu Windows.
