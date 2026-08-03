# Especificação do mapa oficial — Travessia

## Papel da arena

Travessia é o mapa canônico da Alpha 1: retrato, compacto, simétrico e construído para empurrar as equipes a decisões frequentes. As duas lanes dão clareza; o eixo central e o dragão criam conflito transversal.

## Dados canônicos

- Arena lógica: 900 × 1600 unidades.
- Time azul nasce ao sul; vermelho ao norte.
- Duas lanes verticais, uma torre por time em cada lane.
- Bases no centro de cada extremidade.
- Rio entre y=760 e y=840.
- Pontes nas lanes e ilha/acesso central para o dragão.
- Quatro bushes e quatro blocos leves de selva/rocha.
- Gating `anyTower`: ao menos uma torre inimiga precisa cair antes da base.

## Fluxo pretendido

- 0:00–0:45: encontro das waves e leitura do adversário.
- 0:45–2:00: pressão de torres, rotações pelos bushes e progressão de nível.
- 2:00: dragão aparece e força decisão entre objetivo central e pressão lateral.
- 2:00–3:00: buff do dragão ou vantagem estrutural deve abrir janela de finalização.
- 3:00+: apenas quando necessário, desempate e morte súbita.

## Regras de legibilidade

- Caminhos jogáveis devem parecer caminháveis; água e rochas devem parecer bloqueios.
- Pontes, torres, bases e pit do dragão precisam ser reconhecidos sem texto.
- Bush deve comunicar ocultação e seus limites devem ser compreensíveis.
- Decoração nunca pode sugerir uma colisão inexistente.
- HUD e controles não devem esconder o dragão ou a primeira torre do time azul em retrato comum.

## Checklist de teste

- Minions das duas lanes atravessam todo o trajeto sem travar.
- Bots conseguem alcançar ambas as torres, bases e dragão.
- Heróis não atravessam água ou rochas.
- Todos os corredores acomodam herói e minions sem bloqueio permanente.
- As duas equipes têm resultados estatisticamente próximos em várias seeds.