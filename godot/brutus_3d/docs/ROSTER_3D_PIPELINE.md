# Pipeline 3D do elenco e minions

## Estado atual

- Brutus usa o modelo autoral rigado em `assets/brutus/brutus.glb`.
- Sol, Lyra e Nix usam GLBs autorais rigados em `assets/roster/`.
- Minions azuis e vermelhos têm a mesma geometria autoral, mas GLBs e materiais
  de equipe independentes para manter contraste em tela pequena.
- Os antigos PNGs dos heróis continuam no repositório apenas como referência visual;
  `HeroBot` não instancia mais `Sprite3D`.

## Regras do sistema

- Frente do modelo: eixo `-Z`, igual ao Brutus.
- Rotação: 360 graus seguindo o vetor real de movimento.
- Heróis: clips `idle`, `run`, `attack`, `q`, `ultimate`, `hurt`, `death`.
- Minions: clips `idle`, `run`, `attack`, `hurt`, `death`.
- Ataque e dano são acionados pelo mesmo evento que aplica o resultado de gameplay.
- A morte toca antes de ocultar/remover o personagem; o respawn restaura `idle`.
- Materiais: iluminados pelas luzes e sombras reais da cena; sem billboard.
- Escala visual runtime: heróis `1.28`; minions `0.82`.

## Identidade visual desta primeira versão

- Sol: branco, ouro, capuz, halo, cajado e orbes de luz.
- Lyra: verde, couro, capuz, capa, arco e flecha.
- Nix: preto, roxo, capuz, olho luminoso e duas adagas.
- Minions: soldado baixo com elmo, crista, escudo e espada nas cores da equipe.

## Fontes e reconstrução

Cada `.glb` possui um `_source.blend` editável e uma prévia PNG. Para reconstruir
deterministicamente todo o conjunto com Blender 5.2 ou superior:

```text
blender --background --factory-startup --python tools/build_roster_family.py
```

`scripts/stylized_actor_3d.gd` deixou de construir primitives em runtime. Ele agora
é o adaptador que seleciona o GLB, direciona o modelo em 360 graus e escolhe os
clips a partir do movimento e dos eventos de combate.

O teste `tools/test_match.gd` falha se os heróis voltarem a usar `Sprite3D` ou se um
minion deixar de possuir sua composição mínima de meshes 3D.
`tools/inspect_roster_family.gd` valida os cinco GLBs e todos os clips obrigatórios.
