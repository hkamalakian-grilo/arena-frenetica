# Evento do Dragão

## Regra da partida

- A partida canônica dura 3 minutos no relógio do jogo.
- O centro começa fechado visualmente e contém um ovo de dragão.
- O ovo é neutro, invulnerável e não pode ser selecionado como alvo.
- Quando o relógio chega a `01:00`, o ovo choca e é substituído pelo dragão.
- No mesmo instante, duas pontes autorais no mesmo estilo das pontes laterais do rio se expandem pelas ligações norte e sul até a ilha central.
- A torre principal permanece protegida até as duas torres de lane da equipe
  serem destruídas.
- Se nenhuma torre principal for destruída até `00:00`, o desempate considera
  vida das torres principais, vida das torres de lane, abates e dragão.

## Sequência visual

1. `03:00`: ovo roxo autoral 3D no centro, com pulsação e oscilação próprias.
   O jogo instancia `assets/dragon/dragon_egg_3d.glb`; não há billboard no
   objetivo central.
2. `01:00`: anúncio `O OVO ESTÁ CHOCANDO!`. O clip `hatch` comprime a casca e
   lança os três fragmentos superiores antes da substituição pelo dragão.
3. Duas instâncias de `ModularBridge3D` são montadas da estrutura existente até
   a ilha durante 1,35 segundo de jogo. Quatro cursos completos de alvenaria
   sobem da água em sequência, usando a escala e as pedras da ponte lateral
   aprovada. O tabuleiro possui espessura 3D discreta e encaixa sob as muralhas.
   A colisão e a máscara caminhável permanecem bloqueadas até as duas pontes
   terminarem a construção.
4. A camada `DragonIsland` troca para `dragon_island_open_full_v1.png`. Apenas
   os corredores norte e sul mudam: árvore e muralha fechadas dão lugar ao
   mesmo piso de alvenaria amostrado da ponte lateral. A ponte dinâmica termina
   na borda e encontra essa continuação, sem sobreposição sobre o dragão.
5. O dragão 3D nasce no ponto central, executa `roar` e passa a ser um objetivo
   neutro atacável. Ataque, dano e derrota disparam respectivamente os clips
   `attack`, `hurt` e `death`; a morte termina antes de remover o modelo.
6. A equipe que aplica o golpe final recebe cura imediata nos heróis e bônus de
   12% de dano pelo restante da partida. O bônus alcança heróis, minions vivos e
   novas ondas, e também participa do desempate por tempo.

## Fonte dos parâmetros

Os tempos e dados do objetivo ficam em `scripts/data/travessia_definition.gd`:

- `match_duration`: duração total da partida.
- `dragon_hatch_remaining`: tempo restante em que o ovo choca.
- `neutral_objectives()`: estado inicial do ovo.
- `dragon_definition()`: atributos do dragão após o nascimento.

O fluxo da partida é controlado por `scripts/main.gd`. `scripts/travessia_map.gd`
posiciona as pontes, e `scripts/modular_bridge_3d.gd` constrói e anima as peças.
`scripts/arena_actor.gd` instancia e sincroniza os dois modelos 3D. A fonte
editável, o comando de reconstrução e o contrato das animações estão em
`docs/DRAGON_3D_PIPELINE.md`.

## Observação sobre o ritmo Alpha

O Alpha usa `Engine.time_scale = 0.50` apenas para o ritmo da ação. O relógio usa
tempo real; o evento ocorre quando o HUD mostra `01:00`, dois minutos reais após o
início, mesmo com movimento e animação mais cadenciados. A montagem das pontes
também ignora o `time_scale` e termina em aproximadamente 1,35 segundo real.
