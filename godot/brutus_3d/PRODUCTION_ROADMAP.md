# Arena Frenética — plano de produção no Godot

Este projeto Godot é a base oficial do jogo. A versão HTML permanece preservada
somente como referência jogável de ideias, regras e balanceamento; ela não define
o limite de qualidade visual, animação ou arquitetura do produto final.

## Vertical slice atual

Objetivo: provar uma partida curta e divertida antes de multiplicar conteúdo.

- mapa Travessia orientado a dados, com duas lanes, rio, torres, bases e dragão;
- câmera MOBA em retrato e controle 360° por teclado ou analógico touch;
- Brutus 3D autoral com caminhada, corrida, combo básico, Investida e Escudo Bumerangue;
- minions em trajetória reta, combate contra estruturas, morte, respawn e vitória;
- testes headless cobrindo locomoção, habilidades, objetivos e encerramento da partida.

Os blocos simples usados em chão, pedras, minions, torres e bases são *greybox*.
Eles existem para validar escala, leitura, distâncias e ritmo, e serão substituídos
sem mudar as coordenadas canônicas mantidas em `TravessiaDefinition`.

## Ordem de produção

1. **Combate do Brutus** — sensação de peso, cancelamentos, mira, hitboxes, feedback,
   câmera, partículas, áudio e ausência de bugs.
2. **Partida mínima completa** — uma lane representativa, uma torre, waves e um bot
   capazes de produzir uma luta repetível e divertida em aparelho mobile.
3. **Travessia completa** — navegação, jungle pequena, dragão, buffs, duas lanes,
   bases, arte modular, iluminação e otimização.
4. **Elenco inicial** — Lyra, Nix e Sol usando componentes reutilizáveis de
   movimento, atributos, dano, projéteis, áreas e estados.
5. **Alpha jogável** — onboarding, seleção de herói, HUD final, áudio, configurações,
   métricas de desempenho, exportação Android e sessões extensas de teste.
6. **Multiplayer** — somente após bots e partida local estarem estáveis e divertidos;
   simulação autoritativa e sincronização são tratadas como uma fase própria.

## Critério para sair da vertical slice

- Brutus responde bem no touch e não desliza visualmente;
- ataques e habilidades deixam claro antecipação, impacto e recuperação;
- nenhuma habilidade cria dano, projétil ou efeito fantasma ao ser interrompida;
- uma partida contra bots permanece funcional do início até vitória ou derrota;
- 60 FPS no aparelho-alvo intermediário, sem crescimento contínuo de memória;
- regras centrais passam nos testes automatizados e no playtest humano.
