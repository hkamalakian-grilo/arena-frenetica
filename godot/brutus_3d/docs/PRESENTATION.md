# Apresentação — câmera de brawler, estilo toon e minimapa

Decisão de 05/09/2026: o jogo deixa de mostrar o mapa inteiro. A câmera fica
perto do Brutus, como nos brawlers mobile, e o minimapa cobre a visão geral.
Motivo: com o mapa inteiro o herói tinha 30 px numa tela de 720 e o jogo
parecia um tabuleiro; a arte pintada da Travessia funciona bem de perto.

## Câmera (`main.tscn`, `scripts/main.gd`)

- Ortográfica, `size = 14` (era 37), inclinação de 55° (era 75°), posição
  `(0, 26, 18.2)` no rig. A 55° vemos rosto e armadura, não só o capacete.
- **Mapa inteiro sob demanda:** tocar no minimapa (ou Tab) afasta a câmera
  até a Travessia completa (size 37, 75°) com transição de 0,38 s, e volta
  do mesmo jeito. A partida continua rodando.
- Segue o Brutus com suavização (`CAMERA_FOLLOW_SPEED = 6`) e um pequeno
  adiantamento na direção em que ele olha (`CAMERA_LEAD = 0.9`).
- Limites do rig: `x ∈ [-5, 5]`, `z ∈ [-8.8, 8.8]`. Nunca aparece o vazio
  além do mapa pintado. `snap_camera_to_player()` posiciona sem suavizar.
- `follow_player_camera = false` volta ao mapa inteiro (útil para capturas
  de mapa e para as ferramentas de build).

## Estilo dos personagens (`scripts/toon_style.gd`)

`ToonStyle.apply(model, largura_do_contorno)` troca cada material por uma
cópia com `DIFFUSE_TOON` + `SPECULAR_TOON`, cores um pouco mais saturadas, e
encadeia um segundo passe (`next_pass`) que desenha a silhueta escura
extrudando a malha pelas normais com `cull_front`. Funciona no
`gl_compatibility` e acompanha a animação (skinning acontece antes do shader).

`ToonStyle.add_blob_shadow(parent, tamanho)` adiciona a sombra macia no chão.

Aplicado a: Brutus (0,06 em unidades do modelo, escala 0,56), escudo
arremessado, Lyra/Nix/Sol (0,03), minions (0,035), dragão e ovo (0,04).

## Proporções de desenho animado (`tools/chibi_warp.py`)

Os modelos continuam gerados por script no Blender 5.2, mas agora passam
por um warp depois de montados: um remapeamento vertical por faixas (pernas
encurtam, tronco encolhe um pouco, cabeça cresce) mais uma escala radial que
depende da altura, e escala extra em mãos e botas. Ossos e vértices são
deformados juntos, então todas as animações continuam válidas.

| Modelo | Pernas | Tronco | Cabeça (z / xy) | Mãos | Botas |
|---|---|---|---|---|---|
| Lyra, Nix, Sol, minions | ×0,62 | ×0,86 | ×1,15 / ×1,26 | ×1,55 | ×1,3 |
| Brutus | ×0,64 | ×0,84 | ×1,18 / ×1,22 | ×1,4 | ×1,3 |

Lyra e Sol ganharam olhos grandes (esclera, pupila, brilho), sobrancelhas
com expressão e boca; Nix, dois olhos brilhantes estreitos; minions, olhos
luminosos na cor do time sob a viseira. As animações do elenco têm
squash-and-stretch na raiz (corrida, ataque, dano, habilidades).

O elmo do Brutus passou a laranja com aro dourado e as ombreiras a laranja
escuro, para cabeça, ombros e escudo não virarem uma mancha única de cima.

Para regerar:

```text
blender --background --factory-startup --python tools/build_roster_family.py
blender --background --factory-startup --python tools/build_brutus.py
godot --headless --path . --import
```

## Luz e shader dos personagens

Luz principal a 40° de elevação (era 55°): vista de cima, uma luz quase
vertical iluminava tudo por igual. O shader cel (`ToonStyle.CEL_SHADER`)
usa 3 tons com piso de sombra 0,45, e um degradê vertical (pés a 62% do
brilho, cabeça a 100%) que dá volume mesmo na câmera inclinada.

## Minimapa (`scripts/minimap.gd`)

Control de 92×174 px no canto superior esquerdo. Desenha grama, rio, lanes,
bases e ilha de forma esquemática; torres e bases como quadrados, minions
como pontos, heróis como círculos com a cor do time, Brutus em dourado com
anel branco, dragão/ovo em roxo, e o retângulo que a câmera mostra no chão
(calculado com `Camera3D.size`, o aspecto da viewport e a inclinação).

## Indicador de mira (`scripts/aim_indicator.gd`)

A prévia de Q/R é desenhada em 2D no HUD, projetando os quatro cantos da
faixa no chão com `Camera3D.unproject_position`. Antes era um plano 3D e a
sombra dele aparecia serrilhada sobre o relevo. `BrutusController` só guarda
`aim_preview_kind` e `aim_preview_direction`; `aim_preview_extent(kind)` dá
comprimento e largura em unidades de mundo.

## Efeitos (`scripts/vfx.gd`)

Tudo procedural, sem texturas, em `GPUParticles3D` (suportado no
`gl_compatibility`): `burst` (faíscas aditivas ou fumaça), `dust` (poeira no
chão), `flash` (clarão que estoura e some), `slash` (meia-lua do golpe
corpo a corpo, shader), `trail` (emissor preso a projéteis e ao escudo) e
`area` (chuva de flechas descendo ou brilho de cura subindo nas zonas).

Onde aparecem: golpe básico (meia-lua + faíscas no acerto), Investida
(poeira no rastro, explosão no fim), Escudo (clarão ao soltar, rastro roxo,
explosão no impacto), passos na corrida, projéteis dos bots (rastro e clarão
no acerto), cura (faíscas verdes), zonas, tiro de torre, morte de minion,
herói, torre e dragão, nascimento do dragão e abate.

## Interface (`scripts/hud_style.gd`)

- Rótulos com contorno grosso (`outline_label`), placa escura com aro dourado
  atrás do placar (`plate`), barra de vida com borda e brilho no topo.
- Botões de habilidade circulares com aro na cor da habilidade, sombra e os
  ícones pintados do projeto (`assets/ui/skill_attack.png`, `skill_q.png`,
  `skill_r.png`). O ícone escurece durante a recarga e o tempo restante é
  desenhado por cima com contorno.
- Joystick com sombra, aro dourado, marcas de direção e brilho no botão.
- Números de dano "estouram" (escala 1,6 → 1,0) ao aparecer.

## Ajustes que acompanharam a câmera próxima

- Números de dano: `pixel_size` 0,0075 → 0,0042.
- Vinheta de dano começa mais longe do centro.
- `tools/test_match.gd` passou a exigir `size 14`, câmera seguindo, minimapa,
  toon com contorno no Brutus e sombra no chão, além do limite do rig.
