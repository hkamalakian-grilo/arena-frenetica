# Arquitetura modular 2.5D da Travessia

## Decisão

A Travessia é montada em runtime a partir de módulos 3D independentes, com
câmera ortográfica e jogabilidade no plano X/Z. A imagem aprovada
`travessia_clean_v1.png` continua preservada como referência artística, mas não
é carregada pela partida nem usada para colisão, posicionamento ou navegação.

Isso permite mover uma torre, redesenhar uma lane, trocar uma ponte ou ampliar
o rio sem repintar uma imagem única e sem deixar marcas antigas no chão.

## Árvore principal

```text
TravessiaMap
├── TerrainModules
│   ├── WaterField
│   ├── NorthLand / SouthLand
│   ├── PathModules
│   └── DragonIslandModule
├── StaticModules
│   ├── StaticBridgeModules
│   ├── StructurePlatforms
│   ├── WallModules
│   ├── ShoreModules
│   ├── JungleModules
│   └── OuterForestModules
├── DynamicModules
│   └── DragonAccessBridges (criado durante a partida)
├── GameplayAnchors
├── FloorCollision
└── ArenaBounds
```

## Responsabilidade das camadas

- `TerrainModules`: água, terrenos, pavimentação e ilha central. Cada peça pode
  receber material, dimensões e posição próprias.
- `StaticModules`: objetos permanentes e reutilizáveis. As seis plataformas,
  pontes laterais, muralhas, margens, clareiras, pedras, arbustos e árvores são
  instâncias separadas.
- `DynamicModules`: elementos que mudam durante a partida. Os acessos norte e
  sul do dragão são construídos aqui quando o ovo choca.
- `GameplayAnchors`: fonte espacial usada para criar torres, torre principal,
  spawns e objetivo. A apresentação visual não determina gameplay.
- Colisão e zonas caminháveis: usam dados de `TravessiaDefinition`, nunca pixels
  ou limites visuais de um PNG.

## Fonte de verdade

`scripts/data/travessia_definition.gd` contém as dimensões, zonas caminháveis,
ritmo e posições canônicas. IDs estáveis:

- `red_left_tower`, `red_right_tower`;
- `blue_left_tower`, `blue_right_tower`;
- `red_core`, `blue_core`.

`Main._spawn_structure()` consulta `get_structure_anchor(id)`. Em runtime,
`Main.move_lane_tower(id, position)` move ator, plataforma e âncora em conjunto.

## Pontes

`scenes/world/modular_bridge_3d.tscn` e `scripts/modular_bridge_3d.gd` formam uma
peça reutilizável de alvenaria real. Cada curso possui pedras independentes; a
ponte pode variar comprimento, largura, sentido e correção de perspectiva. Não
há recorte nem alongamento da imagem antiga do mapa.

As duas pontes de lane existem desde o início. As duas pontes do dragão usam a
mesma tecnologia, aparecem por cursos e conectam o caminho à ilha após a eclosão.
A colisão do tabuleiro fica rente ao chão para não criar um degrau invisível.

## Regras de evolução

1. Elementos visuais repetidos devem virar módulos reutilizáveis.
2. Todo objeto com função de gameplay recebe ID e âncora estáveis.
3. Elementos mutáveis pertencem a `DynamicModules`.
4. Colisão, navegação, alcance e alvo nunca dependem da arte.
5. Uma mudança visual não pode alterar coordenadas de combate silenciosamente.
6. A imagem completa do mapa pode servir de referência externa, nunca de piso
   oculto por baixo dos módulos.

## Validação

- `tools/test_match.gd`: estrutura de camadas, módulos, seis plataformas,
  âncoras móveis, evento do dragão e fluxo completo da partida.
- `tools/test_walkable_physics.gd`: lanes, água, bordas e portão do dragão.
- `tools/test_abilities.gd`: movimentação e habilidades do Brutus sobre o mapa.
- `tools/capture_scene.gd`: captura visual em retrato para revisar alinhamento.

O método `uses_composite_map_art()` retorna `false` tanto no mapa quanto nas
pontes e é verificado automaticamente.
