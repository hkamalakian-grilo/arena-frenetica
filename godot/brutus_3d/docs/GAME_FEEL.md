# Sensação de jogo — camada de feedback do combate

Item 1 do `PRODUCTION_ROADMAP.md`: peso dos golpes, mira, cancelamentos e
feedback. Tudo aqui é apresentação ou regra local do Brutus; a simulação da
partida (waves, torres, dragão, relógio) não muda.

## Controle do Brutus (`scripts/brutus_controller.gd`)

- **Mira assistida.** Ataque básico e Investida viram para o melhor inimigo
  dentro de um cone à frente (ataque: 2,4 m / 110°; Q e R: 6,5 m / 70°).
  Unidades têm prioridade sobre torres. Sem alvo no cone, mantém a direção do
  analógico. Alvo escolhido fica em `last_assist_target`.
- **Buffer de comando.** Ataque, Q ou R apertados durante outra ação ficam
  guardados por 0,35 s reais e disparam assim que a ação atual pode ser deixada.
- **Cancelamentos.** Q e R cortam a recuperação do ataque básico depois que o
  golpe conectou. O recuo de dano (`hurt`) nunca come um comando.
- **Investida acerta no contato.** Durante o dash, o primeiro inimigo a 1,15 m
  recebe dano e atordoamento na hora; o impacto final cobre quem sobrou (raio
  1,85). Ninguém mais é atravessado sem ser atingido.
- **Mira manual.** `request_q(aim)` / `request_r(aim)` recebem uma direção de
  mundo; zero = quick cast com assistência. No teclado, Q/R miram no cursor do
  mouse (`mouse_world_direction()`), como no HTML.
- **Prévia de alcance.** `show_aim_preview(kind, dir)` desenha no chão a faixa
  do dash (Q, laranja) ou a linha do escudo (R, roxa) enquanto o botão é segurado.
- Sinais novos: `action_started(kind)` e `shield_returned`, usados pelo áudio.

### Números do Brutus (jogador) e por que diferem do HTML

| Stat | Godot | HTML | Motivo |
|---|---|---|---|
| Vida | 1800 | 1150 | Brutus é o único herói humano; sem XP/nível, precisa sobreviver a torre + dois bots com kit completo. |
| AA | 95 | 60 | Golpe corpo a corpo com hitstop; o combo de dois golpes precisa matar um minion (240) em três toques. |
| Q | 150 + stun 0,8 s | 80 + stun 0,8 s | Skill de entrada; acerta no contato e no fim, sem repetir alvo. |
| R | 190 + lentidão 50% / 1,6 s | 160 + 30% / 1,5 s | Ultimate de 35 s de recarga; a lentidão forte é o que permite a dupla fechar o abate. |

Revisar após o playtest humano com os kits dos bots ativos. Se o Brutus
dominar sozinho, o primeiro corte é o AA (95 → 75) e depois a vida (1800 → 1500).

## Controles touch (`scripts/ability_button.gd`, `scripts/virtual_joystick.gd`)

- **Botões de habilidade.** Tap = quick cast. Segurar e arrastar além de 14 px
  entra em mira: um "stick" aparece sobre o botão e o Brutus mostra a prévia no
  chão. Soltar lança na direção arrastada; soltar de volta sobre o botão
  cancela. O preenchimento radial escuro mostra a recarga.
- **Botão de ataque.** Dispara no toque e repete a cada 0,22 s enquanto
  segurado (auto-ataque).
- **Joystick flutuante.** A área sensível é a metade inferior esquerda da
  tela; a base aparece onde o dedo toca e acompanha quando o arrasto passa da
  borda. Um fantasma marca a posição de descanso.
- O botão R foi afastado da plataforma da torre azul direita em retrato.

## Controle de grupo (`arena_actor.gd`, `hero_bot.gd`)

- `apply_stun(s)`: Investida atordoa por 0,8 s (dragão: 40% disso). Torres,
  bases e ovo ignoram. Alvo para de andar e atacar e mostra um anel amarelo.
- `apply_slow(fator, s)`: Escudo Bumerangue reduz a velocidade a 50% por 1,6 s.
- `revive()` limpa os dois efeitos.

## Feedback (`scripts/combat_feedback.gd`)

- **Hitstop** só quando o golpe acerta: ataque 0,05 s, Q 0,08 s, R 0,11 s,
  abate 0,09 s. Restaura o `Engine.time_scale` que encontrou (respeita o ritmo
  canônico de 50%).
- **Tremor de câmera** proporcional: golpe no vazio treme pouco, acerto treme
  cheio e cresce com o número de alvos.
- **Números de dano** flutuantes (`Label3D`) sobre cada alvo atingido; dano
  recebido pelo Brutus aparece em vermelho sobre ele. Textos: `ATORDOADO`, `ABATE!`.
- **Vinheta vermelha** nas bordas ao receber dano; pulsa devagar abaixo de 30%
  de vida. O centro do mapa continua legível.

## Áudio (`scripts/arena_sfx.gd`)

Catorze efeitos sintetizados na inicialização em `AudioStreamWAV` (22 kHz,
mono): swing, hit, q_charge, q_impact, r_throw, r_impact, r_catch, hurt, kill,
death, tower_shot, tower_down, stun, dragon. Nenhum arquivo de áudio no
projeto. Tecla **M** silencia. Qualquer nó toca via
`get_tree().call_group("arena_sfx", "play", &"tower_shot")`.

## Validação

- `tools/test_game_feel.gd`: mira assistida (acerta a 35°, ignora alvo atrás),
  buffer, cancelamento do `hurt`, stun/slow, imunidade de estruturas, revive,
  hitstop, número de dano, vinheta e biblioteca de sons.
- `tools/capture_game_feel.gd`: gera `tools/travessia_game_feel_capture.png`
  para revisar a camada visual sem aparelho.
- Os testes existentes (`test_abilities`, `test_match`, `test_walkable_physics`)
  continuam passando.

Ajustes subjetivos (duração do hitstop, força do tremor, volumes) devem ser
feitos no aparelho, com o playtest humano previsto no `ALPHA_1.md`.
