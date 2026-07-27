# DECISIONS — decisões de design não especificadas (§17)

Cada linha: a decisão e a justificativa em uma linha.

## Desvio de stack (aprovado pelo usuário)

- **JavaScript puro em vez de TypeScript + Vite**: a máquina não tem Node e a instalação exigia
  admin; o usuário optou por "sem Node". O jogo abre com 2 cliques no `index.html` (scripts
  clássicos funcionam em `file://`). A estrutura de pastas, a separação sim/render e o timestep
  fixo da spec foram mantidos integralmente; o namespace global `MOBA` substitui os imports.
- **Simulação testável sem browser**: mantida — `src/sim/` não toca DOM (verificado por busca);
  o runner headless (`src/sim/headless.js`) roda as suítes de playtest na própria página ou em
  qualquer engine JS; em Node bastaria concatenar/`require` os arquivos de `sim/` + `config/`.

## Simulação / regras

- **Comandos amostrados antes de qualquer update de herói**: elimina vantagem de informação para
  quem age depois no tick (bug de simetria encontrado no playtest) e espelha o modelo de servidor
  autoritativo futuro.
- **Habilidades não acertam estruturas**: padrão do gênero; torres caem por AA (+ minions
  tankando), mantendo o papel dos minions (§6).
- **Dragão imune a stun/slow**: chefe neutro; CC nele deixaria o leash/reset inconsistente.
- **Cura do Sol não escala com nível**: §8 dá +6% a DANO; curas ficam fixas para o suporte não
  virar bola de neve.
- **Orbe Solar**: colide com heróis/minions/dragão inimigos (dano) e com HERÓIS aliados feridos
  (cura); aliado com HP cheio não bloqueia o projétil, senão a Q "desperdiçaria" no tank full.
- **Velocidade de ataque** (não especificada): Brutus 0,9s, Lyra 0,8s, Nix 0,7s, Sol 0,9s por
  ataque — calibradas p/ TTK 4–6s em trade justo (§7) considerando os HPs dados.
- **Respawn cura 100%**: padrão do gênero; o "cura completa NÃO" do §8 refere-se ao level up
  (implementado: só o delta de HP máximo é somado).
- **XP de minion dividido igualmente** entre aliados no raio de 400u; se nenhum herói está no
  raio, o XP se perde (punir farm ausente). Kill 55 / assist 28 (janela de 5s) / torre 60 p/ cada
  herói do time.
- **Ramp da torre com teto de +100%** (4 stacks): dive continua punido sem one-shot instantâneo.
- **Pit do dragão NA lane do Mapa A**: consequência literal do §4 (pit no centro exato + lane
  única passando pela arena central); o efeito colateral (dragão no meio do fluxo) está medido e
  discutido no BALANCE_NOTES.
- **Minions podem ser atordoados** (Investida); dragão não.
- **Fonte de cura na base** (adição fora da spec, a pedido do playtest humano): 8%/s do HP máximo
  num raio de 110u da própria base, em pulsos de 0,5s — recuar vira decisão tática e dive na
  fonte é punido pela torre + regeneração do defensor.
- **Mapa B com selva** (redesenho a pedido do playtest humano): os 2 blocões entre as lanes
  viraram 6 rochas pequenas em simetria de ponto com corredores ≥90u + 2 bushes de emboscada nos
  bolsões (o §4-B pede 4 bushes; os 4 originais foram mantidos e os 2 extras estão documentados
  como desvio consciente). Movimento ganhou deslize de quina; bots recuam até a fonte.
- **Empate absoluto aceito** (§10): implementado e sinalizado na tela de resultado; não ocorreu
  em ~120 partidas de bots.

## Pacote "melhor jogo possível" (pedido do usuário)

- **Parceiro escolhível + dificuldade**: o menu ganhou a linha "Parceiro (bot)" (qualquer um dos 4,
  inclusive repetido) e o seletor Fácil/Normal/Difícil. A dificuldade afeta SÓ os bots inimigos
  (aliado é sempre Normal) e vive em `BAL.difficulty`: tempo de reação, erro de mira em skillshot,
  alcance de percepção, covardia/agressividade, chance de usar habilidade (Fácil "esquece" 45%)
  e multiplicador de dano do time (0,85× / 1× / 1,12× — prática padrão do gênero). Validado em
  espelhos: Fácil perde 2-8, Normal 4-6, Difícil vence 6-4 vs time normal; o modo Normal reproduz
  bit a bit o comportamento calibrado anterior.
- **Cerimônia de abertura**: painéis VOCÊS × INIMIGOS com os heróis apresentados, contagem
  3-2-1-LUTE! com bipes; simulação parada e controles travados durante a contagem; toque pula.
- **MVP e tabela pós-partida**: dano causado (sem overkill), cura feita (fonte não conta) e farm
  (last hits) acumulados por herói na sim; MVP = melhor nota do time vencedor
  (kills×3 + assist×1,5 + dano/250 + cura/200 + farm×0,6), coroa + destaque dourado.
- **Acessórios por código** (sem sprites, §13 preservado): Brutus elmo+pluma+escudo que avança no
  golpe; Lyra arco cuja corda puxa ao recarregar e solta ao atirar (flecha nocada visível);
  Nix capuz + adagas que cruzam no ataque; Sol auréola flutuante + raios que flaram ao castar.
  Mesmos desenhos no jogo, no menu e na apresentação.

## Mapa C "Travessia" e orientação POR MAPA (pedido do usuário)

- **Acréscimo, não mudança**: os mapas A/B seguem deitados e intocados; o C é RETRATO
  (900×1600, você embaixo de azul), inspirado na referência de arte do usuário (rio, pontes,
  ilha do dragão). O motor passou a suportar **orientação por mapa**: o encaixe de tela usa o
  tamanho do mapa ativo (`renderer.setArena`), e o aviso de "girar o celular" pede a orientação
  DO MAPA (só em telas pequenas; desktop faz letterbox).
- **Rio como parede de água**: paredes com `type:'water'` bloqueiam movimento/navegação como
  qualquer parede, mas são desenhadas chatas (rio) na camada estática; `map.bridges` são
  decoração de tábuas sobre as travessias (a passagem em si é o vão entre as águas).
- **IA independente de orientação**: lane de uma posição agora é a de waypoint mais próximo, e
  o progresso de avanço usa o eixo do mapa (`map.axis: 'x'|'y'`). Validado: 8 partidas headless
  no C (2:51 de média, 13% de morte súbita, dragão 100% contestado, zero travadas) e Mapa B
  re-verificado sem regressão.

## App instalável (PWA) — pedido do usuário: "jogar em tela cheia no celular"

- **PWA em vez de Capacitor/loja** (decisão discutida): `manifest.json` + `sw.js` dão ícone na
  tela de início, abertura **sem barra de navegador** e jogo **offline**, sem Node, sem Android
  Studio/Xcode, sem custo de loja. O caminho Capacitor continua aberto no futuro (o jogo é web
  estático) e nada aqui o atrapalha.
- **`display: "fullscreen"`** com fallback `standalone`; **`orientation: "any"`** de propósito —
  temos mapas deitados (A/B) e em pé (C), então travar orientação quebraria metade do jogo.
- **Tela cheia também sem instalar**: `requestFullscreen()` disparado no toque em JOGAR (precisa
  de gesto do usuário); falha silenciosa no iPhone, onde o caminho é instalar.
- **Estratégia de cache**: código = rede primeiro (atualização publicada aparece na hora, sem o
  clássico "atualizei e continua velho"), imagens = cache primeiro. Ao publicar, subir `CACHE`
  em `sw.js` é opcional mas recomendado.
- **`file://` preservado**: o service worker só é registrado em http(s), então abrir o
  `index.html` com 2 cliques continua funcionando igual.
- **Ícones** gerados por script a partir da arte do Brutus (192/512/maskable/apple-180/favicon).

## Apresentação / controles

- **Direção de arte "toy/cartoon"** (pedido do usuário, referência Clash Royale): arena clara de
  grama em xadrez com caminhos de terra, sombras sob as unidades, contorno grosso, gradiente de
  luz de cima, **olhos com piscada** e bounce ao andar, torres de pedra com cúpula do time e
  bandeirinha tremulando, bases como castelinhos, pit rochoso com brasas, HUD com molduras
  douradas. Continua 100% desenhado por código no Canvas (sem sprites, §13) e mexeu SÓ na camada
  de render — a simulação não mudou em nada.
- **Projeção inclinada 2.5D** (pedido do usuário, ref. Brawl Stars): a câmera olha o campo de
  cima e por trás — o CHÃO é achatado verticalmente (`TILT = 0.8`; círculos de alcance/zonas
  viram elipses), objetos têm ALTURA subindo da própria sombra (paredes extrudadas com face
  frontal, torres-cilindro, castelos com alicerce, unidades com os pés na sombra) e o desenho é
  ordenado por profundidade (painter: quem está mais ao sul cobre quem está atrás — herói atrás
  de rocha fica escondido pela pedra). A inclinação é pelo eixo VERTICAL para manter a simetria
  azul/vermelho perfeita. Entrada compensa a projeção (mira do mouse/arrasto e joystick divididos
  pelo tilt) — a simulação continua 2D pura e intocada; é 100% câmera.

- **Hitstop congela a simulação, não o render** (40ms): partículas e HUD continuam vivos, o
  impacto "morde" sem a tela travar.
- **Números de dano só em heróis/estruturas/dragão**; minions recebem faísca — 30+ floats de
  dano de minion por wave viravam ruído.
- **Menu e resultado desenhados no próprio canvas**: um único caminho de render, zero DOM extra,
  e o rematch nunca recarrega a página (§15).
- **Escala de UI limitada em desktop** (`uiScale ≤ 1,15`): os botões touch dimensionados p/ 64px
  móveis ficavam gigantes em monitor.
- **Retrato (celular em pé)**: overlay "gire o celular" e simulação pausada — o jogo é landscape
  por decisão fechada da spec (§2).
- **Aliado escolhido automaticamente** (Sol para qualquer pick; Lyra se o jogador pegar Sol) e
  dupla inimiga sorteada: tela de seleção enxuta (§3); duplas inimigas podem repetir heróis do
  time azul, nunca dentro do próprio time.
- **Áudio 100% sintético via WebAudio** (`src/render/audio.js`, adicionado a pedido do usuário):
  osciladores + ruído filtrado, zero arquivos externos; consome os mesmos eventos da sim que o
  `effects.js`. Rate-limit por tipo de som + compressor no master p/ teamfight não virar ruído;
  destrava no primeiro gesto (regra dos navegadores); mudo pela tecla M ou botão no HUD,
  persistido em `localStorage`.
- **`navigator.vibrate`** só em abate/morte do jogador (suporte varia; falha silenciosa).

## Processo

- **Playtest do M5 via bots** (ver metodologia no BALANCE_NOTES): sem humano disponível no
  ambiente; as suítes são reproduzíveis por seed e rodáveis no console (`__moba.runSuite`).
- **Servidor local (`python -m http.server`) usado apenas durante o desenvolvimento** para as
  ferramentas de inspeção; o jogo em si não precisa de servidor.
