# Física de movimentação da Travessia

## Regra

Personagens móveis só podem ocupar zonas caminháveis definidas por dados. O PNG
do mapa é apresentação visual e não determina a colisão.

Zonas liberadas na Alpha 1:

- lane esquerda e lane direita, incluindo as pontes laterais;
- praças das duas bases;
- lane central contínua entre cada base e os portões do rio;
- corredor lateral aberto entre a lane esquerda e o acampamento superior
  esquerdo;
- pontes centrais e ilha do dragão somente depois que o ovo choca.

Água, jungle decorativa, margens e exterior do mapa são bloqueados.
As muralhas superior e inferior usam limites elípticos que acompanham sua curva,
evitando passagem pelos cantos. Cada lane lateral é dividida em estrada norte,
ponte e estrada sul; o trecho da ponte é mais estreito para impedir que metade do
personagem fique sobre a água.

## Resolução

`TravessiaDefinition` contém os retângulos e o círculo caminháveis. Jogador e
heróis-bot usam a mesma função de resolução depois de `move_and_slide()`:

1. movimento válido é aceito;
2. ao tocar uma borda, os eixos são resolvidos separadamente para deslizar;
3. investidas usam uma busca até o último ponto válido, evitando atravessar a
   borda em um único frame;
4. atores encontrados fora do mapa são recuperados para o ponto caminhável mais
   próximo.

A colisão considera o raio da cápsula do personagem, portanto o centro não pode
chegar até a borda visual e deixar metade do corpo sobre água ou floresta.

## Colisão entre unidades

Personagens e minions usam a camada 2 e consultam somente a camada 1 do mapa.
Eles não colidem, empurram nem bloqueiam uns aos outros; as restrições físicas
existem apenas nas bordas e zonas proibidas da Travessia.

Os minions mantêm o deslocamento reto na lane. A prioridade de alvo é:

1. minion ou herói inimigo próximo e alcançável no mesmo eixo da lane;
2. torre inimiga da lane;
3. base inimiga, depois que as torres forem destruídas.

## Evento do dragão

Antes do nascimento, as duas passagens centrais e a ilha não participam da
máscara caminhável. `TravessiaMap.is_dragon_access_open()` libera essas zonas no
mesmo evento que monta as pontes.

## Teste

`tools/test_walkable_physics.gd` cobre lane, água, jungle, limites externos,
deslizamento, recuperação, investida, bots e abertura dinâmica do dragão.
