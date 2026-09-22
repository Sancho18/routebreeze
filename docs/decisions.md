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
- Chegada: 40 m da próxima parada, mais o botão "Marcar como visitado".
- Início da navegação e partida: último fix com precisão ≤ 50 m (partida em até 15 s).
- Distância ponto-segmento em projeção equiretangular: erro abaixo de 1% na escala da cidade e barata por fix.

**Consequências.** Filtra ruído, evita tempestade de recálculos e mantém uma requisição por evento real de desvio. Os valores ficam em construtores com defaults e são testados um a um.

## D-007: Offline com rota persistida e recálculo adiado

**Contexto.** "Sem internet" é critério de avaliação. A rota já está no aparelho depois de calculada; só o recálculo precisa de rede.

**Decisão.** `connectivity_plus` alimenta um banner "Sem conexão" e desabilita ações de rede (confirmar rota, autocomplete). A rota ativa é salva em `shared_preferences` (um JSON) ao ser calculada e a cada parada visitada; apagada ao concluir ou ao iniciar uma rota nova. No cold start com rota salva, o app oferece "Continuar rota?". Offline na navegação, acompanhamento e chegada continuam; o recálculo fica pendente e roda ao reconectar. Requisições têm timeout de 10 s e uma nova tentativa após 2 s em erro de conexão.

**Consequências.** Uma queda de sinal não perde a rota. `connectivity_plus` informa estado do link, não alcance da internet: a requisição que falhar é mapeada para "sem conexão" do mesmo jeito.

## D-008: Bateria e GPS

**Contexto.** Otimização de bateria é diferencial do teste. Localização em segundo plano exige permissão "sempre" e foreground service.

**Decisão.** Stream de posição só durante a navegação, com precisão máxima e `distanceFilter` de 5 m. Pausa em segundo plano, retoma na volta, encerra em "Encerrar" ou ao concluir. Partida com um único fix. Sem localização em segundo plano.

**Consequências.** Parado, não há eventos nem processamento. Nada de setup nativo extra. O acompanhamento pausa fora da tela (limitação documentada).

## D-009: Bloqueio com fallback para PIN e rebloqueio após 30 s

**Contexto.** O app deve exigir biometria e tratar aparelhos sem biometria cadastrada ou sem bloqueio de tela.

**Decisão.** `local_auth` com `biometricOnly: false`. Prompt no primeiro frame. Rebloqueio ao voltar do segundo plano após 30 s ou mais, exceto com navegação ativa. Sem credencial nenhuma, o app fica bloqueado com instrução para configurar o bloqueio de tela.

**Consequências.** Trocas rápidas de app não interrompem; a rota em andamento nunca é bloqueada. O caso sem credencial é tratado, não contornado.

## D-010: Design system Rota como tokens em código

**Contexto.** A aderência ao design system é critério de avaliação.

**Decisão.** Tokens (9 cores, 6 estilos de texto, 4 espaçamentos, 3 raios) em `lib/core/theme/rb_tokens.dart`. Widgets base usam só tokens; `buildRbTheme` aplica ao Material. Fonte do sistema. Botão primário com a mesma altura e raio nos estados habilitado/desabilitado. Marcadores numerados desenhados em canvas com `dart:ui`, cacheados por número.

**Consequências.** Nenhum valor solto nas telas. Testes de widget conferem cores e estilos. Sem tema escuro (o design system define só o claro).

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
