# Soft Ecommerce Mobile 1.4.1

- Corrige 404 de Meus Pedidos, Favoritos e Meus Endereços usando um endpoint de perfil único no nível raiz da API Mobile.
- Exibe o resumo e o total do pedido, já com frete/desconto, antes da escolha da forma de pagamento.
- Finalização de pedido com chave de idempotência para evitar pedido duplicado em retry/time-out.
- Notificações no perfil agora são somente um liga/desliga e a preferência é persistida no servidor por cliente/dispositivo.
- Mantém autenticação persistente/biometria e todo o histórico das versões anteriores.
