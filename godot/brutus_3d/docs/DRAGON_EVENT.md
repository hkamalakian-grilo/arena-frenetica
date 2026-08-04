# Evento do Dragão

## Regra da partida

- A partida canônica dura 3 minutos no relógio do jogo.
- O centro começa fechado visualmente e contém um ovo de dragão.
- O ovo é neutro, invulnerável e não pode ser selecionado como alvo.
- Quando o relógio chega a `01:00`, o ovo choca e é substituído pelo dragão.
- No mesmo instante, duas pontes autorais no mesmo estilo das pontes laterais do rio se expandem pelas ligações norte e sul até a ilha central.
- Se nenhuma base for destruída até `00:00`, vence a equipe cuja base tiver mais vida; vidas iguais resultam em empate.

## Sequência visual

1. `03:00`: ovo roxo autoral no centro, com oscilação leve para indicar que está
   vivo. A arte transparente usada no jogo é
   `assets/dragon/dragon_egg_purple_v1.png`.
2. `01:00`: anúncio `O OVO CHOCOU — DRAGAO NO CENTRO!`.
3. Duas instâncias de `ModularBridge3D` são montadas da estrutura existente até
   a ilha durante 1,35 segundo. Cada fileira física sobe da água em sequência.
   As pedras possuem geometria, juntas, bordas, espessura e colisão próprias;
   apenas suas faces reutilizam amostras da arte aprovada das pontes laterais.
4. O dragão nasce no ponto central e passa a ser um objetivo neutro atacável.

## Fonte dos parâmetros

Os tempos e dados do objetivo ficam em `scripts/data/travessia_definition.gd`:

- `match_duration`: duração total da partida.
- `dragon_hatch_remaining`: tempo restante em que o ovo choca.
- `neutral_objectives()`: estado inicial do ovo.
- `dragon_definition()`: atributos do dragão após o nascimento.

O fluxo da partida é controlado por `scripts/main.gd`. `scripts/travessia_map.gd`
posiciona as pontes, e `scripts/modular_bridge_3d.gd` constrói e anima as peças.

## Observação sobre o ritmo Alpha

O Alpha usa `Engine.time_scale = 0.50`. O HUD continua sendo a referência correta:
o evento ocorre exatamente quando ele mostra `01:00`, mesmo com o ritmo geral
mais cadenciado.
