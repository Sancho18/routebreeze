# RouteBreeze

App Flutter de roteirização de entregas: bloqueio biométrico, endereços com autocomplete, rota otimizada e navegação em tempo real com recálculo automático.

![CI](https://github.com/Sancho18/routebreeze/actions/workflows/ci.yml/badge.svg)

## Sobre

O RouteBreeze ajuda um entregador a visitar vários endereços na melhor ordem. O fluxo tem seis passos:

1. **Bloqueio.** O app abre pedindo biometria. Se não houver biometria cadastrada, usa o PIN, padrão ou senha do aparelho.
2. **Mapa.** O mapa centraliza na posição atual (zoom 16) com o marcador "Partida". Esse é o ponto de origem da rota.
3. **Endereços.** O entregador digita três ou mais endereços e escolhe cada um na lista de sugestões do Google Places.
4. **Rota otimizada.** Uma única chamada à Routes API devolve a melhor ordem de visita. O app desenha a rota no mapa e numera as paradas de 1 a N.
5. **Navegação.** Ao tocar em "Iniciar", a posição é acompanhada em tempo real. A câmera segue o usuário e cada parada é marcada como visitada ao chegar.
6. **Recálculo.** Se o entregador sai da rota, o app pede uma nova rota pelas paradas que faltam e mostra o aviso "Rota recalculada".

Feito com Flutter 3.47.5 e o design system **Rota** (tokens em `lib/core/theme/rb_tokens.dart`). Interface em português do Brasil.

## Demonstração

> Vídeo do fluxo completo: em breve neste espaço.

APK de release (Android): [Release v0.1.0](https://github.com/Sancho18/routebreeze/releases/tag/v0.1.0), arquivo `app-release.apk`. Esse APK já sai com uma chave de teste embutida (restrita às APIs que o app usa), então dá para instalar com `adb install app-release.apk` e testar sem configurar nada. Para rodar a partir do código, veja "Configuração da chave do Google".

## Requisitos

- Flutter 3.47.5 (canal stable), que traz o Dart 3.13
- Android SDK e um aparelho ou emulador Android
- Xcode (opcional, só para compilar o iOS)
- Uma chave do Google Cloud com as quatro APIs da seção abaixo

## Configuração da chave do Google

### APIs a ativar no projeto Google Cloud

- Maps SDK for Android
- Maps SDK for iOS
- Places API (New)
- Routes API

### Registrar a chave

Opção 1, pelo script (na raiz do projeto). Sem argumento ele pede a chave sem ecoar, para ela não ficar no histórico do shell:

```bash
tool/set_api_key.sh
```

O script escreve dois arquivos ignorados pelo Git (modo 600):

- `env.json` com `{"GOOGLE_MAPS_API_KEY": "SUA_CHAVE"}`
- `ios/Flutter/Secrets.xcconfig` com `GOOGLE_MAPS_API_KEY=SUA_CHAVE`

Opção 2, manual: copie `env.example.json` para `env.json` e troque o valor. Para o iOS, crie `ios/Flutter/Secrets.xcconfig` com a linha `GOOGLE_MAPS_API_KEY=SUA_CHAVE`.

### Como a chave chega em cada lugar

- **Dart.** `--dart-define-from-file=env.json` preenche `Env.googleMapsApiKey` (`lib/core/config/env.dart`). O `Dio` envia a chave no header `X-Goog-Api-Key` das chamadas REST a Places e Routes.
- **Android.** `android/app/build.gradle.kts` lê `env.json` no build e injeta o valor no `AndroidManifest.xml` (`com.google.android.geo.API_KEY`) por um placeholder de manifest.
- **iOS.** `Secrets.xcconfig` é incluído pelos xcconfig do Flutter. O `Info.plist` expõe `GMSApiKey` e o `AppDelegate` chama `GMSServices.provideAPIKey`.

### Por que a chave não está no Git

`env.json` e `ios/Flutter/Secrets.xcconfig` estão no `.gitignore`. Só `env.example.json` é versionado. Assim o repositório pode ser público sem expor a chave, e cada pessoa compila com a sua.

Sem `env.json` o app falha ao abrir com uma mensagem que aponta para o arquivo. `flutter analyze` e `flutter test` não precisam da chave.

### Para quem for avaliar

Use a sua própria chave (com as quatro APIs ativadas) ou a chave que envio em separado. Nos dois casos basta rodar `tool/set_api_key.sh SUA_CHAVE` e seguir para "Como rodar".

## Como rodar

```bash
flutter pub get
flutter run --dart-define-from-file=env.json
```

No VS Code, use a configuração **RouteBreeze (debug, env.json)** de `.vscode/launch.json`, que já passa o `--dart-define-from-file`. Sem esse argumento o app para na checagem da chave antes de abrir a primeira tela.

Recomendo um aparelho físico: biometria e GPS de verdade. No emulador Android dá para cadastrar uma digital nas configurações e simular a posição pelos "Extended controls > Location".

## Build

APK de release:

```bash
flutter build apk --release --dart-define-from-file=env.json
```

Saída: `build/app/outputs/flutter-apk/app-release.apk` (cerca de 53 MB, com as três ABIs: arm64-v8a, armeabi-v7a e x86_64). Para um APK menor por arquitetura, acrescente `--split-per-abi`. O build leva pouco mais de um minuto em um Mac com o Gradle já aquecido.

Instalação no aparelho: `adb install build/app/outputs/flutter-apk/app-release.apk`. A pasta `build/` está no `.gitignore`; o APK vai para a página de Releases, não para o repositório.

O build de release usa a assinatura de debug (`signingConfig = debug` em `android/app/build.gradle.kts`). Isso basta para instalar e testar. Para publicar na loja seria preciso um keystore próprio.

iOS: `flutter build ios --no-codesign` compila com as permissões e a chave configuradas. Não validei em aparelho iOS.

## Testes e qualidade

```bash
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
```

São 405 testes de unidade, Cubit (`bloc_test`) e widget em `test/`, espelhando a árvore de `lib/`. Regras de domínio testam os valores exatos (50 m, 3 fixes, 30 m, 20 s, 40 m, 300 ms, 3 caracteres, 15 s). `test/app_flow_test.dart` percorre as rotas nomeadas de ponta a ponta com Cubits reais e serviços falsos (desbloqueio, ponto de partida, três endereços, rota otimizada, navegação e "Encerrar"); os `GoogleMap` padrão das telas são montados com um dublê dos canais de plataforma (`test/helpers/fake_google_map.dart`), o que permite verificar zoom, marcadores e movimentos de câmera.

### Cobertura

```bash
flutter test --coverage
python3 tool/coverage_report.py   # lê coverage/lcov.info (só stdlib)
```

O script agrega linhas por pasta, lista os arquivos abaixo de 90 % e imprime dois totais: todos os arquivos e sem os arquivos *native-only* (código que só executa num aparelho, hoje apenas `lib/main.dart`: `configureDependencies()` e `runApp()` após a checagem da chave). Sai com código 1 quando alguma pasta ou o total fica abaixo de 90 %.

| Pasta | Linhas | Cobertas | % |
| --- | ---: | ---: | ---: |
| lib/core | 257 | 256 | 99,6 % |
| lib (raiz: `app.dart`, `main.dart`) | 80 | 78 | 97,5 % |
| lib/features/addresses | 306 | 304 | 99,3 % |
| lib/features/location | 166 | 166 | 100,0 % |
| lib/features/lock | 71 | 71 | 100,0 % |
| lib/features/navigation | 339 | 336 | 99,1 % |
| lib/features/route | 425 | 422 | 99,3 % |
| **Total (todos os arquivos)** | 1644 | 1633 | 99,3 % |
| **Total (sem native-only)** | 1639 | 1630 | 99,5 % |

`test/coverage_helper_test.dart` importa todos os arquivos de `lib/` para que o `lcov.info` liste inclusive os que nenhum teste carregaria. As linhas restantes são `stringify`/`props` de objetos de valor nunca comparados por igualdade nos testes e as duas linhas nativas de `main.dart`.

Teste de integração (precisa de um aparelho conectado; usa fakes para biometria, GPS e Google APIs):

```bash
flutter test integration_test -d <deviceId> --dart-define-from-file=env.json
```

CI: o workflow `.github/workflows/ci.yml` roda no GitHub Actions a cada push e pull request para `main` e `develop`, com Flutter 3.47.5 stable: `flutter pub get`, `dart format --set-exit-if-changed lib test`, `flutter analyze` e `flutter test`.

## Arquitetura

Feature-first, com três camadas por feature:

- `data`: APIs REST, plugins nativos e storage (implementa as interfaces do domínio)
- `domain`: modelos, interfaces e regras puras (sem Flutter nem I/O)
- `presentation`: Cubits e telas

Estado com `flutter_bloc` (Cubit). Injeção de dependência com `get_it`, montada em `lib/core/di/injector.dart`. As telas aceitam o Cubit e os serviços por parâmetro (usado nos testes); em produção vêm do `get_it`.

```
lib/
  main.dart                      binding, checagem da chave, DI, runApp
  app.dart                       MaterialApp, tema, rotas nomeadas, AppLifecycleGate
  core/
    config/env.dart              chave via --dart-define
    di/injector.dart             composição do get_it
    error/failure.dart           Failure (NoConnection, ApiFailure...)
    geo/                         GeoPoint, GeoMath (haversine, ponto-segmento), PolylineCodec
    network/                     Dio (chave, timeouts, retry) e ConnectivityService
    session/session_state.dart   navegação ativa + hooks de pause/resume
    theme/                       RbTokens (design system Rota) e RbTheme
    widgets/                     RbPrimaryButton, RbTextField, RbBanner, RbStatusChip, RbInlineError
  features/
    lock/         data: LocalAuthService (local_auth)
                  domain: AuthResult, RelockPolicy
                  presentation: LockCubit, LockScreen
    location/     data: GeolocatorLocationService
                  domain: LocationService, Fix
                  presentation: MapCubit, MapScreen
    addresses/    data: PlacesApi (autocomplete + details)
                  domain: Stop, Suggestion, AddressField, AddressFormValidator
                  presentation: AddressFormCubit, AddressesScreen, AddressFieldWidget
    route/        data: RoutesApi, RouteStorage (shared_preferences)
                  domain: RoutePlan, RoutePlanner, RouteRepository
                  presentation: RouteCubit, RouteScreen, RouteSheet, MapMarkers
    navigation/   domain: DeviationDetector, ArrivalDetector, RecalcPolicy
                  presentation: NavigationCubit, NavigationScreen
test/            espelha lib/ (unidade, bloc_test, widget)
integration_test/ fluxo principal com fakes, roda no aparelho
tool/            set_api_key.sh
docs/            decisions.md
```

Fluxo de telas: `/lock` → `/map` → `/addresses` → `/route` → `/navigation`. O `AppLifecycleGate` (em `app.dart`) observa o ciclo de vida: rebloqueia ao voltar do segundo plano e pausa/retoma o stream de posição durante a navegação.

Onde ficam as regras puras (todas com teste de unidade):

- `AddressFormValidator`: campo obrigatório, sugestão selecionada, endereço repetido.
- `RoutePlanner`: escolhe o destino (ponto mais distante) e monta a ordem final a partir de `optimizedIntermediateWaypointIndex`.
- `DeviationDetector`: saída da rota (50 m, 3 fixes, precisão ≤ 30 m).
- `ArrivalDetector`: chegada (40 m).
- `RecalcPolicy`: intervalo mínimo, uma requisição por vez, adiamento offline.
- `RelockPolicy`: rebloqueio após 30 s em segundo plano.
- `GeoMath` e `PolylineCodec`: distâncias e decodificação da polyline.

## Decisões técnicas

Resumo abaixo. Cada decisão está detalhada em formato ADR em [`docs/decisions.md`](docs/decisions.md).

### Routes API em vez de Directions API

A Directions API é legada. A Routes API (`computeRoutes`) aceita `optimizeWaypointOrder`, devolve `optimizedIntermediateWaypointIndex` e usa field mask, o que limita o que é cobrado. O app pede só `duration`, `distanceMeters`, `polyline.encodedPolyline`, `legs.distanceMeters`, `legs.duration` e o índice otimizado. É uma requisição por cálculo, com `travelMode: DRIVE`.

### Destino = ponto mais distante da origem

A Routes API exige um destino fixo e só reordena os pontos intermediários. Escolho como destino a parada não visitada mais distante da origem (em linha reta). As demais viram intermediários com otimização ligada. O ponto mais distante costuma ser o fim natural de uma rota de entregas, e a regra mantém uma requisição por cálculo. A mesma regra vale no recálculo, sobre as paradas que faltam.

Limite: a ordem pode não ser a ótima global quando o melhor ponto final não é o mais distante. A alternativa exata seria fazer N requisições (uma com cada parada como destino) e ficar com a de menor duração. Custa N vezes mais chamadas para um ganho pequeno em rotas de bairro, então ficou de fora.

### Places API (New) com session tokens e field mask enxuta

Autocomplete: mínimo de 3 caracteres, debounce de 300 ms, no máximo 5 sugestões, `locationBias` circular de 50 km ao redor da partida, `includedRegionCodes: br` e `languageCode: pt-BR`. Cada campo tem o seu session token. O Place Details usa o mesmo token e a field mask `id,formattedAddress,location` (SKU Essentials), o que fecha a sessão. Depois da seleção o campo recebe um token novo. Resultado: um Place Details por endereço escolhido e autocomplete só depois do debounce. O bias é só uma dica: endereços a mais de 50 km continuam válidos.

### Limiares de desvio, chegada e recálculo

- **Fora da rota:** 3 fixes consecutivos a mais de 50 m da polyline, contando só fixes com precisão ≤ 30 m. Um fix repetido (mesmo timestamp) conta uma vez.
- **Recálculo:** no mínimo 20 s entre dois recálculos e um por vez. Só as paradas não visitadas entram, com a mesma regra de destino. Ao chegar, a polyline é trocada, as paradas renumeradas e o aviso "Rota recalculada" fica 4 s na tela.
- **Chegada:** a 40 m da próxima parada ela é marcada como visitada. Há também o botão "Marcar como visitado", útil para demonstrar sem ir até o local.
- **Qualidade do GPS:** "Iniciar" só habilita quando o último fix tem precisão ≤ 50 m; antes disso aparece "Aguardando sinal de GPS". No mapa inicial, a partida precisa de um fix com precisão ≤ 50 m em até 15 s.

### Offline: rota persistida e recálculo adiado

- Sem conexão, um banner "Sem conexão" aparece no topo da tela. Em Endereços, "Confirmar rota" desabilita e o autocomplete não é chamado, mas o texto digitado fica.
- A rota ativa (ordem, flags de visitado, polyline e totais) é salva em `shared_preferences` ao ser calculada e a cada parada visitada. É apagada ao concluir ou ao começar uma rota nova. Fica em texto puro, só na sandbox do app; o backup automático do Android está desligado (`android:allowBackup="false"`) para ela não ir para a nuvem.
- Se o app for encerrado com uma rota em andamento, ao abrir de novo (depois do desbloqueio) ele oferece "Continuar rota?" e abre a navegação com o plano salvo.
- Offline durante a navegação, o acompanhamento e a detecção de chegada seguem funcionando. O recálculo fica pendente ("Recálculo pendente (sem conexão)") e roda sozinho quando a conexão volta.
- Toda requisição tem timeout de 10 s e uma nova tentativa após 2 s em erro de conexão.

### Bateria e GPS

O stream de posição só existe durante a navegação: precisão máxima com `distanceFilter` de 5 m (parado, não há eventos). Ele é pausado quando o app vai para segundo plano e retomado na volta, e é encerrado em "Encerrar" ou ao concluir a rota. Não há localização em segundo plano nem foreground service. No mapa inicial uso um único fix, não um stream.

### Bloqueio

`local_auth` com `biometricOnly: false`: o sistema oferece biometria e cai para PIN, padrão ou senha sem mensagem de erro. O prompt abre no primeiro frame da tela. O app rebloqueia ao voltar do segundo plano após 30 s ou mais, exceto com uma navegação ativa (para não interromper a rota). Aparelho sem biometria e sem bloqueio de tela fica bloqueado com "Configure um bloqueio de tela no aparelho para usar o app" e um botão para tentar de novo.

### Chave de API

Uma chave, restrita às quatro APIs usadas e com cotas diárias. Ela não tem restrição por aplicativo (SHA-1 ou bundle id) de propósito: assim o projeto compila e roda em qualquer máquina, inclusive a de quem avalia. Em produção eu separaria uma chave por plataforma com restrição de app para os Maps SDKs, colocaria Places e Routes atrás de um backend que guarda a chave e faria rotação periódica.

### Design system Rota como código

Os tokens ficam em um só arquivo (`RbColors`, `RbText`, `RbSpace`, `RbRadius`): 9 cores, 6 estilos de texto, 4 espaçamentos e 3 raios. Os widgets base (`RbPrimaryButton`, `RbTextField`, `RbBanner`, `RbStatusChip`, `RbInlineError`) usam só esses valores, e `buildRbTheme` os aplica ao Material. Fonte do sistema, sem fonte embarcada. O botão primário desabilitado usa `border` com texto `ink-muted`; habilitado usa `brand` com texto branco `body-strong` no mesmo raio e altura, então nada pula de lugar. Na lista de paradas, a parada visitada troca o número por um círculo `success` com um check ("entrega concluída" é um dos usos listados para `success`), e as linhas ficam a `space-2` uma da outra, como o DS pede para linhas de lista.

Uma extensão que o DS não lista: o botão "Encerrar" da navegação usa `danger` como fundo, com texto branco, e fica abaixo de "Marcar como visitado" (em `brand`). O DS reserva `danger` para erros, falha de autenticação, permissão negada e sem internet; usei a mesma cor para a única ação destrutiva do app porque ela interrompe a navegação em andamento e a cor evita o toque por engano ao lado do botão que o motorista usa o tempo todo. É a mesma paleta, o mesmo `radius-lg` e a mesma altura do botão primário, então o componente é o `RbPrimaryButton` com a cor trocada. A rota é desenhada em `brand` com 5 px, os marcadores numerados são desenhados em canvas e o marcador de partida é um pino distinto. Testes de widget conferem esses valores.

### Generalização para N endereços

"Adicionar ponto" cria campos sem limite ("Ponto D", "Ponto E"...), cada um com controle de remoção. Todo campo presente precisa de uma sugestão selecionada; editar depois de escolher invalida o campo; dois campos com o mesmo `placeId` recebem "Endereço repetido". A rota usa todas as paradas em uma única requisição e os marcadores vão de 1 a N.

### Câmera do mapa

Zoom 16 na partida. Na tela de rota a câmera enquadra a rota inteira. Na navegação ela segue o usuário; arrastar o mapa solta a câmera e mostra "Recentralizar", que volta a seguir.

## Tratamento de erros e casos extremos

| Cenário | Comportamento |
| ------- | ------------- |
| Permissão de localização negada | Card com "Precisamos da sua localização para seguir. Ela define o ponto de partida da sua rota." e o botão "Permitir localização", que pede de novo |
| Permissão negada permanentemente | Mesmo texto mais "Você negou o acesso. Ative em Configurações." e o botão "Abrir configurações" |
| GPS do aparelho desligado | "Ative a localização do dispositivo para continuar." com "Ativar localização" |
| GPS impreciso no mapa inicial (sem fix ≤ 50 m em 15 s) | "Não conseguimos uma posição precisa. Verifique se está em local aberto." com "Tentar novamente"; "Para onde vamos?" fica desabilitado |
| GPS impreciso antes de iniciar a navegação | "Aguardando sinal de GPS" e "Iniciar" desabilitado até um fix ≤ 50 m |
| Erro no stream de posição | "Perdemos o sinal de GPS" em `danger`; a última posição é mantida |
| Fixes ruins durante a navegação (precisão > 30 m) | Ignorados na detecção de desvio; não disparam recálculo |
| Sem internet em Endereços | Banner "Sem conexão"; "Confirmar rota" desabilitado; autocomplete suspenso; texto mantido |
| Sem internet na Rota | O cálculo falha (uma nova tentativa automática após 2 s) e mostra "Não foi possível calcular a rota." com "Tentar novamente" |
| Sem internet na Navegação | Banner "Sem conexão"; acompanhamento e chegada continuam; recálculo pendente até a conexão voltar |
| Falha do Autocomplete ou do Place Details | "Não foi possível buscar endereços. Tente novamente." sob o campo; texto mantido |
| Falha da Routes API (erro HTTP, sem rota, legs a menos) | "Não foi possível calcular a rota." com "Tentar novamente"; voltar mantém o formulário preenchido |
| Falha no recálculo | Rota anterior mantida; aviso "Falha ao recalcular" por 4 s; nova tentativa após 20 s |
| Chave de API ausente | O app falha ao abrir com uma mensagem que cita `env.json` |
| Biometria cancelada | "Autenticação cancelada"; "Desbloquear" continua disponível |
| Muitas tentativas de biometria | "Muitas tentativas. Aguarde e tente novamente" |
| Sem biometria, mas com PIN | Autentica com o PIN, sem mensagem de erro |
| Sem biometria e sem bloqueio de tela | "Configure um bloqueio de tela no aparelho para usar o app" com "Tentar novamente" |
| Campo vazio ao confirmar | "Campo obrigatório" em `danger`, borda em `danger` |
| Texto sem sugestão escolhida | "Selecione um endereço da lista" |
| Mesmo endereço em dois campos | "Endereço repetido" no segundo campo; some ao remover a duplicata |
| Partida a mais de 50 km das paradas | A rota é calculada normalmente (o bias é só uma dica) |

## Limitações conhecidas

- **Navegação em segundo plano.** Sem permissão "sempre" nem foreground service. O acompanhamento pausa quando o app sai da tela e retoma na volta.
- **iOS validado só por compilação.** O projeto compila com permissões e chave configuradas, mas não testei em aparelho iOS. A entrega é Android.
- **Ordem ótima.** Com destino fixo no ponto mais distante, a ordem pode não ser a melhor possível em todos os casos (veja a decisão acima).
- **Sem trânsito.** A rota não usa `TRAFFIC_AWARE_OPTIMAL`, que é incompatível com a otimização de waypoints e custa mais.
- **Mapa offline.** Os tiles dependem do cache do Maps SDK; o app não controla isso.
- **Detecção de conectividade.** `connectivity_plus` informa se há rede, não se a internet responde. Com rede sem internet, a requisição falha e é tratada como sem conexão.
- **Modo escuro.** O design system define só o tema claro.
- **Sem instruções passo a passo.** O app desenha a rota e mostra a posição; não há navegação por voz ou texto curva a curva.
- **Só pt-BR.** Um único idioma.
- **Sem contas, backend ou histórico de rotas.** Não foi pedido.
- **Rota salva sem criptografia.** A rota em andamento (origem, endereços, polyline) fica em texto puro nas preferências do app, fora do backup automático; não expira sozinha.

## Estrutura de commits

- Conventional Commits (`feat`, `fix`, `test`, `docs`, `ci`, `chore`...), mensagens em inglês.
- Um commit por unidade de trabalho, sempre com os testes da mudança.
- Trabalho em `develop`; `main` recebe merge por pull request.
- Código, testes e commits em inglês; interface e este README em português.
- Todos os commits são de minha autoria.
