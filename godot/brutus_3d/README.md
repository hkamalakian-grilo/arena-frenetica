# Arena Frenética — vertical slice oficial no Godot

Base oficial do Arena Frenética em Godot 4.7. O primeiro corte vertical usa o
Brutus para validar movimento, combate e uma partida curta na Travessia antes da
produção dos demais heróis e do multiplayer.

A versão HTML foi preservada como laboratório e referência de regras. O produto
final é este projeto Godot e não precisa reproduzir as limitações visuais do HTML.

## Implementado

- Modelo 3D original construído do zero para Arena Frenética.
- Silhueta de tanque com armadura laranja/dourada, elmo, penacho e escudo.
- Uma malha rigada otimizada, com 10 materiais e aproximadamente 18 mil vértices.
- Rig completo e animações próprias: `idle`, `walk`, `run`, `attack`, `q` e `ultimate`.
- Movimento livre em 360°, rotação suave, aceleração e frenagem.
- Caminhada para analógico parcial e corrida própria acima de 68% de intensidade.
- Golpe básico acionado por espaço, Enter ou botão touch.
- Q — Investida: preparação atrás do escudo, dash, rastro e impacto; cooldown de 7 s.
- R — Escudo Bumerangue: giro de tronco, escudo destacável, voo, impacto e retorno; cooldown de 35 s.
- Câmera MOBA ortográfica inclinada em 55°.
- Controles por WASD, setas e analógico virtual.
- Travessia em retrato com apresentação 2.5D fiel à arte aprovada: textura
  canônica sobre malha subdividida e relevo alinhado por mapa de altura.
- Renderizador `gl_compatibility`, adequado ao primeiro alvo mobile/web.

## Como executar

1. Abra esta pasta no Godot 4.7 ou superior.
2. Execute `main.tscn` com F6/F5.

Pelo terminal:

```text
godot --path godot/brutus_3d
```

## Arquivos de produção

- `assets/brutus/brutus.glb`: modelo otimizado consumido pelo jogo.
- `assets/brutus/brutus_source.blend`: fonte editável com rig e animações.
- `tools/build_brutus.py`: reconstrói o modelo, renderiza a prévia e exporta o GLB.
- `tools/inspect_brutus.gd`: valida o modelo e os nomes das animações no Godot.
- `tools/test_abilities.gd`: executa automaticamente Investida e Escudo Bumerangue e valida seus estados.
- `scripts/data/travessia_definition.gd`: fonte canônica das posições e regras do mapa.
- `scripts/travessia_map.gd`: apresentação jogável alinhada à arte aprovada da Travessia.
- `assets/maps/travessia_clean_v1.png`: referência artística original preservada.
- `assets/maps/travessia_terrain_v4.png`: chão canônico usado pela partida, já
  sem os objetos do primeiro acampamento separado.
- `assets/maps/travessia_depth_v2.png`: relevo 2.5D derivado pixel a pixel da
  arte canônica; levanta florestas, muralhas, rochas e a ilha sem redesenhá-las.
- `assets/maps/upper_left_camp_v1.png`: primeiro acampamento extraído da própria
  arte e posicionado como módulo 2.5D independente.
- `tools/build_travessia_depth.gd`: reconstrói deterministicamente o mapa de altura.
- `tools/build_upper_left_camp_module.gd`: recompõe chão limpo, recorte e relevo
  do primeiro acampamento sem alterar lanes ou ponte.
- `assets/maps/tower_platform_v1.png`: plataforma independente das torres de lane.
- `docs/MODULAR_MAP_ARCHITECTURE.md`: regras para editar e ampliar o mapa sem repintá-lo.
- `PRODUCTION_ROADMAP.md`: ordem de construção até a alpha jogável.

O modelo não incorpora malhas, texturas ou animações de terceiros. A geometria, os materiais, o rig e os clips foram produzidos especificamente para este projeto a partir da identidade visual estabelecida para o Brutus.

## Vertical slice da partida

As coordenadas medidas, a fórmula de conversão e as regras de alinhamento visual
ficam registradas em `docs/TRAVESSIA_MAP_COORDINATES.md`.

O projeto deixou de ser apenas um visualizador do Brutus. A cena principal agora
inclui a primeira versão jogável da Travessia:

- duas lanes verticais e rio central;
- duas bases e quatro torres com vida, alcance e dano;
- waves automáticas nas duas lanes;
- minions que mantêm uma linha reta e focam torre antes da base;
- dragão neutro no centro;
- Brutus com vida, dano em área real, morte e retorno;
- HUD de vida, tempo, vida da base inimiga e anúncios;
- vitória ao destruir a base inimiga.

`tools/test_match.gd` valida estruturas, wave inicial, trajetória reta dos minions,
dano do Brutus e condição de vitória.
