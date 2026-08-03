# Pipeline 3D do elenco e minions

## Estado atual

- Brutus usa o modelo autoral rigado em `assets/brutus/brutus.glb`.
- Sol, Lyra e Nix usam volumes 3D estilizados criados por
  `scripts/stylized_actor_3d.gd`.
- Minions azuis e vermelhos usam a mesma fábrica 3D, com materiais por equipe.
- Os antigos PNGs dos heróis continuam no repositório apenas como referência visual;
  `HeroBot` não instancia mais `Sprite3D`.

## Regras do sistema

- Frente do modelo: eixo `-Z`, igual ao Brutus.
- Rotação: 360 graus seguindo o vetor real de movimento.
- Movimento: pernas e braços alternados, bob vertical pequeno e cadência ligada à
  velocidade da unidade.
- Ataque: pose transitória acionada pelo mesmo evento que aplica o dano.
- Dano: reação curta de compressão do volume.
- Materiais: iluminados pelas luzes e sombras reais da cena; sem billboard.
- Escala visual: heróis `1.26`; minions `0.92`.

## Identidade visual desta primeira versão

- Sol: branco, ouro, capuz, halo, cajado e orbes de luz.
- Lyra: verde, couro, capuz, capa, arco e flecha.
- Nix: preto, roxo, capuz, olho luminoso e duas adagas.
- Minions: soldado baixo com elmo, crista, escudo e espada nas cores da equipe.

## Próxima camada de qualidade

Esta fábrica resolve volume, iluminação, direção e animação básica. Ela não substitui
os modelos finais rigados. A evolução correta é produzir um GLB autoral por herói,
reaproveitando a interface de movimento e combate já estabelecida aqui, sem voltar a
sprites planos.

O teste `tools/test_match.gd` falha se os heróis voltarem a usar `Sprite3D` ou se um
minion deixar de possuir sua composição mínima de meshes 3D.
