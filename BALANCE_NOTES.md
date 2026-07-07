# BALANCE_NOTES — Arena Frenética

## Metodologia do playtest (M5)

Sem jogador humano disponível para as sessões de tuning, o passe de balanceamento foi feito com
**playtests automatizados**: partidas completas de 4 bots (a mesma IA do jogo, §14) rodando na
simulação pura (`src/sim/headless.js`), determinísticas por seed. Cada rodada de tuning usou
**12 partidas por mapa** (seeds fixas 5000/7000 para comparabilidade) e a configuração final foi
validada com **mais 12 partidas por mapa em seeds novas** (21000/23000) para não sobreajustar —
total de ~120 partidas, bem acima das 8 por mapa pedidas na spec. Limitação honesta: bots não
medem "diversão" nem dificuldade percebida por humano; medem ritmo, desfechos e curvas.

Alvos perseguidos (da spec):
- Nível 4 (destrava a ult) com farm médio em ~1:20–1:40 (§8).
- Partida termina em ~3 min na maioria das vezes; morte súbita como exceção, não regra (§10).
- Dragão contestado com frequência e decisivo sem ser auto-win (§9).
- Vitórias ~50/50 entre os lados (mapas simétricos).

## Mudanças e porquês

| # | Mudança | De → Para | Por quê |
|---|---|---|---|
| 1 | `xp.thresholds` | [0,80,190,330,520] → [0,95,230,400,620] | Nível 4 chegava aos ~65–75s (alvo 80–100s). Kills abundantes aceleravam a curva além do previsto no papel. |
| 2 | `xp.heroKill` / `heroAssist` | 70/35 → 55/28 | Mesmo motivo: em partidas com 20–30 abates, o XP de kill dominava o farm e antecipava as ults; reduzir também modera o snowball. |
| 3 | `xp.mapMult.B` | 0.65 → 0.62 | Farm solo por lane no B rende mais por herói; recalibrado p/ a curva de níveis bater com o A (B fechou em 81,5s de média p/ nível 4). |
| 4 | `dragon.hp` | 1800 → 1400 | Com 1800, o dragão era contestado mas raramente MORTO no A (17% das partidas): 2 heróis não fechavam a janela com a lane pressionando. 1400 tornou o abate viável (33–92%). |
| 5 | `dragon.buffDmgPct` | 0.25 → 0.30 | O buff precisava converter em quebra de estrutura dentro dos ~45s p/ cumprir o papel de desempate do último minuto (§9). |
| 6 | `bots.objectiveMinHpPct` | 0.50 → 0.45 | No A (skirmish constante) os bots raramente estavam >50% HP aos 2:00 e ignoravam o pit; 0.45 aumentou contestação. |
| 7 | Torres do Mapa A | T1 1200→1150, T2 1500→1250 | Metade das partidas do A empatava em torres (1×1) aos 3:00 e caía em morte súbita; T2 mais quebrável devolveu desfechos no tempo normal (SD de 67% → 50%). |
| 8 | IA: dive com buff do dragão | (novo) | Bot com buff do dragão não fica mais esperando wave fora do alcance da torre: comita o push — a janela de 45s não pode ser desperdiçada. |
| 9 | Sim: comandos pré-amostrados | (correção) | Bug de simetria: bots do time vermelho decidiam DEPOIS dos azuis se moverem no mesmo tick (informação mais fresca) e venciam 61–64% dos espelhos. Comandos de todos agora são amostrados antes de qualquer movimento — espelhos voltaram a ~50/50 (56% azul em 36 partidas, dentro do ruído). |

Também corrigidos durante o playtest (mecânica, não número): ramp da torre aplicava +25% já no
1º tiro (agora 1º tiro é dano base); Chuva de Flechas dava 1 tick a mais (210 vs 180 de dano).

## Comparativo final entre mapas (12 partidas novas por mapa, config final)

| Métrica | Mapa A — Coliseu | Mapa B — Encruzilhada |
|---|---|---|
| Duração média | **3:14** | **2:56** |
| Abates por partida (total) | 27,6 | 31,7 |
| % indo a morte súbita | 50% | **8%** |
| Dragão morto / contestado | 42% / 67% | **92% / 100%** |
| Nível 4 (média) | 1:13 | **1:21** |
| Vitórias do azul | 50% | 58% |
| Desfechos | 2 base, 4 torres, 5 SD, 1 HP% | 6 base, 5 torres, 1 SD |
| Empates / travadas | 0 / 0 | 0 / 0 |

## Recomendação: **Mapa B (Encruzilhada) como layout principal**

Fundamentos:
1. **Desfechos limpos**: 92% das partidas do B terminam no tempo normal (metade delas com base
   destruída) — a morte súbita fica como válvula de escape rara, como §10 pretende. No A, metade
   das partidas empata em torres e precisa da morte súbita.
2. **O dragão funciona**: no B ele é contestado em 100% e morto em 92% das partidas — o conector
   central transforma o spawn aos 2:00 na convergência prevista na spec. No A o pit fica no meio
   do fluxo contínuo de wave/teamfight e o dragão vira "mais um alvo na pilha".
3. **Curva de níveis no alvo**: nível 4 aos ~1:21 no B (alvo 1:20–1:40), com a ult chegando como
   segundo ato claro.
4. **Decisões espaciais**: o B produz o mind game de rotação visível (§4-B) que o A, por ter uma
   lane só, não oferece.

O Mapa A permanece valioso como **modo briga** (teamfight ininterrupto, zero downtime — máximo
frenetismo literal) e para playtest de kits, mas tende ao empate estrutural: dois times simétricos
trocando em um único corredor raramente abrem vantagem de estrutura antes dos 3:00. Se quiser
promovê-lo a principal no futuro, os caminhos são: pit do dragão deslocado para fora da lane
(exigiria flexibilizar o §4), buff do dragão mais agressivo contra estruturas, ou T2 ainda mais
frágil.

## Flags deixadas para playtest humano

- `ult.mode`: `'level'` (default) vs `'timer'` (90s) — §8.
- `mapB_requireBothTowers`: `false` (default §4-B) vs `true` — com `true` espere mais jogos
  decididos por torres/HP% e menos por base.
- Thresholds da IA em `BAL.bots` para ajustar agressividade.
