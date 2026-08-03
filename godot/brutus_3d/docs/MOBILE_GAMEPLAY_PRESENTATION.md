# Apresentação e movimento mobile

## Direção de jogo

A referência de controle é um arena brawler mobile: resposta imediata ao analógico,
mudança de direção rápida, leitura clara das ações e pouca interface sobre o campo.
O objetivo não é copiar conteúdo de outro jogo, mas seguir essa linguagem de uso.

## Movimento do Brutus

- velocidade-base: `3.0` unidades por segundo de simulação;
- aceleração: `18.0`;
- frenagem: `24.0`;
- resposta de rotação: `20.0`;
- força do analógico controla a velocidade; direção completa usa a velocidade máxima;
- escala visual no mapa inteiro: `0.72`;
- colisão: cápsula de raio `0.42` e altura `1.72`.

O ritmo global da partida continua em `50%`. Os valores de resposta acima são altos
deliberadamente para o controle continuar ágil mesmo com esse ritmo mais cadenciado.

## Limites do mapa

`TravessiaDefinition.PLAYABLE_HALF_EXTENTS` define a área jogável em `X/Z`:
`(8.30, 16.25)`. Paredes físicas permitem deslizamento pelas bordas e uma trava
lógica após cada movimento impede que ataques, lunges ou dashes atravessem o limite.

## HUD em partida

Elementos permanentes:

- vida compacta do jogador no topo;
- tempo e vida do núcleo inimigo em uma única linha;
- analógico;
- ataque, Q e R com cooldown.

Elementos removidos durante a partida:

- título do projeto;
- instruções textuais;
- porcentagem do analógico e ritmo;
- rodapé de protótipo;
- nomes e percentuais sobre os bots.

Anúncios aparecem apenas por tempo limitado para eventos como torre destruída,
morte, retorno, vitória ou derrota.
