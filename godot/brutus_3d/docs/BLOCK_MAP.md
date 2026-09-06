# Mapa em blocos 3D — kit modular

Decisão de 05/09/2026: a Travessia passa a ser montada com um kit de blocos
3D em vez da pintura 2.5D. Motivo: mapas novos viram montagem numa grade
(horas, não semanas), muros e árvores têm altura e sombra reais, e trocar
um bloco melhora todos os mapas de uma vez. A pintura continua no
repositório como referência (`TravessiaMap.USE_BLOCK_KIT = false` volta a ela).

## Kit (`tools/build_map_kit.py` → `assets/kit/map_kit.glb`)

Quinze peças geradas no Blender, na mesma linguagem low-poly dos personagens,
sem texturas, origem no centro da célula ao nível do chão:

| Peça | Uso |
|---|---|
| `tile_grass`, `tile_road`, `tile_water`, `tile_island`, `tile_bridge` | ladrilhos de 1×1 (instanciados a 0,5) |
| `wall_stone` | borda do mapa e anel da ilha do dragão (os blocos dos portões somem ao chocar) |
| `bush`, `tree_round`, `tree_pine`, `rock`, `flower` | vegetação e pedras nas bordas dos caminhos e no interior |
| `bridge_post` | pilares nos cantos das pontes de lane |
| `platform_tower`, `platform_core` | bases das torres de lane e das torres principais |
| `dragon_pit` | poço brilhante no centro da ilha |

Regerar: `blender --background --factory-startup --python tools/build_map_kit.py`
e depois `godot --headless --path . --import`. A prévia fica em
`assets/kit/map_kit_preview.png`.

## Montagem (`scripts/block_map.gd`)

A regra é **reproduzir a pintura aprovada**, não inventar outro mapa:

- Grade de 0,5 unidades (36×68 células). O tipo de cada célula vem de
  `TravessiaDefinition.is_walkable` (estrada), da faixa do rio e do lago
  (água), do raio da ilha (ilha/anel) e do cruzamento andável × água (ponte).
- **A cor de cada ladrilho é lida da pintura** (`travessia_terrain_v6.png`)
  naquele ponto, com um ganho de 0,90 para compensar a luz real. Grama,
  lanes de areia, chão de pedra das bases e rio ficam com as cores originais.
- **Vegetação, muros e pedras nascem das camadas pintadas**: onde uma camada
  (florestas, muralhas, margens do rio, acampamentos) é opaca, entra a peça
  que combina com a cor pintada ali, tingida com essa cor. Verde vira árvore
  (grade grossa) ou moita; cinza vira muro (muralhas) ou pedra; roxo vira
  flor. Sem aleatoriedade.
- Cada peça é um `MultiMeshInstance3D` com cor por instância
  (`use_instance_color` no shader cel); ladrilhos não projetam sombra,
  vegetação e muros projetam.
- Plataformas das torres (`TowerPlatforms`, móveis pelos testes), plataformas
  dos núcleos e o poço do dragão são nós próprios.
- `open_gates()` esconde os blocos do anel na frente dos dois portões; as
  pontes dinâmicas (`ModularBridge3D`) continuam iguais.
- `ToonStyle.convert_mesh` aplica o shader cel + contorno às peças
  (contorno mais fino e degradê baixo nos ladrilhos).

## O que ainda não é bloco

Torres e torres principais continuam como sprites pintados sobre as
plataformas; dragão, ovo e personagens já são 3D. A troca das torres por
modelos 3D é o próximo passo natural do kit.
