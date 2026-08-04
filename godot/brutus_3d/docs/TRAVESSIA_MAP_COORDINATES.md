# Travessia — coordenadas e alinhamento

A fonte executável é `scripts/data/travessia_definition.gd`. A arte
`assets/maps/travessia_clean_v1.png` é somente referência; a partida é montada
por `scripts/travessia_map.gd` e não converte pixels em coordenadas em runtime.

## Sistema de coordenadas

- Área visual: `18.02 x 34.0` unidades (`MAP_SIZE`).
- Origem: centro da ilha do dragão.
- `X`: horizontal, positivo para a direita.
- `Z`: vertical no mapa, negativo para o time vermelho e positivo para o azul.
- `Y`: altura visual; o gameplay permanece no plano X/Z.
- Centros das lanes: `X = -5.35` e `X = 5.35`.

## Marcadores canônicos

| Estrutura | ID | Posição `(x, y, z)` |
|---|---|---:|
| Torre principal vermelha | `red_core` | `(0, 0, -13.45)` |
| Torre vermelha esquerda | `red_left_tower` | `(-5.35, 0, -12.15)` |
| Torre vermelha direita | `red_right_tower` | `(5.35, 0, -12.15)` |
| Torre principal azul | `blue_core` | `(0, 0, 13.45)` |
| Torre azul esquerda | `blue_left_tower` | `(-5.35, 0, 12.15)` |
| Torre azul direita | `blue_right_tower` | `(5.35, 0, 12.15)` |
| Objetivo do dragão | `DragonObjective` | `(0, 0, 0)` |

As posições são deliberadamente simétricas. O mapa modular não precisa preservar
assimetrias acidentais da antiga pintura.

## Pivô e plataforma

A posição do ator representa o centro da plataforma. O sprite da construção
pode receber apenas ajuste vertical (`Y`) para tocar o chão. Correções em `X` ou
`Z` no sprite são proibidas porque separariam apresentação e gameplay.

Parâmetros atuais:

| Arte | `pixel_size` | deslocamento `Y` |
|---|---:|---:|
| Torre de lane | `0.00355` | `1.24` |
| Torre principal vermelha | `0.0047` | `1.45` |
| Torre principal azul | `0.0047` | `1.62` |

Para mover uma estrutura durante o desenvolvimento, altere o marcador canônico
ou use `Main.move_lane_tower(id, position)`. Plataforma, âncora e ator devem
permanecer juntos.

## Física e navegação

- `WALKABLE_RECTS`: lanes e caminhos centrais.
- `WALKABLE_ELLIPSES`: praças das bases, sem vazamentos nos cantos.
- `DRAGON_ACCESS_RECTS`: pontes que só ficam caminháveis após a eclosão.
- `DRAGON_ISLAND_RADIUS`: limite físico da ilha.

Heróis e minions não colidem entre si. O movimento é restringido somente pela
geometria caminhável do mapa. Minions priorizam unidades inimigas próximas e,
na ausência delas, a torre e depois a torre principal.

## Ritmo global

`TravessiaDefinition.match_rules().game_speed` é a fonte de verdade. O valor
atual é `0.50`: movimento, animações, ataques, projéteis, cooldowns, waves,
respawns e cronômetro avançam a 50% da velocidade de referência.

## Checklist de alteração

1. Edite o módulo ou marcador responsável, não uma imagem completa.
2. Confira a plataforma e a construção na mesma âncora.
3. Gere uma captura vertical da cena.
4. Execute `test_match.gd`, `test_walkable_physics.gd` e `test_abilities.gd`.
5. Se houver mudança arquitetural, atualize `MODULAR_MAP_ARCHITECTURE.md`.
