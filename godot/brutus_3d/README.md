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
- Ovo e dragão centrais totalmente 3D, autorais e animados; o evento inclui
  pulsação, eclosão, rugido, ataque, dano e morte sem sprites billboard.
- Elenco Alpha completo em 3D autoral: Brutus, Lyra, Nix e Sol, além de minions
  azuis e vermelhos, todos com rig, locomoção, combate, dano e morte.
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
- `assets/dragon/dragon_egg_3d.glb` e `assets/dragon/dragon_3d.glb`: modelos 3D
  consumidos pelo evento central.
- `assets/dragon/*_source.blend`: fontes editáveis do ovo e do dragão.
- `tools/build_dragon_family.py`: reconstrói ambos os modelos, previews e GLBs.
- `tools/inspect_dragon_family.gd`: valida malhas e clips após a importação.
- `docs/DRAGON_3D_PIPELINE.md`: contrato visual e técnico do objetivo central.
- `assets/roster/*.glb`: Lyra, Nix, Sol e as duas variantes de minion usadas no jogo.
- `assets/roster/*_source.blend`: fontes editáveis de todo o elenco adicional.
- `tools/build_roster_family.py`: reconstrói modelos, previews, rigs e animações.
- `tools/inspect_roster_family.gd`: valida malhas e contratos de clips do elenco.
- `tools/test_abilities.gd`: executa automaticamente Investida e Escudo Bumerangue e valida seus estados.
- `scripts/data/travessia_definition.gd`: fonte canônica das posições e regras do mapa.
- `scripts/travessia_map.gd`: apresentação jogável alinhada à arte aprovada da Travessia.
- `assets/maps/travessia_clean_v1.png`: referência artística original preservada.
- `assets/maps/travessia_terrain_v6.png`: chão canônico compartilhado por todas
  as peças modulares da Travessia.
- `assets/maps/travessia_depth_v1.png`: relevo 2.5D global alinhado à arte;
  levanta florestas, muralhas, rochas e a ilha sem redesenhá-las.
- `assets/maps/*_full_v1.png`: treze camadas transparentes alinhadas à malha:
  quatro jungles, limites, florestas, margens, ilha e duas pontes.
- `tools/build_travessia_depth.gd`: reconstrói deterministicamente o mapa de altura.
- `tools/build_upper_left_camp_module.gd`: recompõe chão limpo, recorte e relevo
  do primeiro acampamento sem alterar lanes ou ponte.
- `tools/build_remaining_camp_modules.gd`: separa os outros três acampamentos e
  atualiza o chão e o relevo compartilhados.
- `tools/build_full_canvas_camp_modules.gd`: alinha os recortes de jungle aos
  mesmos UVs e à mesma perspectiva da malha principal.
- `tools/build_complete_map_modules.gd`: reconstrói os nove módulos ambientais
  e o chão V6 de forma determinística.
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
- waves automáticas em tempo real nas duas lanes, limitadas a quatro minions por
  equipe em cada lane para impedir acúmulo infinito;
- minions que mantêm uma linha reta e priorizam unidades próximas antes das estruturas;
- dragão neutro no centro;
- Brutus com vida, dano em área real, morte e retorno;
- HUD de vida identificado, tempo real, estado das quatro torres, objetivo central
  e anúncios;
- torre principal protegida até as duas torres de lane caírem;
- tela final com resultado, motivo, torres, abates e reinício;
- vitória ao destruir a torre principal inimiga ou por vantagem no desempate.

`tools/test_match.gd` valida estruturas, limite de waves, prioridades de IA,
relógio real, recompensa do dragão, trajetória reta, dano, bloqueio pelas duas
torres, condição de vitória e tela final.
