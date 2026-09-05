# Fluxo da partida — bots, minions, dragão e desempate

Resposta aos lotes 1 e 2 da `AUDITORIA_2026-09-05.md`. Objetivo: a partida
acontecer sozinha (torres caem, dragão é disputado, placar explica) e os três
bots terem kit completo.

## Bots (`scripts/hero_bot.gd`)

Decisão a cada tick físico, nesta ordem:

1. **Recuo.** Abaixo de 30% de vida o bot volta ao próprio spawn e só sai do
   modo ao chegar a 55%. Perto da torre principal a fonte cura 8%/s.
2. **Torre quase caída (< 25%)**, em qualquer lane, se o bot tem ≥ 45% de vida.
3. **Herói inimigo** a 5,5 m, exceto se estiver sob torre inimiga em pé sem
   minions aliados a 3,2 m dela, ou com o bot abaixo de 60% (anti-mergulho).
4. **Torre ferida (< 45%)**, em qualquer lane.
5. **Minion inimigo** a 4,6 m, com a mesma proteção contra torre.
6. **Dragão**, quando vivo, com as pontes abertas e o bot acima de 50% de vida.
   Os dois times convergem para a ilha: é o clímax previsto no design.
7. **Estrutura da lane.** Sem minions aliados perto da torre (e torre acima de
   45%), o bot segura fora do alcance dela (4,5 m + 0,7) e espera a wave. Com a
   própria lane sem torre e o núcleo ainda protegido, muda para a outra lane.
8. **Rotação.** Sem inimigo a 7 m por 4 s, muda para a lane com mais pressão
   inimiga (minions inimigos mais perto do próprio núcleo).

Torres atiram primeiro em minions e só depois em heróis (aggro clássico), e
têm 1100 de vida (era 1500): uma wave com um herói derruba uma torre. O
dragão tem 1400 de vida e 70 de dano (eram 2200 / 85), valores do HTML.

Navegação: `scripts/travessia_nav.gd` usa os waypoints de
`TravessiaDefinition.nav_waypoints()` (bases, junções, lanes, pontes e ilha).
Linha reta quando andável; senão o menor caminho pelo grafo. Todas as arestas
são validadas com raio 0,42 em `tools/test_roster_kits.gd`.

Kits (`TravessiaDefinition.hero_kits()`, valores do HTML ÷ 100):

| Herói | Q | R | AA |
|---|---|---|---|
| Lyra | Flecha Perfurante: projétil que atravessa unidades, 120, 6 m, 6 s | Chuva de Flechas: zona 2 m por 3 s, 60/s, lentidão 25%, 40 s | projétil teleguiado |
| Nix | Passo Sombrio: teletransporte 3 m + próximo golpe +100, 8 s | Execução: dash, 280 (×2 abaixo de 35%), 50 s | corpo a corpo |
| Sol | Orbe Solar: fere 100 ou cura 140 no aliado mais ferido, 7 s | Zona Radiante: 2,2 m por 4 s, cura 40/s + 20% de velocidade de ataque, 45 s | projétil teleguiado |

Componentes: `scripts/ability_projectile.gd` (reto ou teleguiado, perfura,
cura aliado), `scripts/ability_zone.gd` (ticks com dano/lentidão ou
cura/haste, telegrafado), `scripts/combat_world.gd` (buscas e feedback).
Brutus, HeroBot e ArenaActor expõem `heal()` e `health_ratio()`.

## Minions (`scripts/arena_actor.gd`)

- **Coluna.** Minion aliado a menos de 0,62 m à frente na lane faz o de trás
  esperar. A wave anda em fila e só o da frente troca golpes.
- **Troca justa.** O golpe corpo a corpo cai 0,28 s depois do balanço, mesmo se
  o atacante morrer nesse meio tempo. A ordem na árvore de cena não decide mais.
- **Ordem de spawn** alterna entre os times a cada wave.
- **Waves reforçadas.** Quem mata o dragão ganha 2 waves com +50% de vida e
  dano (modelo 18% maior).

## Dragão e desempate (`scripts/main.gd`)

- Recompensa: +30% de dano por 45 s (`dragon_buff_left`, mostrado no HUD),
  cura e 2 waves reforçadas. Ao expirar, minions e heróis voltam ao normal.
- **Vantagem em cascata** (`_team_advantage()`): torres destruídas → vida da
  torre principal → abates → dragão. O HUD mostra a vida das duas torres
  principais e uma linha "VANTAGEM AZUL — mais torres destruídas (1 × 0)". O
  fim por tempo usa a mesma frase.
- Fonte para o Brutus na própria torre principal (raio 3,2, 8%/s).

## Validação

- `tools/test_roster_kits.gd`: kits, projéteis, zonas, recuo, fonte, dragão,
  anti-mergulho, coluna de minions, troca justa, cascata, HUD, botões touch,
  mira manual, joystick flutuante.
- `tools/validate_match.gd`: partida completa de 3 minutos com um Brutus
  automático; imprime linha do tempo a cada 15 s e o resumo final.

Partida de validação em 05/09/2026 (Brutus automático simples, ritmo canônico):

| Métrica | Antes dos lotes | Depois |
|---|---|---|
| Primeira torre | nunca | 84 s |
| Dragão: primeiro golpe / morte | nunca / nunca | 140 s / 172 s |
| Bots recuando com pouca vida | não | sim (modo `retreat` visível na linha do tempo) |
| Resultado | "VITÓRIA" com 7×11 abates, sem explicação | vitória azul: "mais torres destruídas (1 × 0)" |

O Brutus automático morre duas vezes e faz um abate; um humano deve fazer
melhor. Os números de Lyra/Nix (vermelho leva 4–5 abates) são o próximo alvo
do playtest humano.
