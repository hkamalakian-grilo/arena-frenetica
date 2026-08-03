# Bíblia de Arte — Alpha 1

## Direção

Fantasia colorida, amigável e heroica, vista em câmera 3/4 com inclinação visual próxima de 55°. As formas são grandes, arredondadas e reconhecíveis em tela pequena. A ilustração pode ter acabamento pintado, mas nunca sacrifica silhueta e contraste de gameplay.

## Regra de estilo

- Personagens: volumes tipo brinquedo, proporções exageradas e contorno escuro seletivo para separar a silhueta do chão.
- Cenário: bordas mais suaves e menos contraste que personagens, projéteis e objetivos.
- Times: azul para aliados e vermelho para inimigos; a cor não pode ser o único sinal.
- Habilidades: antecipação, impacto e dissipação visualmente distintos.
- Evitar detalhes finos, texturas ruidosas, realismo sombrio e efeitos que cubram os controles.

## Câmera e projeção

A simulação usa coordenadas 2D. O render aplica achatamento vertical ao chão, altura visual a estruturas e ordenação pelo eixo sul-norte. Arte de personagens deve usar âncora nos pés e deixar margem transparente para ataques e efeitos.

## Escalas de leitura

1. Base e torres: maiores marcos do mapa.
2. Heróis e dragão: foco principal.
3. Minions: informação tática secundária.
4. Decoração: atmosfera sem competir com colisões ou objetivos.

## Animação de heróis

Direções lógicas, em sentido horário: leste, sudeste, sul, sudoeste, oeste, noroeste, norte e nordeste.

Estados mínimos:

- idle;
- caminhada e corrida em ciclos separados;
- dois ataques básicos: antecipação, contato e recuperação;
- Q: guarda, corrida protegida, impacto e recuperação;
- ultimate: preparação, soltura, acompanhamento e recepção;
- dano;
- morte.

O manifesto em `src/config/animations.js` mapeia colunas, linhas, duração, cadência por distância e transições. O controlador em `src/render/animation.js` consome eventos da simulação sem alterar o resultado determinístico. Brutus não usa espelhamento: todas as oito vistas são renderizações próprias do modelo 3D.

## Brutus Alpha 1

Brutus é o primeiro vertical slice: armadura dourada/laranja, elmo fechado com pluma vermelha, escudo redondo e silhueta robusta. Os dez estados — idle, caminhada, corrida, dois ataques, Q, R, recepção, dano e morte — possuem quadros autorais em frente, costas, dois perfis e quatro diagonais. Há ainda nove variantes sem escudo para o período em que o bumerangue está fora da mão, totalizando 19 atlases direcionais.

## Exportação futura

- Fundo transparente, sem sombra externa cortada.
- Todas as células no mesmo tamanho, personagem ancorado nos pés.
- Sem texto, interface ou marca-d'água.
- Validar cada pose no tamanho real de jogo, não apenas ampliada.
