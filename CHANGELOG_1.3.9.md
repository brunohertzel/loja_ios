# Flutter Android 1.3.9

- Corrige o redirecionamento indevido para Login na primeira entrada do checkout.
- A sessao existente agora e validada silenciosamente no servidor antes do checkout.
- Access token expirado e renovado pelo refresh token sem interromper a compra.
- Somente refresh token realmente invalido/revogado abre novamente a tela de Login.
- Falha temporaria de rede/HTTP 5xx nao apaga mais a sessao local nem e tratada como logout.
- Repeticao da chamada autenticada aguarda a gravacao do token renovado antes de prosseguir.
