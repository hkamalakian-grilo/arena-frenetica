# Arena Frenética — mini-MOBA 2v2

Protótipo jogável de MOBA 2v2 mobile-first no browser: **3 minutos** de partida + até 2 de morte
súbita, mapa 100% visível (sem câmera), kits enxutos (ataque + Q + ultimate) e ritmo frenético.

## Como jogar

**Dê dois cliques em `index.html`.** Não precisa instalar nada — funciona em qualquer navegador
moderno (Chrome, Edge, Firefox), inclusive no celular (paisagem/horizontal).

1. Escolha o herói e o mapa, toque **JOGAR**.
2. Você + 1 bot aliado contra 2 bots. Destrua a **base** inimiga (ou tenha mais torres aos 3:00).
3. O **Dragão** nasce aos 2:00 no centro: o time que o matar ganha +30% de dano por 45s e
   2 waves reforçadas — geralmente fecha o jogo.

### Controles

| | Celular (touch) | Computador |
|---|---|---|
| Mover | joystick no lado esquerdo (aparece onde tocar) | WASD ou setas |
| Atacar | segurar botão **AA** | botão esquerdo do mouse ou espaço |
| Q / R | **tap** = lança no alvo mais próximo · **segurar e arrastar** = mira manual (arraste de volta ao botão p/ cancelar) | Q / R lançam na direção do mouse |

Entrar num **bush** (moita) esconde você dos inimigos até atacar ou até um inimigo entrar junto.

### Heróis

| Herói | Papel | Q | R (destrava no nível 4) |
|---|---|---|---|
| **Brutus** ⬡ | Tanque | Investida: dash + atordoa | Terremoto: dano em área + lentidão |
| **Lyra** ◇ | Atiradora | Flecha Perfurante (atravessa minions) | Chuva de Flechas: área contínua |
| **Nix** ▲ | Assassino | Passo Sombrio: teleporte + próximo golpe reforçado | Execução: dano dobrado abaixo de 35% |
| **Sol** ● | Suporte | Orbe Solar: fere inimigo OU cura aliado | Zona Radiante: cura + frenesi + revela |

## Estrutura do projeto

```
index.html              ponto de entrada (2 cliques)
src/config/balance.js   TODAS as constantes de balanceamento
src/config/maps/        Mapa A "Coliseu" e Mapa B "Encruzilhada" (data-driven)
src/sim/                simulação pura e determinística (60 Hz, roda sem browser)
src/input/              joystick virtual, botões touch, teclado/mouse
src/render/             Canvas 2D: mapa, entidades, HUD, partículas
src/main.js             game loop (timestep fixo + render interpolado) e telas
```

- `BALANCE_NOTES.md` — playtests automatizados, mudanças de balanceamento e comparativo dos mapas.
- `DECISIONS.md` — decisões de design e o desvio de stack (JS puro, sem Node).

## Para desenvolvedores

- `?debug=1` na URL mostra o FPS.
- No console do navegador: `__moba.runSuite({mapId:'B', n:8, seedBase:123})` roda partidas
  headless de bots e retorna estatísticas agregadas (duração, abates, dragão, morte súbita…).
- Simulação nunca lê DOM/`Math.random` — determinística por seed, preparada p/ multiplayer futuro.
