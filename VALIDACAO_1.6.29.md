# Validação da entrega — 06/10/2026

PHP 7.4: 253 arquivos do Soft Licenças e instalador sem erros de sintaxe.
Análise Dart: zero erros; 40 avisos/informações herdados da base. Android e iOS compartilham o mesmo código Dart.

Testes MariaDB 10.11 e HTTP com sessões reais: instalação idempotente; snapshot do endereço selecionado, inclusive complemento; manutenção do endereço histórico após mudança cadastral; retirada sem endereço; bloqueio de pedido/endereço/disputa de outro cliente; contatos da empresa oficial; documentos legais da mesma tabela do site; rejeição de versão/hash obsoletos sem gravar aceite; aceite explícito sem duplicação; exigência de novo aceite após mudança de versão; gravação no SAC e histórico existentes; prevenção de segunda solicitação aberta; resposta da loja disponível no app; solicitação de privacidade persistida e isolada por cliente; exclusão não executada automaticamente.

Regressão de infraestrutura e instalador: geração ativa, ativação e produtos preservados; 38 triggers; dimensões sem fan-out; mutex de worker; análise GET sem aplicação; Admin e CSRF obrigatórios; aplicação do payload verificado; rollback de arquivos/triggers/versão.

Cada ZIP passou por verificação de integridade. Ambos os patches foram aplicados a cópias limpas da versão 1.6.28+186 e reproduziram os arquivos dos respectivos pacotes completos byte a byte. Os outros módulos do Soft Licenças permanecem idênticos aos do pacote 2.13.0.

Limites: testes Flutter de widgets foram adicionados, mas não executados aqui porque o SDK local está incompleto (flutter_tools/engine). Não houve compilação APK/IPA nem teste físico nesta máquina Linux. Execute flutter test e compile release no ambiente completo, com assinatura própria. Idiomas e tradução automática não estão incluídos nesta versão.
