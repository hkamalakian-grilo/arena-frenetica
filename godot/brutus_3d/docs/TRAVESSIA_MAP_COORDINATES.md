# Travessia — coordenadas e alinhamento das estruturas

Este arquivo registra os achados usados para alinhar estruturas ao mapa aprovado.
Ele deve ser consultado antes de mover torres, bases, objetivos ou trocar a arte do
chão. A fonte de verdade executável é `scripts/data/travessia_definition.gd`.

## Referência canônica

- Textura: `assets/maps/travessia_clean_v1.png`
- Resolução: `913 x 1723` pixels
- Plano no Godot: `18.02 x 34.0` unidades (`MAP_SIZE`)
- Origem do mundo: centro da textura
- Eixo horizontal da imagem: `X` do mundo
- Eixo vertical da imagem: `Z` do mundo; topo é `Z` negativo

Não se deve calcular estruturas por simetria. A pintura aprovada contém pequenas
assimetrias; cada marca do chão precisa de uma medição própria.

## Conversão de pixel para mundo

Para um ponto `(pixel_x, pixel_y)`:

```text
world_x = (pixel_x / 913 - 0.5) * 18.02
world_z = (pixel_y / 1723 - 0.5) * 34.0
world_y = 0
```

Os valores executáveis são armazenados já convertidos, com quatro casas decimais,
para evitar diferenças entre ferramentas de importação.

## Marcadores medidos

| Estrutura | Equipe | Pixel no mapa | Posição no Godot `(x, y, z)` |
|---|---:|---:|---:|
| Torre de lane superior esquerda | Vermelha (1) | `(200, 238)` | `(-5.0626, 0, -12.3035)` |
| Torre de lane superior direita | Vermelha (1) | `(705, 238)` | `(4.9047, 0, -12.3035)` |
| Torre de lane inferior esquerda | Azul (0) | `(200, 1463)` | `(-5.0626, 0, 11.8694)` |
| Torre de lane inferior direita | Azul (0) | `(705, 1463)` | `(4.9047, 0, 11.8694)` |
| Torre principal superior | Vermelha (1) | `(455, 171)` | `(-0.0296, 0, -13.6257)` |
| Torre principal inferior | Azul (0) | `(455, 1502)` | `(-0.0296, 0, 12.6390)` |

## Regra de pivô do sprite

A posição do ator representa o centro da plataforma pintada no chão. O sprite deve
ser deslocado apenas no eixo `Y`, até a base visual da construção tocar o chão.
Nunca se corrige um pivô ruim alterando `X` ou `Z`, porque isso tira a estrutura do
centro do marcador.

Parâmetros atuais:

| Arte | `pixel_size` | deslocamento `Y` |
|---|---:|---:|
| Torre de lane | `0.0032` | `1.08` |
| Torre principal | `0.0043` | `1.68` |

## Assets atuais

- `assets/structures/tower_crystal_red_v1.png`
- `assets/structures/tower_crystal_blue_v1.png`
- `assets/structures/main_tower_core_red_v2.png`
- `assets/structures/main_tower_core_blue_v2.png`

As torres principais são fortalezas de pedra bege aquecida e ouro, com um grande cristal
central e quatro cristais menores. A versão `v2` usa câmera mais elevada, pedra
bege aquecida, menor contraste e sombra de contato procedural para se integrar ao
mapa. `base` continua sendo o identificador interno no
código para preservar as regras existentes; na interface e no design o nome é
**torre principal**.

## Integração visual — aprendizado da versão v1

A primeira torre principal usava pedra quase preta, contraste alto, excesso de
microdetalhes e uma câmera mais frontal. Embora funcionasse isoladamente, dentro do
mapa parecia um adesivo de outro jogo. Para estruturas grandes da Travessia:

- repetir a câmera elevada de aproximadamente 55 graus da pintura do mapa;
- priorizar superfícies superiores e reduzir fachadas verticais;
- usar a pedra bege/cinza aquecida, ouro suave e bordas menos duras do cenário;
- manter detalhe médio/baixo e formas grandes, legíveis e arredondadas;
- dimensionar a torre principal em torno de 1,6 vez a largura visual da torre de lane;
- não incluir piso no PNG: a plataforma pintada no mapa já cumpre essa função;
- usar uma sombra de contato radial, suave e procedural para apoiar o sprite no chão.

Assets muito escuros, góticos, hiper detalhados ou frontais devem ser rejeitados
antes da integração, mesmo que sejam bonitos quando vistos separadamente.

## Procedimento para futuras alterações

1. Use a textura aprovada, nunca uma captura com HUD.
2. Meça o centro da marca pintada em pixels.
3. Converta com a fórmula acima e registre pixel e mundo nesta tabela.
4. Ajuste somente escala e pivô vertical do sprite.
5. Gere uma captura da cena inteira e confira a base da estrutura contra o círculo.
6. Execute `tools/test_match.gd` e `tools/test_abilities.gd`.

Se uma nova versão da textura alterar resolução ou enquadramento, todos os
marcadores devem ser medidos novamente; não basta reutilizar as coordenadas antigas.

## Ritmo global da Alpha

`TravessiaDefinition.match_rules().game_speed` é a fonte de verdade do ritmo da
partida. O valor atual é `0.50`: movimentação, animações, ataques, projéteis,
cooldowns, ondas, respawns e cronômetro avançam a 50% da velocidade normal.

Não aplique multiplicadores adicionais isoladamente para tentar obter o mesmo
efeito. Se o ritmo global mudar, altere somente `game_speed`; ajustes específicos de
herói ou unidade continuam pertencendo aos respectivos dados de balanceamento.
