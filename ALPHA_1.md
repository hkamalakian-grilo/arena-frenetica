# Arena Frenética — Alpha 1

## Objetivo da versão

Entregar uma partida 2v2 contra bots que possa ser instalada no celular, jogada do menu ao placar final e repetida sem recarregar a página. A Alpha 1 valida o núcleo divertido antes de multiplayer e de uma produção completa de arte.

## Escopo fechado

- Partidas de 3 minutos, com morte súbita de até 2 minutos.
- Orientação retrato no mapa oficial **C — Travessia**.
- Quatro heróis jogáveis: Brutus, Lyra, Nix e Sol.
- Um jogador + aliado bot contra dois bots, com três dificuldades.
- Ataque básico, Q e ultimate por herói; progressão até o nível 5.
- Duas lanes, minions, quatro torres, duas bases, bushes e dragão central.
- Minions de rota previsível: avanço reto, sem aggro em unidades, com foco na torre da lane.
- Controles touch, teclado/mouse, áudio sintético, PWA e modo offline.
- Simulação determinística em timestep fixo de 60 Hz.
- Brutus como vertical slice do sistema de animação direcional.

## Critérios de aceite

1. O jogo abre sem servidor ao carregar `index.html` e como PWA quando publicado por HTTPS.
2. Menu, introdução, partida, resultado e revanche funcionam sem reload.
3. A Travessia inicia por padrão e é jogável em retrato.
4. Todos os heróis conseguem mover, atacar e usar Q/R; bots completam partidas.
5. Vitória pode ocorrer por base destruída, torres ao fim do tempo ou morte súbita.
6. O dragão nasce, pode ser derrotado e concede o buff previsto.
7. O Brutus responde visualmente a oito direções reais e aos estados idle, caminhada, corrida, dois ataques, Q, R, recepção, dano e morte.
8. A suíte headless não lança erros e é determinística para a mesma seed.
9. Código, imagens novas e shell do aplicativo estão disponíveis offline.

## Fora da Alpha 1

- Multiplayer online, contas, matchmaking e servidor autoritativo.
- Loja, monetização, ranking, passe, skins ou inventário.
- Animação direcional final de Lyra, Nix e Sol.
- Polimento final de VFX, música, dublagem e acessibilidade completa.
- Balanceamento competitivo; os números desta versão são ponto de partida para playtests.

## Ordem pós-Alpha

1. Playtest humano de 10 partidas na Travessia e registro de duração, herói escolhido, vencedor e motivo da vitória.
2. Ajuste de legibilidade, sensação de movimento, cooldowns e poder do dragão.
3. Produção direcional dos outros três heróis usando o mesmo manifesto.
4. Extração gradual de blocos reutilizáveis de habilidades e subsistemas do renderizador.
5. Somente então: protótipo de multiplayer autoritativo.

## Estado visual do Brutus

O Brutus possui 19 atlases derivados do modelo 3D autoral: dez estados completos e nove variantes sem escudo, todos em oito direções reais. Passadas avançam pela distância percorrida, idle/caminhada/corrida têm transições curtas e os quadros de contato e soltura são sincronizados aos eventos da simulação. A validação humana em celular continua sendo o critério para os últimos ajustes subjetivos de peso e ritmo.
