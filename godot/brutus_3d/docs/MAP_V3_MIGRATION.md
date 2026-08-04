# Travessia V3 — migração para mapa 3D modular

## Decisão

A Travessia será tecnicamente 3D, com câmera ortográfica fixa e jogabilidade no
plano X/Z. A composição do mapa aprovado permanece como gabarito visual, mas a
imagem única deixa de ser a implementação definitiva.

## Primeiro componente concluído

`ModularBridge3D` estabelece o padrão para novos elementos do cenário:

- uma única cena reutilizável para qualquer ponte;
- dimensões e direção configuráveis por dados;
- fileiras do tabuleiro como geometria independente;
- colisão separada da apresentação;
- montagem animada sem esticar imagens;
- textura, rejunte e luz extraídos das pontes aprovadas do próprio mapa.

Os dois acessos usam quatro fileiras completas de três pedras, repetindo os
cursos de alvenaria da ponte lateral sem esticar a arte. O tabuleiro visual tem
a mesma proporção das pontes existentes; a colisão permanece mais larga e
independente. No acesso norte, uma correção sutil de perspectiva aumenta a
largura em direção à ilha. As extremidades avançam ligeiramente sob as bordas
existentes para não deixar água ou emendas aparentes.

## Próximas etapas

1. Criar terreno base e caminhos como malhas modulares.
2. Substituir o rio pintado por água e margens 3D.
3. Instanciar `ModularBridge3D` também nas pontes laterais.
4. Reconstruir ilha, muralhas e entradas com peças reutilizáveis.
5. Migrar vegetação e rochas para cenas instanciadas e otimizadas.
6. Remover o PNG de gabarito quando a comparação visual da V3 for aprovada.

Até a etapa 6, a imagem atual continua por baixo da geometria como referência de
posição. Isso permite migrar sem interromper os testes de combate e objetivo.
