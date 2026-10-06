# Flutter Android 1.4.0

- Acesso passa a ser autenticado antes de abrir a Home.
- Sessao persistente nao entra silenciosamente na loja: exige biometria ou CPF/CNPJ/e-mail + senha.
- Biometria habilitada e com refresh token salvo abre automaticamente ao iniciar o app.
- Depois de autenticado, a Home continua sendo a primeira tela.
- Checkout reaproveita a sessao ja desbloqueada e nao deve abrir Login na primeira finalizacao.
- Campo de usuario pode ser lembrado no aparelho quando `Manter conectado` estiver ativo.
- A senha nao e gravada pelo app; pode ser preenchida pelo gerenciador de senhas do Android via autofill.
