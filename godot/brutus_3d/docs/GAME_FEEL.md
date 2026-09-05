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
- Sinais novos: `action_started(kind)` e `shield_returned`, usados pelo áudio.

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
