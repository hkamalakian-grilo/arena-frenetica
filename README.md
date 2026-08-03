# Arena Frenética — mini-MOBA 2v2

> **Alpha 1:** o mapa oficial e padrão é C — Travessia. Brutus inaugura o sistema de animação em oito direções lógicas. Consulte [ALPHA_1.md](ALPHA_1.md).

> **Vertical slice 3D:** a fonte autoral está em `godot/brutus_3d`; o jogo Canvas usa 19 atlases exportados desse modelo, com dez estados, oito direções reais e variantes sem escudo.

Protótipo jogável de MOBA 2v2 mobile-first no browser: **3 minutos** de partida + até 2 de morte
súbita, mapa 100% visível (sem câmera de rolagem), **visão inclinada 2.5D** estilo Brawl Stars
(objetos com altura e profundidade), kits enxutos (ataque + Q + ultimate) e ritmo frenético.

## Como jogar

**Dê dois cliques em `index.html`.** Não precisa instalar nada — funciona em qualquer navegador
moderno (Chrome, Edge, Firefox), inclusive no celular.

### No celular, como um app (tela cheia, offline)

O jogo é um **PWA**: abra o link publicado (Netlify) no celular e instale na tela de início —
ele passa a abrir **sem barra de navegador**, com ícone próprio, e **funciona sem internet**.

- **Android (Chrome)**: menu ⋮ → *Instalar aplicativo* / *Adicionar à tela inicial*.
- **iPhone (Safari)**: botão Compartilhar → *Adicionar à Tela de Início*.
- Jogando pelo navegador mesmo (sem instalar), tocar em **JOGAR** já entra em tela cheia
  no Android; no iPhone o caminho é instalar.

1. Escolha o seu herói, o **parceiro** (bot), o mapa e a **dificuldade** (Fácil/Normal/Difícil,
   vale só para os inimigos) e toque **JOGAR** — as duplas se apresentam e a contagem 3-2-1-LUTE!
   solta a partida (toque na tela para pular). São **3 mapas**: A e B deitados (paisagem) e o
   **C "Travessia" em pé** (vertical, estilo Clash Royale: rio, pontes e o dragão na ilha) —
   no celular, segure o aparelho conforme o mapa.
2. Você + seu parceiro contra 2 bots. Destrua a **base** inimiga (ou tenha mais torres aos 3:00).
   No fim, a tabela mostra K/D/A, dano, cura e farm de cada um — com coroa de **MVP**.
3. O **Dragão** nasce aos 2:00 no centro: o time que o matar ganha +30% de dano por 45s e
   2 waves reforçadas — geralmente fecha o jogo.

### Controles

| | Celular (touch) | Computador |
|---|---|---|
| Mover | joystick no lado esquerdo (aparece onde tocar) | WASD ou setas |
| Atacar | segurar botão **AA** | botão esquerdo do mouse ou espaço |
| Q / R | **tap** = lança no alvo mais próximo · **segurar e arrastar** = mira manual (arraste de volta ao botão p/ cancelar) | Q / R lançam na direção do mouse |
| Som liga/desliga | alto-falante no canto superior direito | tecla **M** (ou o alto-falante) |

Entrar num **bush** (moita) esconde você dos inimigos até atacar ou até um inimigo entrar junto.

O jogo tem **efeitos sonoros sintéticos** (golpes, habilidades, abates, torres, dragão) gerados
em tempo real via WebAudio — sem arquivos de áudio. O som destrava no primeiro toque/tecla
(regra dos navegadores) e a preferência de mudo fica salva entre partidas.

### Heróis

| Herói | Papel | Q | R (destrava no nível 4) |
|---|---|---|---|
| **Brutus** ⬡ | Tanque | Investida: corrida protegida + atordoa | Escudo Bumerangue: arremesso, lentidão e retorno |
| **Lyra** ◇ | Atiradora | Flecha Perfurante (atravessa minions) | Chuva de Flechas: área contínua |
| **Nix** ▲ | Assassino | Passo Sombrio: teleporte + próximo golpe reforçado | Execução: dano dobrado abaixo de 35% |
| **Sol** ● | Suporte | Orbe Solar: fere inimigo OU cura aliado | Zona Radiante: cura + frenesi + revela |

## Estrutura do projeto

```
index.html              ponto de entrada (2 cliques)
src/config/balance.js   TODAS as constantes de balanceamento
src/config/maps/        Mapa A "Coliseu" e Mapa B "Encruzilhada" (data-driven)
src/sim/                simulação pura e determinística (60 Hz, roda sem browser)
src/sim/abilities/      kits Q/R independentes de Brutus, Lyra, Nix e Sol
src/input/              joystick virtual, botões touch, teclado/mouse
src/render/             Canvas 2D: mapa, entidades, HUD, partículas
src/main.js             game loop (timestep fixo + render interpolado) e telas
godot/brutus_3d/        vertical slice 3D do Brutus em Godot
```

- `BALANCE_NOTES.md` — playtests automatizados, mudanças de balanceamento e comparativo dos mapas.
- `DECISIONS.md` — decisões de design e o desvio de stack (JS puro, sem Node).

## Para desenvolvedores

- `?debug=1` na URL mostra o FPS.
- No console do navegador: `__moba.runSuite({mapId:'B', n:8, seedBase:123})` roda partidas
  headless de bots e retorna estatísticas agregadas (duração, abates, dragão, morte súbita…).
- Simulação nunca lê DOM/`Math.random` — determinística por seed, preparada p/ multiplayer futuro.
