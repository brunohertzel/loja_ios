# iOS de produção — 1.6.28 (186)

Projeto completo com o mesmo código de negócio do Android 1.6.28: correções de sessão/carregamento, Read Model, paginação, ofertas/patrocinadas, cards, imagens/vídeo, busca e leitura de código de barras. Diagnóstico visível removido. A API recebe `IOS`, e licença/ativação/branding são consultados para a plataforma iOS.

A pasta `ios` contém projeto Runner, workspace, configurações Release, Podfile, ícones e permissões para câmera, fotos e Face ID. A câmera também atende a leitura de códigos de barras. O projeto exige iOS 15.5 ou superior, conforme o plugin de leitura utilizado. O fluxo existente de Google Pay é exclusivo do Android; Apple Pay continua dependendo da integração de carteira já prevista, sem finalizar pagamento sem token.

No Mac, execute `bash tooling/prepare_ios.sh https://domlevi.com.br/api/mobile/v1`. Configure `SOFT_IOS_TEAM_ID` para a sua equipe Apple. O script sincroniza a identidade do módulo, configura o projeto existente e instala as dependências. A API deve permitir a plataforma iOS na licença e no configurador.

Para gerar IPA: `bash tooling/build_ipa.sh`. Para Codemagic, há `codemagic.yaml` com workflow de IPA Release assinado. Envie o certificado Apple Distribution e o provisioning profile App Store correspondentes ao Bundle ID e selecione o workflow. O YAML não publica automaticamente no App Store Connect.

Identidade inicial: Dom Levi / `br.com.softsistemas.domlevi`; a configuração do módulo iOS é a fonte autoritativa antes da compilação. Para login Google, mantenha o client ID Web no módulo e informe `SOFT_GOOGLE_IOS_CLIENT_ID` ao preparar o projeto. O script grava `GIDClientID` e seu URL Scheme reverso; `SOFT_GOOGLE_IOS_REVERSED_CLIENT_ID` permite um esquema explícito.

Este pacote é código fonte. A geração e assinatura do IPA exigem macOS/Xcode ou Codemagic e os certificados da sua conta. A validação física em iPhone permanece pendente.
