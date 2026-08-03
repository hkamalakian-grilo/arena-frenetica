# Arena Frenética — Notas da Alpha 1

Data de atualização: 29/07/2026

## Entrega

- Travessia definida como mapa oficial e padrão.
- Brutus definido como herói inicial da demonstração.
- Sistema de animação visual desacoplado da simulação.
- Brutus com oito direções reais e dez estados: idle, caminhada, corrida, dois ataques, Q, ultimate, recepção, dano e morte.
- Velocidade de locomoção de heróis, bots, minions e avanços rápidos reduzida em 50%.
- Minions avançam em linha reta e focam exclusivamente a torre inimiga da própria lane; depois seguem para a base liberada.
- Brutus recebeu 19 atlases derivados do modelo 3D autoral, incluindo variantes sem escudo; quique procedural e espelhamento foram removidos.
- Passadas são sincronizadas à distância real, com transições de 100 ms entre idle, caminhada e corrida.
- Ataques, investida, soltura e recepção do escudo são sincronizados aos eventos determinísticos de combate.
- Controles touch possuem captura de ponteiro, cancelamento seguro e limpeza integral entre telas.
- Cache offline atômico inclui todos os módulos, atlases e ícones instaláveis.
- Documentos canônicos: escopo Alpha 1, game design, bíblia de arte e especificação da Travessia.

## Validação executada

- Sintaxe de todos os arquivos JavaScript: aprovada.
- `manifest.json`: válido.
- Cache offline: 75 caminhos e 69 referências de runtime cruzados, nenhum ausente.
- Controlador de animação: 19 atlases, oito direções, transições, recuperação de Q/R, recepção e morte aprovadas.
- Suíte local: 12 arquivos de teste, incluindo controles mobile e hitch artificial de 250 ms.
- Estresse do Brutus: 53.280 ticks, sem escudo órfão ou ação fantasma.
- Determinismo: duas partidas com a mesma seed produziram resultado idêntico.
- Suíte headless: 16 partidas na Travessia, zero timeout e zero empate.
- Média da suíte: 178,60 s, 27,13 abates, dragão derrotado em 100% das partidas.
- Inspeção ampliada: frente, costas, corrida, Q, dois ataques, arremesso e recepção possuem poses distintas.
- Regressão de ritmo: 24 partidas headless nos três mapas, zero timeout e zero empate.

## Próxima validação humana

Jogar no celular pelo menos três partidas com Brutus e informar:

1. se a movimentação parece rápida, lenta ou correta;
2. se personagem, projéteis e objetivos são fáceis de enxergar;
3. se Q e ultimate respondem bem ao toque/arraste;
4. se o dragão parece decisivo demais, de menos ou na medida;
5. uma nota de diversão de 1 a 5.

## Limitações conscientes

- Lyra, Nix e Sol ainda usam arte estática espelhada.
- O passe técnico do Brutus está completo; peso, ritmo e legibilidade final ainda dependem do playtest humano em celular.
- Multiplayer não pertence à Alpha 1 e deve começar somente depois do playtest e do primeiro passe de balanceamento humano.
