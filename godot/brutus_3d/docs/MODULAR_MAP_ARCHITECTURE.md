# Arquitetura modular da Travessia

## Objetivo

A arte aprovada da Travessia continua definindo a identidade visual, mas nenhum
elemento de gameplay que precise mudar de posição deve ficar pintado
permanentemente no terreno. A montagem modular permite alterar uma torre sem
redesenhar o mapa inteiro nem deixar uma plataforma fantasma no local antigo.

## Camadas da cena

```text
TravessiaMap
├── TerrainLayer
│   └── TerrainArt
├── StaticProps
│   └── TowerPlatforms
├── DynamicProps
│   └── DragonAccessBridges (criado durante a partida)
├── FloorCollision
└── ArenaBounds
```

- `TerrainLayer`: usa `travessia_terrain_v3.png`, sem as quatro plataformas das
  torres de lane.
- `StaticProps`: contém objetos separados que permanecem durante a partida. As
  plataformas das torres são montadas aqui a partir dos marcadores canônicos.
- `DynamicProps`: contém objetos que surgem, desaparecem ou animam, como as
  pontes do dragão.
- Colisões continuam independentes da imagem e das camadas visuais.

## Fonte de verdade

`scripts/data/travessia_definition.gd` mantém IDs, equipes e posições. Cada
estrutura possui um ID estável:

- `red_left_tower`, `red_right_tower`;
- `blue_left_tower`, `blue_right_tower`;
- `red_core`, `blue_core`.

Ao alterar `position` em `tower_markers()`, a torre e sua plataforma passam a
usar a nova coordenada na próxima montagem da partida. Não é necessário editar
o PNG do terreno.

Em runtime, `Main.move_lane_tower(id, position)` move o ator e a plataforma em
conjunto. O teste automatizado desloca uma torre, verifica os dois objetos e
restaura a posição original.

## Regra para novos elementos

1. Elementos puramente decorativos e imutáveis podem permanecer no terreno.
2. Objetos com posição relevante para gameplay pertencem a `StaticProps`.
3. Objetos que mudam de estado durante a partida pertencem a `DynamicProps`.
4. Colisão, navegação e alcance nunca devem depender dos pixels da arte.
5. Todo objeto móvel recebe um ID estável e posição em `TravessiaDefinition`.

## Assets

- `travessia_clean_v1.png`: referência artística original preservada.
- `travessia_terrain_v3.png`: terreno de produção sem plataformas de lane e com
  o corredor lateral do acampamento superior esquerdo liberado.
- `tower_platform_v1.png`: plataforma modular transparente.
- `scenes/world/modular_bridge_3d.tscn`: cena de ponte 3D reutilizável. Comprimento,
  direção e largura são configuráveis; o piso é gerado por quatro fileiras
  físicas com colisão independente.
- `scripts/modular_bridge_3d.gd`: monta e anima cursos completos da alvenaria
  original. Cada curso preserva pedras, rejunte, paleta e iluminação das pontes
  aprovadas, sem alongamento de textura.

## Limite atual

As quatro plataformas das torres de lane e as pontes do dragão já são
modulares. A ponte é o primeiro componente real da Travessia V3. Terreno, água,
margens, pontes laterais, vegetação e muralhas ainda usam a imagem antiga como
gabarito e serão migrados por etapas conforme `MAP_V3_MIGRATION.md`.
