# Soft Ecommerce Mobile iOS 1.6.20+178

Este pacote usa a mesma base funcional do Android 1.6.19, com adaptacao iOS sem duplicar a regra da loja.

## Primeira execucao no Mac

Requisitos:
- macOS com Xcode instalado e aberto ao menos uma vez;
- Flutter no PATH (`flutter --version`);
- CocoaPods recomendado (`pod --version`);
- para iPhone fisico: Apple ID/Team configurado no Xcode.

No Terminal, dentro da pasta do projeto:

```bash
chmod +x tooling/*.sh
./tooling/prepare_ios.sh http://softpinhais.ddns.net:8585/ecommerce/api/mobile/v1
./tooling/run_ios.sh
```

O `prepare_ios.sh`:
1. consulta o bootstrap como plataforma `IOS`;
2. valida se iOS esta licenciado/habilitado no modulo Mobile;
3. pega nome do app, Bundle ID, icone iOS, cores e versao do cliente;
4. gera a pasta `ios/` usando a versao do Flutter instalada no Mac;
5. configura Face ID/Touch ID, camera/fotos e Bundle ID;
6. libera HTTP para o ambiente de teste atual (ATS); em producao use HTTPS;
7. instala dependencias e executa `flutter analyze`.

## Abrir no Xcode

```bash
./tooling/open_xcode.sh
```

Para iPhone fisico, em **Runner > Signing & Capabilities**, selecione o seu **Team**. Tambem e possivel preparar ja com Team ID:

```bash
SOFT_IOS_TEAM_ID=SEU_TEAM_ID ./tooling/prepare_ios.sh http://softpinhais.ddns.net:8585/ecommerce/api/mobile/v1
```

## Gerar IPA

```bash
./tooling/build_ipa.sh
```

O archive/IPA fica em `build/ios/`.

## Observacoes atuais

- API e origem dos pedidos usam `IOS` automaticamente.
- Face ID / Touch ID usa o mesmo recurso de biometria do Mobile.
- Google Pay fica oculto no iOS.
- Apple Pay fica temporariamente oculto ate ligarmos a tokenizacao da carteira ao HUB; isso nao bloqueia PIX, cartao, dinheiro/entrega, retirada e os demais meios existentes.
- Login Google pode exigir o OAuth Client ID iOS/URL Scheme da Apple/Google antes de ser usado em producao. O restante do app nao depende disso.
- O rodape da aba Conta continua exibindo versao/build e data/hora de preparacao para debug.
