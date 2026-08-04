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
  torres de lane. A textura permanece visualmente canônica, mas é aplicada a
  uma malha subdividida e deslocada por `travessia_depth_v1.png`, produzindo
  relevo 2.5D sem reinventar a arte.
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
- `travessia_depth_v1.png`: mapa de altura alinhado à textura de produção.
- `tools/build_travessia_depth.gd`: geração determinística do mapa de altura a
  partir dos pixels aprovados; não usa geração criativa nem redesenha objetos.
- `tower_platform_v1.png`: plataforma modular transparente.
- `scenes/world/modular_bridge_3d.tscn`: cena de ponte 3D reutilizável. Comprimento,
  direção e largura são configuráveis; o piso é gerado por quatro fileiras
  físicas com colisão independente.
- `scripts/modular_bridge_3d.gd`: monta e anima cursos completos da alvenaria
  original. Cada curso preserva pedras, rejunte, paleta e iluminação das pontes
  aprovadas, sem alongamento de textura.

## Estratégia 2.5D permanente

O cenário imutável usa uma representação híbrida: aparência canônica em textura
e profundidade física em geometria. Isso evita perder identidade visual durante
a migração. Elementos que precisam mudar durante a partida — estruturas,
plataformas, personagens, ovo, dragão e pontes dinâmicas — permanecem separados.

Refinamentos futuros devem melhorar o mapa de altura ou extrair uma camada da
própria arte. Não se deve substituir o mapa por um greybox procedural.
