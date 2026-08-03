# Game Design — Arena Frenética

## Visão

Arena Frenética é um MOBA mobile 2v2 de partidas curtas, leitura imediata e decisões concentradas. O jogador deve entender a situação em poucos segundos, encontrar combate rapidamente e sempre ter um objetivo claro: pressionar lane, emboscar, disputar o dragão ou finalizar uma estrutura.

## Pilares

1. **Frenético, não caótico:** pouca distância ociosa e habilidades claras.
2. **Legível no celular:** silhuetas grandes, poucos botões e feedback forte.
3. **Profundidade compacta:** posicionamento, bushes, foco de alvo e tempo do dragão.
4. **Partida completa em minutos:** abertura, crescimento, disputa central e clímax.

## Loop da partida

- Escolher herói, aliado, mapa e dificuldade.
- Avançar com as waves e disputar duas lanes.
- Ganhar XP por minions, abates, assistências e torres.
- Destravar a ultimate no nível 4.
- Decidir entre pressionar estruturas e contestar o dragão aos 2:00.
- Destruir a base inimiga ou vencer pelo desempate de estruturas; persistindo empate, entrar em morte súbita.

## Controles

- Movimento contínuo pelo joystick esquerdo ou WASD/setas.
- Ataque básico pelo botão AA, mouse ou espaço.
- Q/R com toque para alvo automático; segurar e arrastar para mira manual.
- A mira volta ao botão para cancelar.

## Elenco Alpha 1

### Brutus — tanque/iniciador

- Fantasia: cavaleiro pesado que abre combate e protege espaço.
- AA: corpo a corpo, 60 de dano, alcance 90, período 0,78 s.
- Q — Investida: dash de 350, 80 de dano e stun de 0,8 s; cooldown 7 s.
- R — Escudo Bumerangue: arremesso linear que causa 160 de dano, desacelera e retorna ao Brutus; alcance 520 e cooldown 35 s.
- Risco: errar a entrada e ficar distante do aliado.

### Lyra — atiradora

- Fantasia: dano sustentado à distância e controle de corredor.
- AA: 72 de dano, alcance 305, período 0,75 s.
- Q — Flecha Perfurante: projétil de alcance 600 que atravessa minions; cooldown 6 s.
- R — Chuva de Flechas: área persistente de dano; cooldown 40 s.
- Risco: pouca segurança quando alcançada.

### Nix — assassino

- Fantasia: aproximação explosiva e execução de alvos frágeis.
- AA: 90 de dano corpo a corpo, período 0,62 s.
- Q — Passo Sombrio: teleporte de 300 e bônus no próximo golpe; cooldown 8 s.
- R — Execução: 280 de dano, dobrado abaixo de 35% de vida; cooldown 50 s.
- Risco: depende do momento correto de entrada.

### Sol — suporte

- Fantasia: sustentar o parceiro e transformar uma área em território aliado.
- AA: 62 de dano, alcance 300, período 0,8 s.
- Q — Orbe Solar: causa 100 a inimigo ou cura 140 em aliado; cooldown 7 s.
- R — Zona Radiante: cura, acelera aliados e revela a área; cooldown 45 s.
- Risco: baixo poder de finalização sozinho.

## Economia de poder

Não há ouro ou loja na Alpha 1. O poder vem de XP, níveis, controle de estruturas e buff temporário do dragão. Isso reduz carga cognitiva e deixa os testes focados no combate.

## Métricas para playtest

- Duração e causa do fim da partida.
- Número de abates por time e diferença final de torres.
- Frequência e time vencedor do dragão.
- Dano, cura, farm e K/D/A por herói.
- Quantas vezes o jogador usou Q/R e quantas acertou.
- Avaliação subjetiva de 1 a 5 para movimento, clareza e diversão.
