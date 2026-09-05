# Pipeline 3D do ovo e do dragão

## Entrega runtime

O evento central não usa as imagens antigas como billboard. O Godot instancia:

- `assets/dragon/dragon_egg_3d.glb`: 38 peças de malha e clips `idle`, `hatch`;
- `assets/dragon/dragon_3d.glb`: 56 peças de malha e clips `idle`, `roar`,
  `attack`, `hurt`, `death`.

As fontes editáveis são `dragon_egg_source.blend` e `dragon_source.blend`. Toda
a geometria, materiais, rig e animações são próprios do Arena Frenética; não há
malha, textura ou animação de terceiros.

## Reconstrução

No diretório do projeto Godot, execute com Blender 5.2 ou superior:

```text
blender --background --factory-startup --python tools/build_dragon_family.py
```

O script substitui deterministicamente os dois `.blend`, os dois `.glb` e as
prévias PNG. Depois, reimporte os GLBs no Godot e execute:

```text
godot --headless --path . --script res://tools/inspect_dragon_family.gd
godot --headless --path . --script res://tools/test_match.gd
```

Resultados esperados: `DRAGON_FAMILY_MODEL` com os clips acima e
`ARENA_MATCH_OK`.

## Integração no jogo

`ArenaActor` mantém uma única interface para o objetivo:

- `play_hatch()` acelera o clip para terminar em 0,86 segundo real, mesmo com
  o ritmo global da Alpha em 50%;
- `play_spawn()` executa o rugido ao criar o dragão;
- ataques e dano selecionam os clips correspondentes;
- a derrota emite a recompensa imediatamente, desativa a colisão e preserva o
  modelo até o clip `death` terminar.

As escalas runtime são intencionais para a câmera ortográfica de 75°: o ovo
preenche o interior da ilha, enquanto o dragão preserva espaço para a barra de
vida e para as entradas das duas pontes.
