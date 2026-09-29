# Decisões técnicas

Registro das decisões do RouteBreeze no formato Contexto / Decisão / Consequências. O README traz o resumo; aqui fica o raciocínio.

## D-001: Arquitetura feature-first com Cubit e get_it

**Contexto.** O app tem cinco telas com regras mensuráveis (limiares em metros e segundos) que precisam de teste de unidade sem Flutter. Os avaliadores olham arquitetura e testes.

**Decisão.** Feature-first: `core/` compartilhado e `features/<nome>/{data,domain,presentation}`. Estado com `flutter_bloc` (Cubit, um por tela). Injeção com `get_it`, montada em `lib/core/di/injector.dart`. As regras (validador, detectores, política de recálculo, planejador) são classes Dart puras no `domain`.

**Consequências.** Regras testáveis com os valores exatos da especificação. Cubits finos, que só orquestram streams e serviços. Mais boilerplate do que Riverpod e registro manual de dependências. Telas aceitam Cubit e serviços por parâmetro, o que simplifica os testes de widget.

## D-002: Routes API e Places API (New) por REST

**Contexto.** O teste pede autocomplete de endereços, rota otimizada e uso eficiente das APIs do Google. Directions API e Places API legadas ainda existem, mas são as versões antigas.

**Decisão.** `google_maps_flutter` para o mapa. Places API (New) e Routes API (`computeRoutes` com `optimizeWaypointOrder`) chamadas por REST com `dio`. Nada de Directions API nem Places legada, nem SDK nativo de Places.

**Consequências.** Field masks e session tokens mantêm o custo baixo. O código HTTP é testável com adapter falso. A interface do autocomplete é própria (não há widget nativo). Uma requisição por cálculo de rota.

## D-003: Chave de API única, fora do Git

**Contexto.** O repositório será lido por avaliadores, que podem compilar com a própria chave ou com uma chave enviada em separado. O segredo não pode ficar no Git.

**Decisão.** Uma chave restrita às quatro APIs usadas (Maps SDK Android, Maps SDK iOS, Places (New), Routes) com cotas diárias. Carregada de `env.json` (gitignored) por `--dart-define-from-file`, injetada no manifest Android por um placeholder que o Gradle lê do mesmo arquivo e no iOS por `Secrets.xcconfig` (gitignored). `env.example.json` fica versionado e `tool/set_api_key.sh` escreve os dois arquivos.

**Consequências.** Qualquer máquina compila com a própria chave. Sem segredo no histórico. A chave não tem restrição por app (SHA-1/bundle), então as cotas limitam o risco. Em produção: chave por plataforma com restrição de app para os SDKs e um backend na frente de Places e Routes.

## D-004: Destino fixo no ponto mais distante da origem

**Contexto.** A Routes API otimiza só os pontos intermediários; origem e destino são fixos. O app precisa de uma ordem de visita para N paradas com uma única requisição.

**Decisão.** A parada não visitada mais distante da origem (linha reta, haversine) vira o destino. As demais viram intermediários com `optimizeWaypointOrder: true`. A ordem final é `optimizedIntermediateWaypointIndex` seguida do destino. O recálculo aplica a mesma regra às paradas que faltam.

**Consequências.** Uma requisição por cálculo. Resultado bom para rotas de entrega, em que o ponto mais distante costuma ser o fim natural. A ordem pode não ser a ótima global. A alternativa exata (N requisições, uma por destino candidato, ficando com a mais curta) custa N vezes mais e ficou de fora.

## D-005: Autocomplete com session tokens e field mask enxuta

**Contexto.** O autocomplete é cobrado por sessão quando fechado com um Place Details que usa o mesmo token. Sem isso, cada tecla vira uma cobrança.

**Decisão.** Mínimo de 3 caracteres, debounce de 300 ms, no máximo 5 sugestões, bias circular de 50 km ao redor da partida, região BR, idioma pt-BR. Um session token por campo. Place Details com o mesmo token e a field mask `id,formattedAddress,location` (SKU Essentials). Depois da seleção, token novo para o campo.

**Consequências.** Um Place Details por endereço escolhido. Chamadas de autocomplete só depois do debounce. O bias é uma dica: endereços fora dos 50 km continuam válidos.

## D-006: Limiares de desvio, chegada e recálculo

**Contexto.** O GPS urbano oscila. Recalcular a cada fix ruim gastaria API e confundiria o usuário.

**Decisão.**
- Fora da rota: 3 fixes consecutivos a mais de 50 m da polyline, contando só fixes com precisão ≤ 30 m; fix repetido conta uma vez.
- Recálculo: mínimo de 20 s entre dois; um em andamento por vez; só paradas não visitadas.
- Chegada: 40 m da próxima parada, mais o botão "Marcar como visitado"; superado depois da entrega por D-019 (a chegada só informa, e o entregador registra o resultado).
- Início da navegação e partida: último fix com precisão ≤ 50 m (partida em até 15 s).
- Distância ponto-segmento em projeção equiretangular: erro abaixo de 1% na escala da cidade e barata por fix.

**Consequências.** Filtra ruído, evita tempestade de recálculos e mantém uma requisição por evento real de desvio. Os valores ficam em construtores com defaults e são testados um a um.

## D-007: Offline com rota persistida e recálculo adiado

**Contexto.** "Sem internet" é critério de avaliação. A rota já está no aparelho depois de calculada; só o recálculo precisa de rede.

**Decisão.** `connectivity_plus` alimenta um banner "Sem conexão" e desabilita ações de rede (confirmar rota, autocomplete). A rota ativa é salva em `shared_preferences` (um JSON) ao ser calculada e a cada parada visitada; apagada ao concluir ou ao iniciar uma rota nova. No cold start com rota salva, o app oferece "Continuar rota?". Offline na navegação, acompanhamento e chegada continuam; o recálculo fica pendente e roda ao reconectar. Requisições têm timeout de 10 s e uma nova tentativa após 2 s em erro de conexão.

**Consequências.** Uma queda de sinal não perde a rota. `connectivity_plus` informa estado do link, não alcance da internet: a requisição que falhar é mapeada para "sem conexão" do mesmo jeito.

## D-008: Bateria e GPS

**Contexto.** Otimização de bateria é diferencial do teste. Localização em segundo plano exige permissão "sempre" e foreground service.

**Decisão.** Stream de posição só durante a navegação, com precisão máxima e `distanceFilter` de 5 m. Pausa em segundo plano, retoma na volta, encerra em "Encerrar" ou ao concluir. Partida com um único fix. Sem localização em segundo plano; superado durante a navegação depois da entrega por D-022 (de "Iniciar" até o fim, o acompanhamento continua em segundo plano, e o stream só pausa antes de "Iniciar").

**Consequências.** Parado, não há eventos nem processamento. Nada de setup nativo extra. O acompanhamento pausa fora da tela (limitação documentada); superado durante a navegação por D-022.

## D-009: Bloqueio com fallback para PIN e rebloqueio após 30 s

**Contexto.** O app deve exigir biometria e tratar aparelhos sem biometria cadastrada ou sem bloqueio de tela.

**Decisão.** `local_auth` com `biometricOnly: false`. Prompt no primeiro frame. Rebloqueio ao voltar do segundo plano após 30 s ou mais, exceto com navegação ativa. Sem credencial nenhuma, o app fica bloqueado com instrução para configurar o bloqueio de tela.

**Consequências.** Trocas rápidas de app não interrompem; a rota em andamento nunca é bloqueada. O caso sem credencial é tratado, não contornado.

## D-010: Design system Rota como tokens em código

**Contexto.** A aderência ao design system é critério de avaliação.

**Decisão.** Tokens (9 cores, 6 estilos de texto, 4 espaçamentos, 3 raios) em `lib/core/theme/rb_tokens.dart`. Widgets base usam só tokens; `buildRbTheme` aplica ao Material. Fonte do sistema. Botão primário com a mesma altura e raio nos estados habilitado/desabilitado. Marcadores numerados desenhados em canvas com `dart:ui`, cacheados por número.

**Consequências.** Nenhum valor solto nas telas. Testes de widget conferem cores e estilos. Sem tema escuro (o design system define só o claro); superado depois da entrega por D-017.

## D-011: Generalização para N endereços

**Contexto.** O teste pede três endereços; usar mais é um diferencial.

**Decisão.** "Adicionar ponto" sem limite, com remoção nos campos além dos três primeiros. Validação: todo campo presente precisa de sugestão selecionada; editar invalida; `placeId` repetido é erro. Uma requisição com todas as paradas; marcadores 1..N.

**Consequências.** O mesmo código serve para 3 ou 30 paradas. O limite prático é o da Routes API (25 intermediários).

## D-012: Ferramentas de apoio

**Contexto.** Cobrança, cache de mapa e outras escolhas menores.

**Decisão.**
- `dio` pelo interceptor de chave e retry, timeouts e erros tipados.
- `PolylineCodec` próprio (30 linhas, testado) em vez de dependência.
- `equatable` nos estados para `bloc_test` barato.
- Navegação como tela própria (`NavigationScreen`), que delimita o ciclo de vida do `NavigationCubit`.
- Cubit em vez de Bloc: não há eventos externos além dos streams que o próprio Cubit possui.

**Consequências.** Poucas dependências, todas comuns no ecossistema. Código legível para quem avalia.

## D-013: Progresso até a próxima parada

**Contexto.** Depois da entrega (v0.1.0). Na navegação, o painel mostrava só os totais calculados no início, que não mudavam enquanto o entregador andava. Quem dirige quer saber quanto falta até a próxima entrega e a que horas chega.

**Decisão.**
- A Routes API devolve a polyline de cada trecho (`routes.legs.polyline.encodedPolyline`) no lugar da polyline da rota. A documentação diz que a polyline da rota é a combinação das dos trechos; numa resposta real, juntá-las com o vértice compartilhado uma vez só deu os mesmos 115 pontos. Cada trecho guarda o índice do vértice em que termina (`RouteLeg.endIndex`), e um trecho de distância zero (duas paradas no mesmo lugar) vem com um ponto só.
- `ProgressEstimator` (Dart puro) projeta a posição no segmento mais próximo do trecho que chega à próxima parada e escala a distância e a duração que o Google deu para esse trecho pela fração da linha que falta. Os trechos seguintes entram inteiros, até a última parada não visitada. Os trechos pertencem às últimas `legs.length` paradas: um recálculo mantém as visitadas na frente, sem trecho.
- O `NavigationCubit` mede o progresso a cada fix com precisão ≤ 50 m (o corte do "Iniciar"), ao chegar numa parada, em "Marcar como visitado" e depois de um recálculo. Um fix pior move o marcador e mantém a última medida. O horário de chegada é o relógio do aparelho mais o tempo que falta.
- Um card "Próxima parada" no topo do mapa (tokens do DS para card de endereço: `surface-200`, borda `border`, `radius-md`, legenda e distância em `caption`) e a linha de totais do painel trocada por "Faltam … · término às …".

**Consequências.** Nenhuma chamada a mais: sai da resposta que o app já pedia, e pedir as polylines dos trechos não muda a SKU (com `optimizeWaypointOrder` a chamada já é Compute Routes Pro). A estimativa herda os limites da rota: sem trânsito, e o tempo de um trecho é proporcional à distância que falta nele. Numa rua de ida e volta dentro do mesmo trecho, a projeção pode pegar o lado errado por alguns instantes. Rotas salvas pela 0.1.0 não têm o fim de cada trecho: a navegação segue normal, sem o progresso.

## D-014: Mapa com padding das sobreposições

**Contexto.** O painel da rota (e agora o card da próxima parada) fica por cima do `GoogleMap`, que ocupa a tela inteira. A câmera centralizava a posição no mapa inteiro, então o marcador do entregador e o logo do Google ficavam atrás do painel; na tela de rota, parte da rota enquadrada também.

**Decisão.** Medir depois do layout a altura das sobreposições fixas (`MeasureSize`, um `RenderProxyBox` que avisa quando o tamanho do filho muda) e passar ao `GoogleMap` como `padding`. Na navegação entram o banner offline e o card (em cima) e o painel (embaixo); ficam de fora os chips temporários e o "Recentralizar", para o mapa não pular quando eles aparecem. Na tela de rota entra o painel.

**Consequências.** A câmera segue e enquadra dentro da área visível, e o logo do Google fica visível, como os termos do Maps pedem. A medida chega um frame depois do layout; até lá o padding é zero, o que não aparece porque o mapa ainda está sendo criado.

## D-015: Abrir a próxima parada em outro app

**Contexto.** Depois da entrega. O RouteBreeze desenha a rota e acompanha a posição, mas não dá instruções curva a curva (limitação conhecida). Quem dirige costuma querer a voz do Google Maps ou do Waze até a próxima entrega.

**Decisão.** Um botão no card da próxima parada abre um bottom sheet com Google Maps e Waze. O `NavigationApp` monta links universais: Maps URLs (`/maps/dir/?api=1` com as coordenadas, o `placeId`, `travelmode=driving` e `dir_action=navigate`) e `waze.com/ul` (`ll` e `navigate=yes`). O `NavigationAppLauncher` abre o link com `url_launcher` em `LaunchMode.externalApplication` e devolve `false` quando nada abre (ou a plataforma falha). O sheet fecha quando um app abre; na falha, fica aberto com o motivo.

**Consequências.** Nenhuma configuração nativa: sem esquemas `comgooglemaps://` e `waze://`, sem `LSApplicationQueriesSchemes` nem `<queries>`, porque o link universal abre o app instalado ou o site. Não dá para saber de antemão se o app está instalado; a opção aparece sempre e, sem o app, o site abre (validado no simulador do iOS, que não tem nenhum dos dois). O outro app recebe só a próxima parada, não a rota inteira: o RouteBreeze continua dono da ordem, e o entregador volta a ele a cada entrega.

## D-016: Ícone e abertura a partir da marca do loading

**Contexto.** Depois da entrega. O APK instalado mostrava o ícone padrão do Flutter, que o Android 12+ repete na abertura, e o nome "routebreeze" (no iOS, "Routebreeze"). É a primeira coisa que quem avalia vê.

**Decisão.** A marca é a curva do loading da tela de mapa (`RouteLoaderPainter.route`) com um anel na partida e um ponto na chegada, em branco sobre `brand`. Um script de teste do Flutter (`tool/brand/render_brand_assets_test.dart`) desenha as imagens de origem com esse `Path`, e o `flutter_launcher_icons` e o `flutter_native_splash`, como dependências de desenvolvimento, geram os arquivos de cada plataforma, que ficam no repositório. No Android, o ícone é adaptativo, com camada monocromática e PNGs para o Android 7. A abertura usa a cor da tela de bloqueio (`surface-200`), clara ou escura, para não piscar na troca. O nome passa a ser "RouteBreeze" nas duas plataformas.

**Consequências.** A marca e o loading não divergem: mudar a curva muda os dois. Os arquivos gerados passam por testes (tamanhos, alfa no iOS, cores e a zona segura do ícone adaptativo). Não há dependência nova em tempo de execução. O `flutter_launcher_icons` altera uma linha do `project.pbxproj` que não entra no repositório (o README traz o comando que a desfaz).

## D-017: Tema escuro como extensão do DS Rota

**Contexto.** Depois da entrega. O DS Rota define só o tema claro, e o app mostrava telas e mapa brancos com o aparelho no modo escuro. Os widgets liam as cores direto de `RbColors`, então não bastava ligar um `darkTheme`.

**Decisão.** As cores passam a ser papéis de uma `ThemeExtension` (`RbPalette`) com duas instâncias: a clara com os valores do DS e a escura como extensão, com um papel novo, `onFill`, para texto e ícones sobre `brand`, `success` e `danger`. Os valores escuros foram escolhidos por contraste: todo par de texto e fundo do app passa de 4,5:1. No escuro, os botões usam um azul mais claro (#7EA6F8) com texto escuro, porque o azul do DS como texto sobre o fundo escuro fica em 3,7:1. O app segue o aparelho (`ThemeMode.system`), os widgets leem `context.rb`, e `RbColors` fica restrito a `lib/core/theme/`, com um teste que falha se outro arquivo usar cor fixa. O mapa usa no escuro um estilo JSON com as cores da paleta, e a linha da rota segue o `brand` do tema. Os marcadores ficam iguais nos dois temas, e as barras do sistema acompanham o brilho.

**Consequências.** O modo claro não muda. O contraste do escuro é garantido por teste, e cores fixas novas quebram o build de testes. Menos widgets são `const`. A troca de tema anima por 200 ms, e durante a animação a linha da rota recebe algumas atualizações de cor antes de chegar à final.

## D-018: Acessibilidade com variantes fortes e testes por tela

**Contexto.** Depois da entrega. No tema claro, quatro cores do DS ficavam abaixo de 4,5:1 como texto: o `warning` no fundo do chip (2,0:1), o `success` (2,6:1), o `danger` e o branco sobre ele (3,9:1) e o `brand` sobre `surface-100` (4,3:1). O botão que abre a próxima parada em outro app tinha 44 dp, abaixo dos 48 dp do Android. O leitor de tela lia o card da próxima parada em pedaços e não anunciava as mudanças de status. Nada conferia as telas com o texto do sistema grande: em 200 %, o botão primário de 52 dp cortava um rótulo de duas linhas sem erro de overflow.

**Decisão.** Em vez de escurecer as cores do DS, a paleta ganha quatro variantes fortes: `successStrong` #0D7F4A, `warningStrong` #996206, `dangerStrong` #D01E23 e `brandStrong` #1B63F3 no claro; no escuro, elas repetem os tons da paleta escura. Elas valem só para texto na cor e para fundos com texto ou ícone por cima. As cores base continuam nas bordas, nos fundos a 12 %, nos marcadores, na rota, nos ícones e no botão primário. O teste de cada tela ganha um grupo de acessibilidade: as quatro diretrizes do Flutter (contraste de texto, alvos de toque do Android e do iOS, alvos com rótulo) nos dois temas e em cada estado com texto próprio, e o layout em 360×800 dp com texto em 200 %. Nesse layout, o teste falha em erro de overflow e em texto cortado: `expectNoClippedText` acusa um parágrafo mais baixo ou mais estreito que o próprio texto, salvo um texto com limite de linhas que termina em reticências. O botão primário passa a ter 52 dp como altura mínima e cresce com o rótulo, com a mesma altura enquanto carrega. O nome do app na tela de bloqueio diminui até caber numa linha, em vez de quebrar no meio da palavra. O card da próxima parada vira um nó de semântica com uma frase só, e os avisos de status viram regiões ao vivo.

**Consequências.** O visual muda pouco: os tons fortes aparecem no texto e em três fundos ("Sem conexão", "Encerrar" e a parada visitada). Contraste, alvos e texto grande viram regressões que quebram os testes. As auditorias trouxeram ajustes de layout: o número da parada cresce com o texto; a tela de bloqueio, o card de status do mapa e o sheet "Abrir em outro app" rolam quando não cabem; e o painel da navegação deixa de cobrir o card da próxima parada. Ficam de fora o contraste das bordas (1,3:1, como o DS define), a leitura dos marcadores do mapa, que fica com o SDK, e o movimento reduzido no loader. Os testes usam a fonte de teste do Flutter, mais larga que a do aparelho, então veem mais quebras de linha do que o aparelho.

## D-019: Resultado da entrega na parada e resumo da rota

**Contexto.** Depois da entrega. Uma parada estava visitada ou não, e chegar a 40 m dela a marcava sozinha, mesmo sem entrega. Numa entrega real, algumas tentativas falham (ninguém em casa, endereço não encontrado, recusa), e o entregador precisa registrar o motivo. A rota terminava num "Rota concluída" que não dizia nada do trabalho feito.

**Decisão.**
- O resultado fica na parada: `RouteStop.result` (`StopResult`: entregue, ou não entregue com um de quatro motivos, e o horário). `visited` vira derivado (`result != null`), então há uma fonte só. O JSON salvo continua com `visited`, e uma parada salva antes, com `visited: true` e sem resultado, é lida como entregue.
- "Entregue" (primário) e "Não entregue" (contorno em `brand`, porque o DS não tem botão secundário) substituem "Marcar como visitado" e funcionam a qualquer momento da navegação. "Não entregue" pede o motivo; fechar sem escolher não registra nada. Um toque a menos de 1 s do resultado anterior é ignorado, porque cada toque registra a próxima parada e um toque duplo registraria duas. Um resultado não muda depois de registrado.
- A chegada vira estado (`NavigationState.arrived`), não escrita: um fix com precisão ≤ 50 m a até 40 m da próxima parada mostra "Você chegou", e a parada só avança com um resultado. Com o entregador na parada, nenhum fix passa pela detecção de desvio, porque ele pode sair da rua para entregar. Uma resposta de recálculo que muda a próxima parada desfaz a chegada. A chegada descarta um recálculo adiado offline, com o aviso, porque o desvio que ele respondia acabou. Depois do resultado, a detecção de desvio recomeça do zero.
- A distância percorrida fica num `Odometer` dentro do `NavigationCubit`: a soma dos segmentos em linha reta entre fixes consecutivos com precisão ≤ 30 m (o corte do desvio), só durante a navegação. O início é o primeiro "Iniciar" da rota. Os dois vão para a rota salva a cada resultado, em "Encerrar" e quando o app vai para o segundo plano, nunca a cada fix: o plano mudaria a cada fix, e o cache dos ícones do mapa depende da igualdade do plano.
- O último resultado conclui a rota. O Cubit monta o `RouteSummary` (contagens, paradas não entregues em ordem, distância, início e fim no último resultado) e apaga a rota salva, e a tela troca o painel pelo resumo.
- A navegação continua ativa (`SessionState.isNavigationActive`) até a tela de navegação fechar, também depois de concluída. Voltar do segundo plano após 30 s com o resumo na tela não rebloqueia: o rebloqueio limpa a pilha de telas, e o resumo se perderia, porque a rota salva já foi apagada.
- Sair da navegação não perde o progresso. "Encerrar" espera a rota ser salva e só então volta para a tela Rota, que relê a rota salva quando ela tem as mesmas paradas; o "Iniciar" seguinte continua com os resultados, o início e a distância. O voltar do sistema usa as saídas da própria tela: "Encerrar" durante a rota e "Nova rota" no resumo. A saída roda uma vez só, para um segundo toque durante o salvamento não fechar também a tela de baixo.

**Consequências.** Uma tentativa que falhou nunca conta como entrega, e o resumo diz o que aconteceu. Resultados, distância e início sobrevivem a um reinício do app. A distância vem do GPS: sem posição em segundo plano, o trecho percorrido com o app fora da tela entra como uma linha reta; superado por D-022, que mantém a posição em segundo plano durante a navegação. O resumo não é salvo; se o app for encerrado com ele na tela, ele se perde. Com o resumo na tela, o rebloqueio fica suspenso até "Nova rota". Um resultado errado não tem correção, e uma parada não entregue não volta para a fila na mesma rota. "Outro" não tem texto livre, e não há foto nem assinatura. Rotas salvas antes seguem funcionando: paradas visitadas contam como entregues, e o início passa a ser o "Iniciar" da continuação.

## D-020: Avisar o cliente pela folha de compartilhamento

**Contexto.** Depois da entrega. O cliente pergunta quando a entrega chega. O entregador já vê o horário de chegada no card da próxima parada, mas precisaria digitar a mensagem à mão, dirigindo. O app só guarda endereços: nenhuma parada tem telefone.

**Decisão.**
- Um botão "Avisar cliente" no card da próxima parada, antes de "Abrir em outro app", abre a folha de compartilhamento do sistema (`share_plus`) com a mensagem pronta. O entregador escolhe o app (WhatsApp, SMS, outro) e o contato ali.
- A mensagem segue o estado da navegação: com a chegada medida, "Olá! Sua entrega chega por volta das {HH:mm}.", com o mesmo horário do card; antes da primeira medida, "Olá! Sua entrega está a caminho."; depois de "Você chegou", "Olá! Cheguei com a sua entrega.", porque um horário já passado confundiria o cliente.
- A folha abre ancorada no botão, como o iPad exige. Se ela não abrir, a tela mostra "Não foi possível abrir o compartilhamento.", já que o botão não tem uma folha própria onde mostrar o erro.

**Consequências.** Nenhuma permissão nova, nenhum telefone guardado e nenhum backend nem API paga: um teste fixa as permissões do Android e as descrições de uso do iOS no conjunto de hoje. Cada envio pede um toque e a escolha do contato no outro app; não há envio automático nem aviso para todos os clientes da rota de uma vez, e o texto não é editável no app.

## D-021: Ida e volta com a partida como destino

**Contexto.** Depois da entrega. Muitos entregadores saem de um depósito e voltam para ele no fim do dia. A regra de D-004 termina a rota na parada mais distante: a volta não entra na ordem das paradas nem no tempo, e o app não tem o que mostrar depois da última parada.

**Decisão.**
- Um interruptor "Voltar ao ponto de partida" em Endereços escolhe a ida e volta. Ele começa desligado e guarda a última escolha confirmada (`shared_preferences`, chave `round_trip`).
- Ligado, a partida da rota vira o destino da requisição e todas as paradas viram intermediários com `optimizeWaypointOrder`. É a mesma chamada única de D-004, agora sem destino a escolher, então a ordem de todas as paradas já conta com a volta. Desligado, a regra de D-004 continua.
- A volta é dado do plano, não uma parada falsa: `RoutePlan.returnTo` (a partida) e `returnLeg` (o último trecho da resposta, da última parada até a partida). Assim a numeração, os resultados e o resumo seguem só com as paradas de verdade. Os dois campos entram no JSON salvo só quando existem, e uma rota salva antes é lida como só de ida.
- Depois do último resultado, a rota fica na volta: o card "Retorno" mostra a distância, o tempo e a chegada da volta, e "Finalizar rota" toma o lugar de "Entregue" e "Não entregue". Um fix com precisão ≤ 50 m a até 40 m da partida, a mesma regra da chegada numa parada, ou "Finalizar rota" conclui a rota, e o resumo conta o tempo até esse momento.
- O recálculo leva `returnTo`: com paradas faltando, elas viram intermediários até a partida; na volta, a requisição vai da posição atual até a partida, sem intermediários. `returnTo` fica separado de `origin`, que o recálculo troca pela posição atual, então o destino e o pino de partida no mapa não andam com o entregador.

**Consequências.** Continua uma requisição por cálculo, com um trecho a mais na resposta. A ordem de uma ida e volta é a que a Routes API otimiza para todas as paradas, sem a aproximação do ponto mais distante. A volta aparece na lista ("Retorno ao ponto de partida"), nos totais e no "Faltam …" da navegação. Na volta, "Encerrar" fica abaixo de "Finalizar rota" e continua a última ação do painel. Ele sai como no resto da rota: salva a rota e volta para a tela Rota (D-019), e o voltar do sistema faz o mesmo. O destino é sempre a partida: terminar em outro ponto ou em mais de um depósito pediria um seletor de destino e ficou de fora.

## D-022: Acompanhamento em segundo plano durante a navegação

**Contexto.** Depois da entrega. Pela D-008, o stream de posição pausava quando o app saía da tela. Quem dirige bloqueia o celular ou abre outro app, como o Waze por "Abrir em outro app", e a partir daí chegada, desvio e recálculo paravam até a volta. O README listava isso como limitação. A D-008 também supunha que localização em segundo plano pedia a permissão "sempre"; com as atualizações começando com o app aberto, "durante o uso" basta.

**Decisão.**
- De "Iniciar" até o fim da navegação, o acompanhamento continua em segundo plano, sem opção para desligar. Antes de "Iniciar", esperando o GPS, o stream ainda pausa quando o app sai da tela e volta com ele, como na D-008.
- Android: um foreground service do tipo `location`, do `flutter_local_notifications`, com a notificação fixa "RouteBreeze", texto "Acompanhando sua rota", no canal "Navegação", de importância baixa, e a marca monocromática como ícone pequeno (um ícone colorido e opaco vira um quadrado branco). O serviço deixa o processo em primeiro plano, então o stream do `geolocator` continua recebendo a localização "durante o uso" com a tela apagada. O stream usa `AndroidSettings` sem o serviço do próprio `geolocator`, para não haver duas notificações. O serviço liga em "Iniciar" e para em "Encerrar", ao concluir a rota ou quando a tela de navegação fecha.
- O serviço não é sticky: se o sistema encerrar o app em segundo plano, um serviço sticky voltaria com a notificação e sem o app para acompanhar, e a oferta "Continuar rota?" da D-007 já cobre esse caso. Ele tem `stopWithTask`, porque fechar o app pelos recentes encerra o Flutter, e o serviço não pode durar mais que ele. Uma falha ao ligar o serviço é engolida, e a navegação segue em primeiro plano.
- iOS: o stream da navegação usa `AppleSettings` com atualizações em segundo plano, o indicador de localização do sistema, sem pausas automáticas e como navegação de carro. O `Info.plist` declara o modo de segundo plano `location`.
- Só a permissão "durante o uso", nas duas plataformas: nada de "sempre" nem de `ACCESS_BACKGROUND_LOCATION`.
- O serviço é o do `flutter_local_notifications` porque a notificação dele pode ser atualizada e o mesmo plugin posta avisos: um plugin só para o serviço, a notificação e os avisos da rota.
- O `AppLifecycleGate` não muda: continua chamando a pausa e a volta da navegação, e o `NavigationCubit` decide o que elas fazem. Navegando, a pausa mantém o stream e salva a rota; esperando o GPS, cancela o stream.

**Consequências.** Chegada, desvio, recálculo, progresso e distância percorrida seguem com a tela bloqueada ou com outro app na frente. A troca é a bateria: o GPS fica ligado com a tela apagada enquanto a navegação dura, e só nela. Entra uma dependência nativa, com core library desugaring no Android, e o manifesto do plugin acrescenta `POST_NOTIFICATIONS` e `VIBRATE` ao APK. No Android 13+, o app ainda não pede a permissão de notificação: sem ela, o serviço roda, mas a notificação não aparece no painel. Os testes conferem as chamadas ao serviço e as configurações do stream; o comportamento com a tela bloqueada no Android se confere no aparelho. Depois que o sistema encerra o app, não há acompanhamento: isso pediria a permissão "sempre" e geofencing. Substitui a D-008 durante a navegação; antes de "Iniciar", a D-008 continua valendo.
