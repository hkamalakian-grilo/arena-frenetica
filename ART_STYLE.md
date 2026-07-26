# ART_STYLE — Arena Frenética (guia de arte / "art bible")

Referência visual aprovada pelo dono do projeto (2 imagens geradas por IA: uma "art bible"
em pôster + uma cartela de assets). Este arquivo registra as **decisões** de estilo e a
**lista de assets** a produzir. As artes são criadas fora (ChatGPT), uma por vez, em fundo
liso, e integradas ao jogo por código.

## 1. A "cara" do jogo

- **Estilo**: cartoon pintado de brinquedo (referência Brawl Stars / Clash Royale) — contorno
  escuro grosso, sombreado chapado (cel shading), luz suave vindo de cima, cores vivas e
  saturadas, acabamento "glossy".
- **Câmera**: visão **inclinada 3/4 de cima** (levemente por trás). Já implementada no render
  (`TILT = 0.8`): o chão é achatado no eixo vertical e os objetos "ficam em pé" sobre a sombra.
- **Regra de ângulo** (importante para gerar as artes):
  - Tudo que **fica em pé** (heróis, torres, base, dragão, árvores, rochas, arbustos) → desenhar
    no **ângulo 3/4 de cima**.
  - Só o **chão liso** (grama, terra, pedra, água) → visto **reto de cima** (top-down plano) e
    **tileável** (emenda invisível ao repetir).

## 2. Paleta

- **Time azul**: azuis (do royal ao claro). Herói/anel/UI do time 0.
- **Time vermelho**: vermelhos/laranjas. Time 1.
- **Ambiente**: verdes de grama, marrons de terra, cinzas de pedra.
- **Magia / VFX**: ciano, roxo, rosa, dourado.
- **Cores-assinatura dos heróis** (usadas hoje no código, mantê-las):
  - Brutus `#e8a33d` (laranja/dourado) · Lyra `#7ee08a` (verde) ·
    Nix `#b07ce8` (roxo) · Sol `#ffd166` (amarelo/dourado)

## 3. Regras de asset (para toda arte gerada)

- **Um item por imagem**, centralizado, **fundo chapado de uma cor só** (cinza claro liso),
  **sem** moldura, grade, rótulo, texto ou sombra no chão. Bordas limpas para recorte.
- **Heróis e unidades**: desenhar **virados para a direita** — o código **espelha** para o
  time vermelho.
- **Não se preocupe com o tamanho** de cada peça: o jogo escala tudo pelos dados
  (`balance.js` / mapas). Foque em fazer o item bonito, centralizado e sozinho.
- **O código cuida de**: sombra, anel/cor do time, barra de vida, número de nível, animação
  (quicar, atacar) e efeitos. A arte é só o "corpo" parado.
- **Formato**: PNG (fundo transparente se der; se vier com fundo, eu recorto).
- Guardar os arquivos-fonte/gerados em `assets/` (a criar) — subpastas por tipo.

## 4. Escala relativa (referência da art bible — o código aplica)

Herói 1.0x · Torre 3.0x · Dragão 6.0x · Árvore 2.5x · Ponte 2.5x · Arbusto 1.5x.

## 5. Lista de assets (checklist)

### Heróis (virados à direita, 3/4)
- [ ] Brutus — tanque, armadura laranja/dourada, elmo com pluma, escudo redondo
- [ ] Lyra — atiradora, capuz/roupa verde, arco de madeira, aljava
- [ ] Nix — assassino, capuz roxo escuro sobre os olhos, duas adagas
- [ ] Sol — suporte/maga, manto amarelo/dourado, auréola brilhante

### Construções (3/4, em pé)
- [ ] Torre azul · [ ] Torre vermelha (torre de pedra + cúpula/bandeira do time)
- [ ] Base azul · [ ] Base vermelha (castelo/fortaleza com bandeira do time)
- [ ] Dragão (laranja, chifres, asas — 3/4 de cima)
- [ ] Altar/pit do dragão (cratera rochosa com brasa/ovo no centro — peça de chão)

### Chão (top-down PLANO, tileável)
- [ ] Grama · [ ] Terra (caminho) · [ ] Pedra · [ ] Água (opcional)

### Enfeites (3/4, em pé)
- [ ] Árvore · [ ] Arbusto (moita) · [ ] Rochas grandes (parede) · [ ] Rochas pequenas
- [ ] Flores · [ ] Ponte (opcional)

### Ícones de habilidade (frontal, circular, símbolo chapado)
- [ ] Brutus Q Investida · [ ] Brutus R Terremoto
- [ ] Lyra Q Flecha Perfurante · [ ] Lyra R Chuva de Flechas
- [ ] Nix Q Passo Sombrio · [ ] Nix R Execução
- [ ] Sol Q Orbe Solar · [ ] Sol R Zona Radiante

### VFX — **feitos por código**, não gerar (fogo, gelo, raio, cura, escudo, explosão…)

## 6. Ordem sugerida de produção

1. Heróis (começar pelo Brutus, validar o encaixe) → 2. Construções (torre/base/dragão) →
3. Chão + enfeites → 4. Ícones de habilidade.

## 7. Integração (como o código consome)

A camada de render (`src/render/renderer.js`) é isolada. Ao chegar um asset, troco a forma
desenhada por código pela imagem, mantendo sombra/anel/barra/animação por código. Nada disso
muda a simulação (`src/sim/`) — é 100% apresentação.
