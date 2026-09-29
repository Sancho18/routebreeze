# RouteBreeze

App Flutter de roteirização de entregas: bloqueio biométrico, endereços com autocomplete, rota otimizada e navegação em tempo real com recálculo automático.

![CI](https://github.com/Sancho18/routebreeze/actions/workflows/ci.yml/badge.svg)

## Sobre

O RouteBreeze ajuda um entregador a visitar vários endereços na melhor ordem. O fluxo tem seis passos:

1. **Bloqueio.** O app abre pedindo biometria. Se não houver biometria cadastrada, usa o PIN, padrão ou senha do aparelho.
2. **Mapa.** Enquanto a posição e o mapa carregam, um loading com a marca e uma rota animada cobre a tela. Depois o mapa centraliza na posição atual (zoom 16) com o marcador "Partida". Esse é o ponto de origem da rota.
3. **Endereços.** O entregador digita três ou mais endereços e escolhe cada um na lista de sugestões do Google Places.
4. **Rota otimizada.** Uma única chamada à Routes API devolve a melhor ordem de visita. O app desenha a rota no mapa e numera as paradas de 1 a N.
5. **Navegação.** Ao tocar em "Iniciar", a posição é acompanhada em tempo real. A câmera segue o usuário, um card no topo mostra a próxima parada com distância, tempo e horário de chegada, e cada parada é marcada como visitada ao chegar.
6. **Recálculo.** Se o entregador sai da rota, o app pede uma nova rota pelas paradas que faltam e mostra o aviso "Rota recalculada".

Feito com Flutter 3.47.5 e o design system **Rota** (tokens em `lib/core/theme/rb_tokens.dart`). Interface em português do Brasil. O projeto foi desenvolvido para a etapa técnica de um processo seletivo de desenvolvedor(a) Flutter, a partir de um enunciado e de um design system fornecidos.

## Depois da entrega

A versão entregue no processo seletivo é a tag [`v0.1.0`](https://github.com/Sancho18/routebreeze/releases/tag/v0.1.0). O que veio depois é evolução do projeto, uma branch `feature/*` por funcionalidade, com pull request para `develop`:

- **Progresso até a próxima parada** (`feature/live-progress`). Durante a navegação, um card "Próxima parada" mostra o número e o endereço da parada e quanto falta até ela ("1,2 km · 4 min · chegada às 14:32"). O painel da rota troca os totais pelo que falta até o fim ("Faltam 8,4 km · 22 min · término às 15:10"). Tudo sai da resposta da Routes API que o app já pedia, sem chamada extra. Detalhes em "Progresso até a próxima parada", nas decisões técnicas. Na mesma branch, o mapa passou a respeitar o espaço do painel e do card (antes, a posição do entregador e o logo do Google ficavam atrás do painel), e o fluxo foi validado no simulador do iOS.
- **Abrir a próxima parada no Google Maps ou no Waze** (`feature/open-in-maps`). Um botão no card da próxima parada abre "Abrir em outro app", com Google Maps e Waze. O RouteBreeze continua acompanhando a rota e, na volta, não pede o desbloqueio de novo (há uma navegação ativa). Detalhes em "Abrir em outro app", nas decisões técnicas.
- **Ícone, nome e abertura** (`feature/app-icon`). O app ganhou ícone próprio (a rota do loading, com a partida e a chegada, em branco sobre o azul `brand`), o nome "RouteBreeze" embaixo dele e uma tela de abertura na cor da tela de bloqueio. Detalhes em "Ícone e abertura", nas decisões técnicas.
- **Tema escuro** (`feature/dark-theme`). O app segue o tema do aparelho. A paleta escura estende o DS Rota sem mudar os valores do claro, todo par de texto e fundo passa de 4,5:1, e o mapa, as barras do sistema e a abertura acompanham o tema. Detalhes em "Tema escuro", nas decisões técnicas.
- **Acessibilidade** (`feature/accessibility`). Todo texto passa de 4,5:1 nos dois temas, todo controle tem área de toque de pelo menos 48 dp e um rótulo, as telas cabem com o texto do sistema em 200 % e o leitor de tela lê o card da próxima parada numa frase só. Um grupo de testes em cada tela confere isso. Detalhes em "Acessibilidade", nas decisões técnicas.

## Demonstração

Vídeo do fluxo completo, gravado no aparelho com o build de release (Samsung Galaxy A71, Android 13): [assistir no Google Drive](https://drive.google.com/file/d/18EI1BpJeX7N34w6d5pvXB7j8HmA2pIkz/view?usp=sharing).

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

iOS: `flutter build ios --no-codesign` compila com as permissões e a chave configuradas. Depois da entrega rodei o fluxo completo no simulador (iPhone 17 Pro, iOS 26.5), com as APIs do Google de verdade. No simulador, o Face ID e o GPS podem ser simulados pela linha de comando:

```bash
xcrun simctl spawn booted notifyutil -s com.apple.BiometricKit.enrollmentChanged '1'
xcrun simctl spawn booted notifyutil -p com.apple.BiometricKit.enrollmentChanged
xcrun simctl spawn booted notifyutil -p com.apple.BiometricKit_Sim.pearl.match
xcrun simctl location booted set -23.5645,-46.6527
```

As duas primeiras linhas cadastram um rosto, a terceira reconhece o rosto quando o app pede o Face ID e a última fixa a posição na Av. Paulista. `xcrun simctl location booted start --speed=25 -` lê pontos `lat,lng` da entrada padrão e percorre o caminho, o que serve para ver a navegação andando. Não testei num iPhone físico.

## Testes e qualidade

```bash
flutter analyze
flutter test
dart format --set-exit-if-changed lib test
```

São 738 testes de unidade, Cubit (`bloc_test`) e widget em `test/`, espelhando a árvore de `lib/`; `test/tool/` confere as imagens da marca e `test/platform/` os arquivos gerados de Android e iOS (ícones, nome e abertura). O teste de cada tela tem um grupo de acessibilidade: contraste, alvos de toque e texto em 200 % (veja "Acessibilidade"). Regras de domínio testam os valores exatos (50 m, 3 fixes, 30 m, 20 s, 40 m, 300 ms, 3 caracteres, 15 s). `test/app_flow_test.dart` percorre as rotas nomeadas de ponta a ponta com Cubits reais e serviços falsos (desbloqueio, ponto de partida, três endereços, rota otimizada, navegação e "Encerrar"); os `GoogleMap` padrão das telas são montados com um dublê dos canais de plataforma (`test/helpers/fake_google_map.dart`), o que permite verificar zoom, marcadores e movimentos de câmera.

### Cobertura

```bash
flutter test --coverage
python3 tool/coverage_report.py   # lê coverage/lcov.info (só stdlib)
```

O script agrega linhas por pasta, lista os arquivos abaixo de 90 % e imprime dois totais: todos os arquivos e sem os arquivos *native-only* (código que só executa num aparelho, hoje apenas `lib/main.dart`: `configureDependencies()` e `runApp()` após a checagem da chave). Sai com código 1 quando alguma pasta ou o total fica abaixo de 90 %.

| Pasta | Linhas | Cobertas | % |
| --- | ---: | ---: | ---: |
| lib/core | 428 | 428 | 100,0 % |
| lib (raiz: `app.dart`, `main.dart`) | 83 | 81 | 97,6 % |
| lib/features/addresses | 313 | 311 | 99,4 % |
| lib/features/location | 202 | 202 | 100,0 % |
| lib/features/lock | 77 | 77 | 100,0 % |
| lib/features/navigation | 551 | 547 | 99,3 % |
| lib/features/route | 472 | 470 | 99,6 % |
| **Total (todos os arquivos)** | 2126 | 2116 | 99,5 % |
| **Total (sem native-only)** | 2121 | 2113 | 99,6 % |

`test/coverage_helper_test.dart` importa todos os arquivos de `lib/` para que o `lcov.info` liste inclusive os que nenhum teste carregaria. As linhas restantes são `stringify`/`props` de objetos de valor nunca comparados por igualdade nos testes e as duas linhas nativas de `main.dart`.

Teste de integração (precisa de um aparelho ou do simulador do iOS; usa fakes para biometria, GPS e Google APIs):

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
    theme/                       RbTokens (DS Rota), RbPalette (clara e escura), RbTheme,
                                 estilo escuro do mapa e barras do sistema
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
                  presentation: RouteCubit, RouteScreen, RouteSheet, StopBadge, MapMarkers
    navigation/   data: NavigationAppLauncher (url_launcher)
                  domain: DeviationDetector, ArrivalDetector, RecalcPolicy, ProgressEstimator, NavigationApp
                  presentation: NavigationCubit, NavigationScreen, NextStopCard, OpenInAppSheet
test/            espelha lib/ (unidade, bloc_test, widget)
integration_test/ fluxo principal com fakes, roda no aparelho
tool/            set_api_key.sh, coverage_report.py, brand/ (ícone e abertura)
assets/brand/    imagens de origem do ícone e da abertura
docs/            decisions.md
```

Fluxo de telas: `/lock` → `/map` → `/addresses` → `/route` → `/navigation`. O `AppLifecycleGate` (em `app.dart`) observa o ciclo de vida: rebloqueia ao voltar do segundo plano e pausa/retoma o stream de posição durante a navegação.

Onde ficam as regras puras (todas com teste de unidade):

- `AddressFormValidator`: campo obrigatório, sugestão selecionada, endereço repetido.
- `RoutePlanner`: escolhe o destino (ponto mais distante) e monta a ordem final a partir de `optimizedIntermediateWaypointIndex`.
- `DeviationDetector`: saída da rota (50 m, 3 fixes, precisão ≤ 30 m).
- `ProgressEstimator`: distância, tempo e chegada até a próxima parada e até o fim.
- `ArrivalDetector`: chegada (40 m).
- `RecalcPolicy`: intervalo mínimo, uma requisição por vez, adiamento offline.
- `RelockPolicy`: rebloqueio após 30 s em segundo plano.
- `GeoMath` e `PolylineCodec`: distâncias e decodificação da polyline.

## Decisões técnicas

Resumo abaixo. Cada decisão está detalhada em formato ADR em [`docs/decisions.md`](docs/decisions.md).

### Routes API em vez de Directions API

A Directions API é legada. A Routes API (`computeRoutes`) aceita `optimizeWaypointOrder`, devolve `optimizedIntermediateWaypointIndex` e usa field mask, o que limita o que é cobrado. O app pede só `duration`, `distanceMeters`, `legs.polyline.encodedPolyline`, `legs.distanceMeters`, `legs.duration` e o índice otimizado. A linha da rota é a junção das polylines dos trechos (a documentação diz que a polyline da rota é essa combinação, e numa resposta real as duas têm os mesmos 115 pontos), o que também diz onde cada trecho termina. É uma requisição por cálculo, com `travelMode: DRIVE`. Com `optimizeWaypointOrder`, a chamada é cobrada na SKU Compute Routes Pro.

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

### Progresso até a próxima parada

- **Onde o entregador está.** A posição é projetada no segmento mais próximo do trecho (leg) que chega à próxima parada. Cada trecho sabe em que vértice da linha termina (`RouteLeg.endIndex`), então a projeção nunca cai num trecho que já passou ou que ainda não começou.
- **Quanto falta.** A distância e a duração que o Google deu para esse trecho são multiplicadas pela fração da linha que ainda falta nele. Os trechos seguintes entram inteiros, até a última parada não visitada. Horário de chegada = relógio do aparelho + tempo que falta.
- **Quando mede.** A cada fix com precisão ≤ 50 m (o mesmo corte do "Iniciar"), ao chegar numa parada, em "Marcar como visitado" e depois de um recálculo. Um fix pior move o marcador, mas mantém a última medida.
- **Custo.** Nenhuma chamada a mais: pedir a polyline de cada trecho no lugar da polyline da rota não muda a SKU.

A regra fica em `ProgressEstimator` (Dart puro, testado com rotas sintéticas sobre o Equador, onde as distâncias são exatas).

### Abrir em outro app

- **Links universais.** Google Maps usa o formato Maps URLs (`https://www.google.com/maps/dir/?api=1&destination=<lat,lng>&destination_place_id=<id>&travelmode=driving&dir_action=navigate`); o Waze usa `https://waze.com/ul?ll=<lat,lng>&navigate=yes`. O sistema abre o app quando ele está instalado e o site quando não está, então não precisa de esquema próprio (`comgooglemaps://`, `waze://`), nem de `LSApplicationQueriesSchemes` no iOS, nem de `<queries>` no Android.
- **Destino.** Coordenadas com seis casas decimais (sem notação exponencial) e, no Google Maps, o `placeId` da parada, para o app mostrar o lugar certo.
- **Sem checar antes.** O app chama `launchUrl` direto e trata o `false` (ou um erro da plataforma) mostrando "Não foi possível abrir o <app>." no próprio sheet, que continua aberto para tentar o outro app. É o que a documentação do `url_launcher` recomenda no lugar de `canLaunchUrl`.
- **Na volta.** Sair para o outro app pausa o stream de posição como qualquer ida ao segundo plano, e a volta retoma. Com a navegação ativa não há rebloqueio.

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

Os tokens ficam em um só arquivo (`RbColors`, `RbText`, `RbSpace`, `RbRadius`): 9 cores, 6 estilos de texto, 4 espaçamentos e 3 raios. Os widgets base (`RbPrimaryButton`, `RbTextField`, `RbBanner`, `RbStatusChip`, `RbInlineError`, `RbRouteLoader`) usam só esses valores, e `buildRbTheme` os aplica ao Material. Fonte do sistema, sem fonte embarcada. O botão primário desabilitado usa `border` com texto `ink-muted`; habilitado usa `brand` com texto branco `body-strong` no mesmo raio e altura, então nada pula de lugar. Na lista de paradas, a parada visitada troca o número por um círculo `success` com um check ("entrega concluída" é um dos usos listados para `success`; o círculo usa a variante `successStrong`, veja "Acessibilidade"), e as linhas ficam a `space-2` uma da outra, como o DS pede para linhas de lista, com um divisor de 1 px em `border` (o uso que o DS descreve para essa cor) desenhado dentro desses 8 px e alinhado ao texto do endereço.

Uma extensão que o DS não lista: o botão "Encerrar" da navegação usa `danger` como fundo (na variante `dangerStrong`), com texto branco, e fica abaixo de "Marcar como visitado" (em `brand`). O DS reserva `danger` para erros, falha de autenticação, permissão negada e sem internet; usei a mesma cor para a única ação destrutiva do app porque ela interrompe a navegação em andamento e a cor evita o toque por engano ao lado do botão que o motorista usa o tempo todo. É a mesma paleta, o mesmo `radius-lg` e a mesma altura do botão primário, então o componente é o `RbPrimaryButton` com a cor trocada. A rota é desenhada em `brand` com 5 px, os marcadores numerados são desenhados em canvas e o marcador de partida é um pino distinto. Testes de widget conferem esses valores.

### Tema escuro

O app segue o tema do aparelho (`ThemeMode.system`). As cores ficam em `RbPalette`, uma `ThemeExtension` com duas instâncias: a clara usa os valores do DS sem mudança, e a escura é uma extensão escolhida por contraste. Todo par de texto e fundo que o app desenha no escuro passa de 4,5:1, e um teste confere cada par. Os widgets leem a paleta ativa com `context.rb`; `RbColors` só aparece em `lib/core/theme/`, e um teste falha se outro arquivo de `lib/` usar `RbColors` ou uma constante de `Colors` (branco e transparente são as exceções, usadas nos marcadores).

| Token | Claro (DS) | Escuro |
| --- | --- | --- |
| `brand` | #2A6DF4 | #7EA6F8 |
| `onFill` (texto e ícones sobre `brand`, `success` e `danger`) | #FFFFFF | #0F1115 |
| `success` | #12B76A | #12B76A |
| `warning` | #F59E0B | #F59E0B |
| `danger` | #E5484D | #EB7074 |
| `surface-100` | #F7F8FA | #0F1115 |
| `surface-200` | #FFFFFF | #1A1D23 |
| `ink` | #12141A | #F2F4F7 |
| `ink-muted` | #5B6472 | #A4ACB9 |
| `border` | #E2E5EA | #2F343D |

- **Botões no escuro.** Azul mais claro com texto escuro. O azul do DS como texto sobre o fundo escuro ficaria em 3,7:1; com `onFill`, cada tema tem um valor por papel.
- **Mapa.** No escuro, um estilo JSON com as cores da paleta (terreno #1A1D23, ruas #2F343D, água #0F1115, rótulos #A4ACB9); no claro, o estilo padrão do Google. A linha da rota usa o `brand` do tema. Os marcadores numerados e o pino de partida são iguais nos dois temas, porque o anel branco os destaca nos dois mapas.
- **Sistema.** Ícones escuros na barra de status e de navegação no tema claro e claros no escuro. A abertura nativa já usa #1A1D23 no escuro (veja "Ícone e abertura").
- **Troca com o app aberto.** A tela atual repinta sem perder o estado, e o mapa troca de estilo sem recriar a câmera.

### Acessibilidade

Três metas, conferidas por testes de widget em cada tela: todo texto legível nos dois temas, todo controle com área de toque e rótulo, e telas que cabem com o texto do sistema em 200 %.

**Cores.** No tema claro, quatro cores do DS ficam abaixo de 4,5:1 como texto: o `warning` no fundo do chip (2,0:1), o `success` (2,6:1), o `danger` (3,9:1, e o branco sobre ele também) e o `brand` sobre `surface-100` (4,3:1). Em vez de mudar o DS, a paleta ganhou variantes fortes. Elas valem para texto na cor e para fundos com texto ou ícone por cima; as cores base continuam nas bordas, nos fundos a 12 %, nos marcadores e na rota. No escuro, as variantes repetem os tons da paleta escura, que já passam de 4,5:1.

| Papel | Claro | Escuro | Onde |
| --- | --- | --- | --- |
| `successStrong` | #0D7F4A | #12B76A | "Rota concluída" e o círculo da parada visitada |
| `warningStrong` | #996206 | #F59E0B | chips "Rota recalculada" e "Recálculo pendente (sem conexão)" |
| `dangerStrong` | #D01E23 | #EB7074 | mensagens de erro, chip "Falha ao recalcular", banner "Sem conexão" e "Encerrar" |
| `brandStrong` | #1B63F3 | #7EA6F8 | botões de texto: "Adicionar ponto", "Tentar novamente", "Nova rota", "Continuar" e "Recentralizar" |

No claro, `successStrong` dá 5,1:1 sobre branco, `warningStrong` 4,7:1 sobre o fundo do chip, `dangerStrong` 5,4:1 com o branco nos dois sentidos e `brandStrong` 4,8:1 sobre `surface-100`. Ícones e o botão primário continuam em `brand`.

**Toque.** Todo controle tem área de toque de pelo menos 48×48 dp no Android e 44×44 pt no iOS, e um rótulo para o leitor de tela. O botão "Abrir em outro app" do card da próxima parada passou de 44 para 48 dp.

**Texto em 200 %.** Num aparelho de 360×800 dp com o texto do sistema em 200 %, nenhuma tela transborda e nenhum texto fica cortado. A única exceção é texto com limite de linhas que termina em reticências, como o endereço do card da próxima parada (até 2 linhas). Para caber:

- o botão primário tem 52 dp como altura mínima e cresce quando o rótulo quebra linha; carregando, o rótulo fica no lugar, invisível sob o spinner, e a altura não muda;
- o círculo com o número da parada cresce com o texto (48 dp em 200 %);
- o nome "RouteBreeze" na tela de bloqueio diminui até caber numa linha, em vez de quebrar no meio da palavra;
- a tela de bloqueio, o card de status do mapa e o sheet "Abrir em outro app" rolam quando o conteúdo não cabe;
- na navegação, o painel de baixo ocupa só o espaço abaixo do card e dos avisos e rola a partir das ações, em vez de cobrir o card.

**Leitor de tela.** O card da próxima parada é lido numa frase só: "Próxima parada 2: Rua Augusta, 500. 1,2 km, 4 min, chegada às 14:32" (antes da primeira medida, a frase termina no endereço). O botão "Abrir em outro app" continua como um item separado. O número da parada é lido como "Parada 2" ou "Parada 2, visitada". Os chips de status, o banner "Sem conexão" e "Perdemos o sinal de GPS" são regiões ao vivo: o leitor anuncia quando aparecem, sem mover o foco.

**Como os testes conferem.** O teste de cada tela (bloqueio, mapa, endereços, rota e navegação) tem um grupo de acessibilidade que usa `test/helpers/accessibility.dart`:

- `expectAccessibleGuidelines` roda as diretrizes do Flutter (`textContrastGuideline`, `androidTapTargetGuideline`, `iOSTapTargetGuideline` e `labeledTapTargetGuideline`) nos dois temas, em cada estado com texto próprio: erros, chips, banner, o diálogo "Continuar rota?" e o sheet "Abrir em outro app";
- `setLargeTextPhone` monta a tela em 360×800 dp com o texto em 200 %; ali o teste falha em qualquer erro de overflow e em `expectNoClippedText`, que acusa um parágrafo menor que o próprio texto: mais baixo, no corte que um pai de altura fixa faz sem erro nenhum, ou mais estreito, numa linha que não quebra e passa da borda.

Os testes da paleta conferem cada par de contraste das variantes fortes, e os de semântica leem o rótulo do card, os das paradas e as regiões ao vivo.

### Generalização para N endereços

"Adicionar ponto" cria campos sem limite ("Ponto D", "Ponto E"...), cada um com controle de remoção. Todo campo presente precisa de uma sugestão selecionada; editar depois de escolher invalida o campo; dois campos com o mesmo `placeId` recebem "Endereço repetido". A rota usa todas as paradas em uma única requisição e os marcadores vão de 1 a N.

### Câmera do mapa

Zoom 16 na partida. Na tela de rota a câmera enquadra a rota inteira. Na navegação ela segue o usuário; arrastar o mapa solta a câmera e mostra "Recentralizar", que volta a seguir.

O painel da rota e o card da próxima parada ficam por cima do mapa. As alturas deles são medidas depois do layout e passadas ao `GoogleMap` como `padding`, então a rota enquadrada e a posição seguida ficam na parte visível, e o logo do Google não some atrás do painel. Chips temporários ("Rota recalculada") e o "Recentralizar" ficam de fora da medida para não deslocar o mapa quando aparecem.

### Ícone e abertura

O ícone é a mesma curva do loading da tela de mapa (`RouteLoaderPainter.route`), com um anel na partida e um ponto na chegada, em branco sobre o `brand`. `tool/brand/brand_mark.dart` desenha a marca e `tool/brand/render_brand_assets_test.dart` grava as imagens de origem em `assets/brand/`. Os arquivos de cada plataforma saem de dois geradores, que são dependências só de desenvolvimento:

```bash
flutter test tool/brand/render_brand_assets_test.dart
dart run flutter_launcher_icons
dart run flutter_native_splash:create
git checkout ios/Runner.xcodeproj/project.pbxproj
```

O último comando desfaz uma linha que o `flutter_launcher_icons` 0.14.4 troca no projeto do Xcode (`ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS` vira `AppIcon`, um valor inválido). Com ele, regenerar não muda nenhum arquivo versionado.

- **Android.** Ícone adaptativo (fundo `brand`, a marca como primeiro plano dentro da zona segura de 66 dp), camada monocromática para os ícones temáticos do Android 13+ e PNGs de 48 a 192 px para o Android 7 (minSdk 24).
- **iOS.** Todos os tamanhos do catálogo, sem canal alfa.
- **Nome.** "RouteBreeze" no Android e no iOS.
- **Abertura.** O círculo do ícone no centro, sobre a cor da tela de bloqueio (`surface-200`): #FFFFFF no modo claro e #1A1D23 no escuro. No Android 12+, a abertura do sistema mostra a marca sobre o círculo azul.

`test/tool/` confere as imagens (tamanhos, cores e a zona segura) e `test/platform/` os arquivos gerados (XML do ícone adaptativo, PNGs sem alfa no iOS, nome e cores da abertura).

## Tratamento de erros e casos extremos

| Cenário | Comportamento |
| ------- | ------------- |
| Permissão de localização negada | Card com "Precisamos da sua localização para seguir. Ela define o ponto de partida da sua rota." e o botão "Permitir localização", que pede de novo |
| Permissão negada permanentemente | Mesmo texto mais "Você negou o acesso. Ative em Configurações." e o botão "Abrir configurações" |
| GPS do aparelho desligado | "Ative a localização do dispositivo para continuar." com "Ativar localização" |
| GPS impreciso no mapa inicial (sem fix ≤ 50 m em 15 s) | "Não conseguimos uma posição precisa. Verifique se está em local aberto." com "Tentar novamente"; "Para onde vamos?" fica desabilitado |
| GPS impreciso antes de iniciar a navegação | "Aguardando sinal de GPS" e "Iniciar" desabilitado até um fix ≤ 50 m |
| Erro no stream de posição | "Perdemos o sinal de GPS" em `dangerStrong`; a última posição é mantida |
| Fixes ruins durante a navegação (precisão > 30 m) | Ignorados na detecção de desvio; não disparam recálculo |
| Sem internet em Endereços | Banner "Sem conexão"; "Confirmar rota" desabilitado; autocomplete suspenso; texto mantido |
| Sem internet na Rota | O cálculo falha (uma nova tentativa automática após 2 s) e mostra "Não foi possível calcular a rota." com "Tentar novamente" |
| Sem internet na Navegação | Banner "Sem conexão"; acompanhamento e chegada continuam; recálculo pendente até a conexão voltar |
| Falha do Autocomplete ou do Place Details | "Não foi possível buscar endereços. Tente novamente." sob o campo; texto mantido |
| Falha da Routes API (erro HTTP, sem rota, legs a menos) | "Não foi possível calcular a rota." com "Tentar novamente"; voltar mantém o formulário preenchido |
| Falha no recálculo | Rota anterior mantida; aviso "Falha ao recalcular" por 4 s; nova tentativa após 20 s |
| Mapa demora a ser criado | O loading com a marca segue até o `GoogleMap` avisar que foi criado (mais 400 ms para os primeiros tiles); se o aviso nunca vier, some sozinho após 5 s |
| Chave de API ausente | O app falha ao abrir com uma mensagem que cita `env.json` |
| Biometria cancelada | "Autenticação cancelada"; "Desbloquear" continua disponível |
| Muitas tentativas de biometria | "Muitas tentativas. Aguarde e tente novamente" |
| Sem biometria, mas com PIN | Autentica com o PIN, sem mensagem de erro |
| Sem biometria e sem bloqueio de tela | "Configure um bloqueio de tela no aparelho para usar o app" com "Tentar novamente" |
| Campo vazio ao confirmar | "Campo obrigatório" em `dangerStrong`, borda em `danger` |
| Texto sem sugestão escolhida | "Selecione um endereço da lista" |
| Mesmo endereço em dois campos | "Endereço repetido" no segundo campo; some ao remover a duplicata |
| Partida a mais de 50 km das paradas | A rota é calculada normalmente (o bias é só uma dica) |
| Fix pior que 50 m durante a navegação | O marcador se move, mas a distância e o horário de chegada ficam na última medida boa |
| Google Maps ou Waze não abre (sem app e sem navegador) | "Não foi possível abrir o <app>." em `dangerStrong` no sheet, que continua aberto para tentar o outro |
| Rota salva pela versão 0.1.0 (sem o fim de cada trecho) | A navegação segue normal; o card mostra a próxima parada sem distância e tempo, e o painel mostra os totais |

## Limitações conhecidas

- **Navegação em segundo plano.** Sem permissão "sempre" nem foreground service. O acompanhamento pausa quando o app sai da tela e retoma na volta.
- **iOS só no simulador.** O fluxo completo roda no simulador do iOS (veja "Build"), mas não testei num iPhone físico. A entrega é Android.
- **Ordem ótima.** Com destino fixo no ponto mais distante, a ordem pode não ser a melhor possível em todos os casos (veja a decisão acima).
- **Sem trânsito.** A rota não usa `TRAFFIC_AWARE_OPTIMAL`, que é incompatível com a otimização de waypoints e custa mais.
- **Mapa offline.** Os tiles dependem do cache do Maps SDK; o app não controla isso.
- **Detecção de conectividade.** `connectivity_plus` informa se há rede, não se a internet responde. Com rede sem internet, a requisição falha e é tratada como sem conexão.
- **Sem instruções passo a passo.** O app desenha a rota e mostra a posição; não há navegação por voz ou texto curva a curva. Para isso, o botão "Abrir em outro app" passa a próxima parada ao Google Maps ou ao Waze.
- **Só pt-BR.** Um único idioma.
- **Acessibilidade.** As bordas de campos e cards seguem o DS (1,3:1 contra o fundo); os campos se distinguem pelo preenchimento, pelo texto de exemplo e pela mensagem. Os marcadores do mapa ficam com a acessibilidade do SDK, e o loader animado não segue a opção de reduzir movimento.
- **Sem contas, backend ou histórico de rotas.** Não foi pedido.
- **Estimativa de chegada simples.** O tempo que falta num trecho é proporcional à distância que falta nele, sem trânsito e sem contar o tempo parado nas entregas (o horário se ajusta a cada fix, porque parte do relógio atual). Numa rua de ida e volta dentro do mesmo trecho, a projeção pode pegar o lado errado por alguns instantes.
- **Rota salva sem criptografia.** A rota em andamento (origem, endereços, polyline) fica em texto puro nas preferências do app, fora do backup automático; não expira sozinha.

## Estrutura de commits

- Conventional Commits (`feat`, `fix`, `test`, `docs`, `ci`, `chore`...), mensagens em inglês.
- Um commit por unidade de trabalho, sempre com os testes da mudança.
- Trabalho em `develop`; `main` recebe merge por pull request.
- Código, testes e commits em inglês; interface e este README em português.
- Todos os commits são de minha autoria.
