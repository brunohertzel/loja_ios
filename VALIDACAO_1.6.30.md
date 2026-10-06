# Validação da entrega — 1.6.30 / Mobile 1.14.1

PHP 7.4: 312 arquivos sem erros de sintaxe. Análise Dart: zero erros; 39 avisos/informações herdados da base. Shell iOS: sintaxe válida. Android/iOS compartilham o mesmo código de interface.

Testes reais MariaDB 10.11 e HTTP com tokens reais: entrega alternativa pelo vínculo correto; principal conforme a regra de entrega_id NULL/0 do checkout do site; snapshot preservado; retirada sem endereço; bloqueio de dados de outros clientes; aviso antigo retirado. Endereços: criação/edição persistem; CEP/UF/logradouro inválidos rejeitados sem gravar; edição de endereço de outro cliente bloqueada; preservação do local anterior nos pedidos sem snapshot antes de editar principal/alternativo.

Sobre o App: endpoint devolve o telefone (41) 3263-4580 e o logo da AM Soft; mudar os dados da desenvolvedora no banco atualiza a resposta sem recompilar. Contatos da loja continuam na empresa oficial. Aceites, documentos, SAC e solicitações de privacidade mantêm isolamento e gravação correta.

Sincronização iOS executada contra servidor HTTP de teste: nome com acentos, bundle, cores, tema, Google e release substituem o cache; versão/build vêm do servidor; metadados de chamada vêm do projeto; resposta inválida/plataforma bloqueada interrompem sem substituir o release.

Instalador e regressão: Admin/CSRF; GET sem aplicação; payload com hashes; POST; backup/rollback; geração 123 preservada; 38 triggers; fila compacta de dimensões; idempotência; mutex do worker; rollback de versão/triggers. Outros módulos do Soft Licenças idênticos à 2.14.0.

Patches aplicados a cópias limpas da 1.6.29+187 (Android original e REV1; iOS completo) reproduzem os respectivos completos byte a byte. Arquivos de assinatura privados não são distribuídos nem substituídos. ZIPs íntegros.

Limites: sem build Flutter/Gradle completo, execução Windows/macOS, testes de widgets ou teste físico nesta máquina Linux. Assinatura automática Android é a mesma REV1 já validada. O fluxo PowerShell foi revisado, mas sua execução precisa ocorrer no Windows. Mensagens próprias do plugin de biometria são configuradas em português; mensagens exclusivas do sistema seguem o idioma do aparelho. Interface completa em inglês/espanhol e tradução do catálogo não incluídas.
