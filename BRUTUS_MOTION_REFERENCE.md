# Brutus — direção de movimento

Brutus é autoral. As referências do Capitão América servem para estudar peso,
silhueta e encadeamento corporal; nenhuma animação deve ser copiada quadro a
quadro, nem o personagem deve reproduzir identidade visual, poses exclusivas ou
efeitos da Marvel.

## Referências estudadas

- [Marvel — Captain America Character Spotlight](https://www.marvel.com/articles/games/marvels-avengers-character-spotlight-captain-america): escudo integrado a combinações de luta corporal.
- [Marvel — escudo do Captain America](https://www.marvel.com/characters/captain-america-steve-rogers/on-screen): arma defensiva equilibrada, arremessável e capaz de retornar.
- [Marvel Rivals — nota oficial de combate](https://www.marvelrivals.com/balancepost/20260319/41667_1292065.html): o personagem combina corrida de liderança, golpes próximos e lançamentos de escudo em uma sequência fluida.
- [Marvel Rivals — partida de Captain America](https://www.youtube.com/watch?v=aTDZBCoFlrI): referência visual secundária para corrida, investida e arremesso em gameplay.

## Regras autorais aplicadas ao Brutus

### Corrida

- Ciclo completo de 24 quadros a 30 fps: cadência atlética, mas legível.
- O peito avança; cabeça permanece estável e olhando o alvo.
- Quadril e ombros giram em sentidos opostos.
- O braço direito bombeia. O esquerdo mantém o escudo compacto perto do peito,
  com atraso pequeno causado pela inércia.
- Contato, compressão, passagem e voo existem em cada passo. Não há quique do
  corpo inteiro nem pernas funcionando como pêndulos.

### Ataque básico

- Cadeia autoral de dois golpes: direto curto com a mão direita e batida
  diagonal com o escudo.
- Cada golpe nasce do pé, passa pelo quadril e pelo ombro e termina com um passo
  curto na direção do alvo.
- Um quadro adicional de retenção no contato e efeito sincronizado vendem peso.
- O segundo comando pode ser enfileirado durante o primeiro golpe; a transição
  não retorna ao idle entre os ataques.

### Q — Investida

- Antecipação curta com centro de massa baixo e pé traseiro carregado.
- O corpo corre atrás do escudo durante toda a translação; o modelo nunca
  desliza numa pose congelada.
- Escudo protege cabeça e tronco, mas pernas, quadril e braço livre continuam
  trabalhando.
- Impacto acontece no fim da corrida, antes da recuperação.

### R — Escudo bumerangue

- Movimento começa no pé traseiro e no quadril, passa pelo tronco e só então
  chega ao braço.
- Há uma passada durante o lançamento, uma soltura clara, acompanhamento do
  braço e preparação para a recepção.
- A recepção coincide com o retorno visual do projétil; depois Brutus recompõe a
  guarda.

## Sincronização no protótipo

- Corrida: 25 quadros incluindo o primeiro quadro repetido para fechar o loop.
- Q: impulso entre 0,20 s e 0,70 s; ciclo de pernas entre os quadros 7 e 23.
- R: soltura em aproximadamente 0,58 s e recepção em aproximadamente 1,49 s.
- Ataque básico: impactos nos quadros 9–10; `attack` tem 22 quadros e
  `attack_alt` tem 23 quadros.
