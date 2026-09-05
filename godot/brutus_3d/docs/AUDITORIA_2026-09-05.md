# Auditoria de 05/09/2026 — heróis, mapa, minions e jogabilidade

Quatro auditorias independentes (código + partidas headless) sobre o build
Godot na branch `feat/game-feel`. Nenhum código foi alterado por elas.

## O que as partidas automáticas mostraram

Três partidas de 3 minutos, ritmo canônico:

| Cenário | Torres caídas | Dragão | Resultado |
|---|---|---|---|
| Só bots, Brutus parado | 0 | ninguém foi | empate travado na ponte |
| Só minions, Brutus parado | 0 (nenhuma torre perdeu 1 HP em 2:26) | ninguém foi | lanes travam a z≈0 aos 20 s |
| Brutus roteirizado (anda + ATQ + Q) | 1 (aos 2:23) | nasceu aos 2:00, ninguém foi | "VITÓRIA" azul com 7×11 abates |

Conclusão: a partida não tem abertura, crescimento, disputa e clímax. Sem o
humano, nada acontece; com o humano, só ele decide e o placar não explica.

## Causas raiz (por ordem de impacto)

### P0 — quebram a partida

1. **Bots ignoram o dragão.** `scripts/hero_bot.gd:184-243` só considera
   `team == 1 - team`; o dragão é `team = 2`. Nunca há clímax. Esforço M.
2. **Lanes travam na ponte para sempre.** Waves simétricas nascem no mesmo
   instante (`main.gd:241-249`), minions iguais dos dois lados
   (`travessia_definition.gd:353-365`), sem reforço para quem está perdendo.
   Minions aliados se empilham no mesmo ponto (sem `sepForce` como no HTML,
   `src/config/balance.js:53`) e 4 batem no mesmo alvo. Esforço M.
3. **Bots não recuam com pouca vida nem trocam de lane.** Sol morreu com
   18/700 parada; Lyra ficou 80 s no mesmo ponto. `hero_bot.gd:135-181`.
   Esforço M.
4. **Lyra, Nix e Sol não têm Q nem R.** `hero_bot.gd` inteiro; critério de
   aceite 4 do `ALPHA_1.md` não cumprido. Esforço G.
5. **Desempate ilegível.** `main.gd:312-322` soma vida da própria base, 35%
   das torres, abates×45 e +180 por dragão; o HUD não mostra nada disso.
   Esforço M.
6. **Sem mira manual e joystick fixo.** `brutus_controller.gd:132-163` e
   `virtual_joystick.gd:37-57`; o design pede tap = auto e segurar+arrastar =
   mira. Esforço G.

### P1 — importantes

7. Elenco assimétrico: vermelho tem 2 bots (Lyra, Nix), azul tem 1 (Sol).
   Nix (~145 dps) esmaga Sol (~78 dps) e a lane direita sempre cai para o
   mesmo lado. `travessia_definition.gd:330-350`. Esforço P/M.
8. Buff do dragão é +12% permanente; README promete +30% por 45 s.
   `travessia_definition.gd:210`, `main.gd:371-395`. Esforço P.
9. Ponte pintada tem 2,55 un de largura, mas só 1,64 un é caminhável
   (`travessia_definition.gd:21,29`): parede invisível. Esforço P.
10. Botão R cobre a plataforma da torre azul direita em retrato, contra a
    regra do `TRAVESSIA_SPEC.md`. `main.tscn`. Esforço P.
11. Voltar da base ao front leva ~18 s reais (10% da partida) com respawn
    de 3 s: a punição real é a caminhada. Esforço G (velocidade pós-respawn,
    mapa menor ou move_speed).
12. Números do Brutus jogador destoam do HTML sem registro: vida +56%,
    AA +58%, Q +87%, slow do R 2× mais forte. Esforço P (documentar ou alinhar).
13. AA de Sol/Lyra é instantâneo, sem projétil. `hero_bot.gd:246-253`. Esforço M.
14. Sem indicador radial de cooldown nem prévia de alcance da Investida.
    `main.gd:104-109`. Esforço P/M.
15. Wave a cada 10 s no Godot vs 13 s no HTML, sem nota. Esforço P.

### P2 — fase seguinte do roadmap

16. Sem XP/nível (ult sem gate), morte súbita, cura na base, bushes,
    placar K/D/A e MVP, dificuldade, menu, contagem 3-2-1, pausa.
17. Três dos quatro acampamentos de jungle são só pintura sem acesso.
18. Pit do dragão libera ~10 un², menos de 1/3 de um trecho de lane, para 4
    heróis + dragão.
19. Heróis com ~30 px de diâmetro na câmera de mapa inteiro; validar em
    aparelho.

## Estado após os lotes 1 e 2 (mesmo dia)

Feitos: 1, 2, 3, 4, 5, 6, 8, 9, 10, 12, 13, 14, 15 (wave mantida em 10 s,
documentado em `MATCH_FLOW.md`). Item 7 não era bug: o quarto herói é o
jogador. Ficam para depois: 11 (deslocamento pós-morte), 16–19 (fase seguinte
do roadmap). Detalhes em `MATCH_FLOW.md` e `GAME_FEEL.md`.

## Ordem sugerida de ataque

Lote 1 (faz a partida acontecer, ~2 dias):
1. Bots contestam o dragão (P0-1) e recuam com pouca vida / rotacionam lane (P0-3).
2. Waves com desempate e separação entre minions (P0-2).
3. HUD mostra vida das duas bases e vantagem; fórmula em cascata torres →
   base → abates (P0-5).
4. Correções pequenas juntas: elenco 2×2 (7), buff do dragão temporário (8),
   ponte caminhável na largura pintada (9), botão R fora da torre (10),
   documentar números do Brutus (12).

Lote 2 (faz os heróis existirem, ~3 a 4 dias):
5. Sistema reutilizável de projétil, zona e dash; Q/R de Lyra, Nix e Sol (P0-4) e projétil no AA (13).
6. Mira manual segurar+arrastar, joystick flutuante, cooldown radial e prévia de alcance (P0-6, 14).

Lote 3: XP/nível, morte súbita, placar, menu (P2).
