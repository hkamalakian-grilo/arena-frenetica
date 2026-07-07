# Prompt para Claude Code — Mini-MOBA 2v2 "Arena Frenética"

> Copie tudo abaixo desta linha e cole no Claude Code como prompt inicial do projeto.

---

Você vai construir um protótipo jogável de um **mini-MOBA 2v2 mobile-first** rodando no browser. Leia a especificação inteira antes de escrever qualquer código, depois siga o plano de milestones no final. Ao terminar cada milestone, rode o jogo, valide os critérios de aceite e só então avance.

## 1. Visão do jogo

MOBA competitivo 2v2 de partidas curtas e frenéticas: **3 minutos de partida padrão + 2 minutos de sudden death** em caso de empate (referência de ritmo: Clash Royale; referência de mecânicas: League of Legends condensado).

Diferenciais centrais que NÃO podem ser violados:
- **Mapa 100% estático e travado**: o mapa inteiro cabe na tela, sem câmera, sem scroll, sem minimapa (ele é desnecessário — tudo é visível o tempo todo).
- **Kits enxutos**: cada herói tem apenas ataque básico + 1 habilidade (Q) disponível desde o início + 1 ultimate (R) que destrava ao longo da partida.
- **Ritmo frenético**: decisões a cada segundo, trocas constantes, zero downtime.

## 2. Stack técnica (decisão fechada)

- **TypeScript + Canvas 2D puro + Vite**. Sem engine pesada (nada de Unity/Godot nesta fase). Se você julgar que Phaser 3 acelera muito algum milestone, proponha e justifique ANTES de adicionar a dependência — a preferência é vanilla Canvas para controle total do game loop.
- **Mobile-first, orientação LANDSCAPE (horizontal)**. Justificativa: o jogo tem controle direto do herói, então precisa de dois polegares — joystick virtual à esquerda, botões de ação à direita (padrão Wild Rift / Brawl Stars). Portrait estilo Clash Royale só funciona para jogos de deploy por toque, não para controle direto.
- Deve rodar bem em desktop também (WASD/mouse ou setas como fallback) para facilitar testes.
- **Game loop com timestep fixo de 60 Hz para a simulação** e render interpolado. Separe rigorosamente simulação de renderização — a simulação deve ser determinística e não pode ler nada do DOM/render. Isso prepara o terreno para multiplayer autoritativo no futuro.
- Estrutura do projeto: `src/sim/` (lógica pura), `src/render/`, `src/input/`, `src/config/balance.ts` (TODAS as constantes de balanceamento num único arquivo — nenhum número mágico espalhado pelo código).

## 3. Escopo da versão 1

- **1 jogador humano + 3 bots** (1 aliado, 2 inimigos). Multiplayer online real é fase futura e está FORA do escopo — não implemente networking, mas não tome decisões de arquitetura que o inviabilizem.
- Sem meta-progressão fora da partida (sem loja, sem skins, sem conta). Uma tela de seleção simples (herói + mapa) → partida → tela de resultado → rematch.
- Sem áudio elaborado (sons sintéticos simples via WebAudio são bem-vindos no polish, mas opcionais).

## 4. Mapa — DOIS layouts para playtest

O motor de mapa deve ser **data-driven**: um arquivo de definição por mapa em `src/config/maps/` contendo posições de bases, torres, spawns e waypoints de minions, bushes, paredes e pit do dragão. A engine NÃO pode ter nada de layout hardcoded — os dois mapas abaixo rodam sobre exatamente o mesmo código de simulação. Seleção de mapa na tela inicial + mapa default por flag em `balance.ts`.

Comum aos dois layouts: arena retangular simétrica (proporção ~16:9 em unidades lógicas, ex.: 1600×900), mapa 100% visível sem câmera, **1 base (Nexus) em cada extremidade lateral**, **2 torres por lado**, **pit do Dragão no centro exato do mapa**.

### Mapa A — "Coliseu" (lane única)
- Lane única larga conectando as duas bases, passando por uma **arena central aberta** (praça de teamfight).
- Torres **em série na lane**: Torre externa (T1) mais avançada, Torre interna (T2) protegendo a base. A T2 só se torna atacável depois que a T1 do mesmo lado cair; a base só é atacável depois das duas torres.
- **4 bushes simétricas**: 2 acima e 2 abaixo da arena central, com paredes/obstáculos leves criando corredores de flanco que passam pelos bushes.
- Perfil esperado: teamfight 2v2 constante, zero split push. Máximo frenetismo.

### Mapa B — "Encruzilhada" (duas lanes)
- **Duas lanes paralelas** (superior e inferior) conectando as bases, com **1 torre por lane por lado** (mantém as 2 torres por lado).
- **Conector central (mid)** ligando as duas lanes na vertical e passando pelo pit do Dragão — é o corredor de rotação e gank.
- **4 bushes simétricas**: 2 nas bocas do conector central (uma em cada saída para as lanes) e 2 nos cantos externos das lanes (espelhadas).
- Gating: a base fica atacável quando **ao menos uma** torre do lado cair (default — necessário para a partida caber em 3 min). Inclua flag em `balance.ts` para exigir as duas torres e teste as duas regras.
- Perfil esperado: 1v1 duplo com decisões constantes de rotação pelo mid. Como o mapa inteiro é visível, rotacionar vira mind game — o inimigo VÊ você saindo da lane. O dragão aos 2:00 força a convergência final.

### Regra dos bushes (idêntica nos dois mapas)
Unidade dentro do bush fica **invisível para inimigos que estão fora**, exceto se: (a) um inimigo também estiver dentro do mesmo bush, (b) a unidade atacar ou usar habilidade (revela por 1,5 s), ou (c) estiver marcada por efeito de reveal. Renderize aliados no bush com transparência parcial para o jogador saber que está oculto.

## 5. Estruturas

| Estrutura | HP | Dano | Alcance | Observações |
|---|---|---|---|---|
| Torre T1 — Mapa A | 1.200 | 90/tiro, 1 tiro/s | 220 u | Dano contra heróis cresce +25% por tiro consecutivo no mesmo alvo (ramp) |
| Torre T2 — Mapa A | 1.500 | 110/tiro, 1 tiro/s | 220 u | Mesmo ramp |
| Torre de lane — Mapa B | 1.300 | 100/tiro, 1 tiro/s | 220 u | Mesmo ramp; 1 por lane por lado |
| Base | 2.000 | não ataca | — | Destruição = vitória imediata |

Prioridade de alvo da torre: minions inimigos > herói inimigo. **Exceção de aggro**: se um herói inimigo causar dano a um herói aliado dentro do alcance da torre, a torre troca o alvo imediatamente para o agressor (regra clássica de MOBA — ensina o jogador a respeitar dive).

Todos os valores acima são ponto de partida — coloque em `balance.ts` e ajuste no playtest.

## 6. Minions

- Waves spawnam da base de cada time a cada **13 s**, começando em 0:05.
- **Mapa A**: 1 wave por lado com 3 melee (HP 300, dano 25, alcance corpo a corpo) + 1 ranged (HP 180, dano 35, alcance 150 u).
- **Mapa B**: 1 wave POR LANE por lado, com composição reduzida (2 melee + 1 ranged) para o total de unidades e de farm não dobrar. Ainda assim o XP disponível no mapa difere — inclua um **multiplicador de XP de minion por mapa** em `balance.ts` e calibre para a curva de níveis (§8) bater igual nos dois mapas (nível 4 em ~1:20–1:40 com farm médio).
- Caminham pela lane em direção à base inimiga. IA simples: avançar → atacar primeiro inimigo em alcance de percepção (estrutura, minion ou herói) → ao morrer o alvo, seguir avançando.
- Função primária: **tankar torres** e empurrar a lane. Sem minion na área, a torre foca o herói.
- A partir do sudden death (ver §10), waves ficam reforçadas (+1 melee) e o intervalo cai para 10 s, para forçar desfecho.

## 7. Heróis (roster inicial: 4)

Cada herói: ataque básico + Q (habilidade base, disponível desde o nível 1) + R (ultimate, ver destravamento em §8). Auto-ataque tem **auto-aim** no inimigo válido mais próximo (prioridade: herói com menor HP% em alcance > minion). Q e R com **telegraph visual** (área/linha desenhada) durante a mira.

**Brutus — Tanque/Iniciador (melee)**
- Stats nível 1: HP 1.100, dano AA 60, alcance AA 90 u, velocidade 260 u/s.
- Q "Investida" (CD 7 s): dash em linha (350 u); primeiro inimigo atingido leva 80 de dano e fica atordoado 0,8 s.
- R "Terremoto" (CD 45 s): AoE circular ao redor de si (raio 250 u), 200 de dano + slow de 40% por 2 s.

**Lyra — Atiradora (ranged, dano sustentado)**
- Stats: HP 750, dano AA 75, alcance AA 320 u, velocidade 270 u/s.
- Q "Flecha Perfurante" (CD 6 s): skillshot em linha (600 u), 120 de dano, atravessa minions.
- R "Chuva de Flechas" (CD 40 s): AoE à distância (raio 200 u a até 500 u), 60 de dano/s por 3 s + slow 25%.

**Nix — Assassino (melee, burst)**
- Stats: HP 800, dano AA 85, alcance AA 100 u, velocidade 300 u/s.
- Q "Passo Sombrio" (CD 8 s): teleporte curto (300 u) na direção mirada; próximo AA em 3 s causa +100 de dano.
- R "Execução" (CD 50 s): dash no alvo; se o alvo estiver abaixo de 35% HP, dano é dobrado (280 → 560).

**Sol — Maga/Suporte (ranged, utilidade)**
- Stats: HP 700, dano AA 55, alcance AA 300 u, velocidade 265 u/s.
- Q "Orbe Solar" (CD 7 s): skillshot que causa 100 de dano em inimigo OU cura 120 em aliado (o que atingir primeiro).
- R "Zona Radiante" (CD 45 s): área (raio 220 u) por 4 s; aliados dentro recebem +20% velocidade de ataque e 40 de cura/s, inimigos dentro são revelados (inclusive em bush).

Balanceamento — princípios que você deve respeitar ao ajustar números:
- **TTK (time-to-kill) alvo em trade justo 1v1: 4–6 s.** Burst do assassino pode matar em ~2,5 s um alvo já abaixo de 50%.
- Tanque nunca deve matar um ranged que joga bem, mas deve vencer se o ranged errar posicionamento.
- Nenhum herói pode solar uma torre com HP cheio antes do minuto 1.
- Toda constante de herói vive em `balance.ts` numa tabela por herói.

## 8. Progressão dentro da partida

- **XP** por: minion morto próximo (raio de 400 u, compartilhado entre aliados no raio), takedown de herói, torre destruída (XP para o time todo).
- Níveis 1 → 5. Curva pensada para a partida de 3 min: um jogador com farm médio chega ao nível 4 por volta de 1:20–1:40.
- Por nível: +8% HP máximo, +6% dano de AA e de habilidades, cura completa NÃO (só o bônus de HP máx é adicionado como HP atual).
- **A ultimate destrava no nível 4** — na prática, entre 1:15 e 1:45 dependendo do farm. Isso cria dois atos claros: early game de poke/farm com Q, late game de all-in com ults + dragão. Alternativa por timer fixo (todas as ults liberam aos 90 s) é aceitável como flag em `balance.ts` para playtest — implemente as duas e deixe a por nível como default.
- Sem gold, sem itens. A progressão é só XP/nível. Simplicidade é feature.
- **Respawn**: 3 s no minuto 0, escalando linearmente até 8 s no minuto 3 (e mantendo 8 s no sudden death). Respawn na própria base.

## 9. Dragão

- **Spawna aos 2:00** (início do último minuto) no pit central, com anúncio visual + aviso 10 s antes ("Dragão em 10s" no HUD).
- Stats: HP 1.800, dano 100/AA, não sai do pit (leash), reseta e cura se ninguém o atacar por 4 s.
- Recompensa para o time que der o último hit: **buff de equipe por 45 s** — +25% de dano (AA e habilidades) para os heróis + as próximas 2 waves de minions do time nascem reforçadas (+50% HP e dano).
- O dragão é o mecanismo de desempate natural do último minuto: quem ganha o dragão geralmente fecha o jogo. Ajuste o buff em playtest para que ele seja decisivo mas não auto-win.

## 10. Fim de partida e sudden death

Vitória imediata a qualquer momento: destruir a **base** inimiga.

Aos 3:00, se nenhuma base caiu:
1. Time com **mais torres destruídas** vence.
2. Empate em torres → **sudden death de até 2:00**: a primeira estrutura (torre ou base) destruída decide a partida. Waves reforçadas (ver §6). Todas as ults ficam com CD reduzido em 30%.
3. Se ninguém destruir nada no sudden death: vence o time com maior % agregado de HP de estruturas. Empate absoluto → empate declarado (raro; aceite o empate).

## 11. Controles (touch)

- **Joystick virtual flutuante** no lado esquerdo (aparece onde o polegar toca).
- Lado direito: 3 botões — **AA** (grande, embaixo), **Q**, **R**. Cooldown mostrado como preenchimento radial no próprio botão + número de segundos.
- Habilidades de mira (skillshots): **tap** = cast rápido na direção do inimigo mais próximo; **segurar e arrastar** = mira manual com telegraph desenhado no mapa; soltar = cast; arrastar de volta para o botão = cancelar.
- Desktop fallback: WASD move, mouse mira, botão esquerdo AA, Q/R no teclado.
- Zona morta e suavização no joystick; botões com área de toque generosa (mín. 64 px).

## 12. HUD minimalista

Como o mapa inteiro é visível, NÃO existe minimapa. O HUD se limita a:
- **Timer central no topo** (contagem regressiva 3:00 → 0:00; em sudden death, muda de cor e conta 2:00 → 0:00).
- **Placar de kills** discreto ao lado do timer (azul × vermelho).
- **Barras de HP flutuantes** sobre cada unidade (heróis com barra maior + nível num círculo; minions com barra mínima; estruturas com barra e %).
- Botões de ação (§11) e nada mais. Sem painéis, sem retratos, sem feed de eventos permanente — eventos importantes (kill, torre destruída, dragão) aparecem como **banner central de 1,5 s** e somem.
- Indicador sutil de "você está invisível" quando o jogador está em bush (borda da tela ou glow no herói).

## 13. Animações e game feel (juice)

Isso é o que separa protótipo de jogo. Implemente:
- **Telegraphs**: toda skill de área/linha desenha a zona de impacto antes do hit (semi-transparente, cor do time).
- **Hitstop** de ~40 ms em acertos de habilidade; **screen shake** curto em ults, morte de herói e queda de torre.
- **Números de dano flutuantes** (branco AA, amarelo habilidade, roxo ult, verde cura) subindo e esvaindo.
- Partículas simples em Canvas: impacto de AA, rastro de dash, explosões de ult, fogo do dragão, folhas ao entrar no bush.
- Animação por código (tween/easing), sem sprites externos na v1: heróis como formas geométricas distintas com identidade visual clara por cor/silhueta (tanque = hexágono largo, atirador = losango, assassino = triângulo, suporte = círculo). Se quiser evoluir para sprites depois, a camada de render isolada permite.
- Morte de herói: fade + partículas; respawn com anel de spawn e 0,5 s de invulnerabilidade.
- Feedback tátil: `navigator.vibrate` curto em kill/morte (se suportado).

## 14. Bots (IA)

Máquina de estados simples por bot, com "tick" de decisão a cada 300 ms:
- **FARM**: seguir a wave aliada, atacar minions, manter distância segura da torre inimiga.
- **POKE/TRADE**: se herói inimigo em alcance e HP próprio > 50%, trocar dano com Q + AA.
- **ALL-IN**: se inimigo < 35% HP e ult disponível, comitar.
- **RETREAT**: HP < 30% → recuar para trás da torre aliada; usar bush para quebrar visão.
- **OBJETIVO**: aos 2:00, convergir para o dragão se o time estiver vivo e com HP > 50%; contestar se o inimigo começar o dragão.
- **PUSH**: com vantagem numérica (inimigo morto) ou buff do dragão, empurrar torre.
- **LANES (só Mapa B)**: atribuição inicial de 1 herói por lane. Gatilhos de rotação pelo conector central: aliado iniciou all-in, torre aliada sob dive, dragão vivo/contestado, lane inimiga vazia (inimigo sumiu do mapa visível). O bot deve preferir rotacionar passando pelos bushes do mid para esconder a intenção.
Dificuldade única na v1, mas deixe os thresholds em `balance.ts`.

## 15. Critérios de qualidade

- 60 fps estáveis num celular mediano (teste com throttling de CPU 4× no DevTools).
- Zero uso de `setInterval` para lógica de jogo — tudo dentro do loop com timestep fixo e acumulador.
- Partida completa (menu → jogo → resultado → rematch) sem reload da página e sem vazamento de memória entre partidas.
- Código legível: simulação testável sem browser (as funções de `src/sim/` devem rodar em Node puro).

## 16. Plano de execução — milestones

Trabalhe milestone a milestone. Ao final de cada um, me mostre o jogo rodando e os critérios de aceite atendidos antes de seguir.

**M1 — Fundação e mapas (core loop técnico)**
Game loop com timestep fixo, **motor de mapa data-driven renderizando os DOIS layouts** (Mapa A e Mapa B, alternáveis por flag/seleção sem mudar código), herói placeholder movendo por joystick touch + teclado, colisão com paredes.
Aceite: alternar entre os dois mapas e mover o herói por ambos a 60 fps no mobile, tudo visível e legível em landscape.

**M2 — Combate base**
Minions com waves e IA, torres atacando com prioridade e ramp, AA com auto-aim, HP/morte/respawn, XP e níveis, timer de partida e condição de vitória por base.
Aceite: deixar o jogo rodando sem input e as waves se enfrentam de forma crível; matar minions dá XP e sobe nível.

**M3 — Heróis completos**
Os 4 heróis com Q e R, telegraphs, destravamento de ult por nível, sistema de mira tap/arrastar, buffs e debuffs (stun, slow, reveal).
Aceite: cada habilidade funciona conforme §7, com telegraph e cooldown no botão.

**M4 — Mecânicas de mapa e desfecho**
Bushes com regra de visão completa, dragão com spawn/leash/buff, sudden death com regras do §10, waves reforçadas, tela de resultado + rematch.
Aceite: partida completa de ponta a ponta com todos os desfechos possíveis testados (base, torres, sudden death, empate).

**M5 — Bots, juice e tuning comparativo**
IA dos 3 bots (§14), todo o pacote de game feel (§13), HUD final (§12), passe de balanceamento jogando **ao menos 8 partidas em CADA mapa** e ajustando `balance.ts` (documente cada mudança e o porquê num `BALANCE_NOTES.md`). Feche o `BALANCE_NOTES.md` com uma seção comparativa: duração média de partida, kills por partida, frequência de contestação do dragão e % de partidas indo a sudden death em cada mapa, mais sua recomendação fundamentada de qual layout deve ser o principal.
Aceite: uma partida contra bots é disputada em ambos os mapas, termina em ~3 min na maioria das vezes, e o dragão é contestado com frequência.

## 17. Como quero que você trabalhe

- Antes de M1, me apresente a estrutura de pastas e o modelo de entidades que pretende usar. Espere meu OK.
- Decisões de design não especificadas aqui: decida você, mas registre num `DECISIONS.md` com uma linha de justificativa.
- Nunca quebre os diferenciais do §1. Se alguma spec conflitar com performance ou prazo, me pergunte em vez de cortar silenciosamente.
- Commits pequenos por feature, mensagem descritiva, um commit no fechamento de cada milestone.
