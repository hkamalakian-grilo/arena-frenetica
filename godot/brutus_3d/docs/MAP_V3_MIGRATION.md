# Travessia V3 — migração concluída para mapa 2.5D modular

## Resultado

A migração técnica foi concluída. A partida não usa mais a imagem única do mapa
como piso. Água, terrenos, lanes, praças de base, ilha, plataformas, pontes,
muralhas, margens, clareiras, vegetação e âncoras são módulos independentes.

A composição da arte original continua sendo a referência para direção visual,
mas agora pode ser refinada peça por peça sem comprometer a física.

## Etapas concluídas

1. Terrenos norte e sul e caminhos reconstruídos como malhas independentes.
2. Rio substituído por um plano de água com material procedural animado.
3. Pontes laterais e acessos do dragão instanciados de `ModularBridge3D`.
4. Ilha, muralhas, margens e entradas reconstruídas com peças reutilizáveis.
5. Vegetação, rochas e clareiras separadas em módulos instanciados.
6. Seis plataformas e âncoras de gameplay desacopladas do visual.
7. PNG completo removido do caminho de renderização da partida.
8. Testes de combate, física, habilidades e evento do dragão mantidos verdes.

## Estado de arte

Esta entrega resolve a arquitetura e produz uma primeira linguagem visual
coerente e editável. O polimento futuro deverá trocar materiais e módulos
individualmente, mantendo a mesma árvore e as mesmas âncoras. Não é necessário
reconstruir novamente o sistema do mapa para melhorar a aparência.

Consulte `MODULAR_MAP_ARCHITECTURE.md` para as regras permanentes.
