# Apresentação — câmera de brawler, estilo toon e minimapa

Decisão de 05/09/2026: o jogo deixa de mostrar o mapa inteiro. A câmera fica
perto do Brutus, como nos brawlers mobile, e o minimapa cobre a visão geral.
Motivo: com o mapa inteiro o herói tinha 30 px numa tela de 720 e o jogo
parecia um tabuleiro; a arte pintada da Travessia funciona bem de perto.

## Câmera (`main.tscn`, `scripts/main.gd`)

- Ortográfica, `size = 14` (era 37), inclinação de 60° (era 75°), posição
  `(0, 26, 15)` no rig. A 60° vemos rosto e armadura, não só o capacete.
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
