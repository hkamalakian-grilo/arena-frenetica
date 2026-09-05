# Arena Frenética — correções do playtest de 10/08/2026

## Diagnóstico reproduzido

O playtest automatizado anterior terminou aos `01:34`: apenas a torre vermelha
esquerda caiu, a torre direita permaneceu inteira e o exército azul acumulou onze
minions contra três. A torre principal abriu após uma única torre, permitindo que
a partida acabasse antes do dragão nascer. Com `Engine.time_scale = 0.50`, uma
partida que chegasse a `00:00` também duraria seis minutos reais.

## Regras corrigidas

- O relógio, ondas, cooldowns e respawns usam tempo real; a partida dura três
  minutos reais.
- A torre principal abre somente depois que as duas torres de lane caem.
- Cada combinação equipe/lane admite no máximo quatro minions vivos.
- Waves nascem a cada 10 segundos reais; minions têm 240 de vida e 26 de dano.
- Torres de lane têm 1.500 de vida, 125 de dano e atacam a cada segundo de jogo.
- Torres principais têm 4.200 de vida.
- Heróis controlados por IA defendem contra minions próximos antes de retomar o
  foco em estruturas.
- As quatro junções diagonais entre bases e lanes fazem parte da máscara física.
- O dragão registra a equipe do golpe final, cura seus heróis e concede 12% de
  dano até o fim da partida.
- O fim da partida congela os atores e abre um painel com resultado e reinício.

## Fontes de verdade

- Parâmetros: `scripts/data/travessia_definition.gd`.
- Fluxo, placar, vitória e recompensa: `scripts/main.gd`.
- Priorização de IA: `scripts/arena_actor.gd` e `scripts/hero_bot.gd`.
- Física: `TravessiaDefinition.WALKABLE_RECTS`.
- Cobertura: `tools/test_match.gd`, `tools/test_walkable_physics.gd` e
  `tools/test_abilities.gd`.

Qualquer mudança futura de balanceamento deve ser seguida por uma partida completa;
testes unitários garantem regras, mas não garantem ritmo ou diversão.

## Validação após as correções

Uma nova partida foi executada no ritmo canônico de `0.50`, sem acelerar o
relógio, e terminou exatamente em `03:00` reais:

- vitória azul no desempate;
- uma torre vermelha destruída e a segunda com `1.287 / 1.500`;
- torre principal vermelha intacta e protegida;
- dragão conquistado pela equipe azul;
- placar de abates `4 × 5` e três mortes do Brutus;
- nenhum acúmulo de minions encerrou a partida sozinho.

O resultado confirma que a segunda lane e o dragão passaram a influenciar a
decisão, enquanto uma única torre não permite mais acesso antecipado ao core.
