# Creative Playbook — Meta Ads

## 5 Creative Angles (from Tata Gonçalves case study)

### CRIATIVO 1 — "Urgência/Escassez" (REMARKETING)
- **Formato:** Vídeo curto 30-60 seg, olhando pra câmera
- **Script:** "Se você tá vendo esse vídeo é porque você já visitou minha página e não finalizou. Olha, eu entendo. Se vossas a gente tira as dúvida. Mas eu preciso te falar: as vagas são LIMITADAS e a próxima turma é [data]. Depois quando vai ter de novo. O link tá aqui embaixo, finaliza sua inscrição agora."
- **Por que funciona:** Remarketing + urgência = conversão alta. Quem abandonou checkout precisa de um empurrão.

### CRIATIVO 2 — "Antes e Depois" (FRIO)
- **Formato:** Reel tipo storytelling 45-90 seg
- **Script:** "Antes eu passava HORAS criando conteúdo, montando página, escrevendo copy... [mostra frustração]. Aí eu comecei a usar IA do jeito certo. Agora em 48 horas eu monto tudo: negócio, produto, oferta, página, anúncio, e app de copy. [mostra resultado]. Se você quer fazer o mesmo, link na bio."
- **Por que funciona:** Mostra a DOR que a pessoa sente e a TRANSFORMAÇÃO. Funciona demais pra frio.

### CRIATIVO 3 — "Depoimento de Aluno em Vídeo" (TUDO)
- **Formato:** Vídeo 30-60 seg do aluno falando direto pra câmera
- **Script exemplo:** "Eu entrei no workshop da [nome] sem saber nada de IA. Em 2 dias eu saí com meu negócio montado, minha página pronta, meus anúncios rodando. Melhor investimento que já fiz."
- **Por que funciona:** Depoimento é um criativo campeão. Vídeo de ALUNO REAL falando direto pra câmera converte mais que você falando sobre o aluno.

### CRIATIVO 4 — "Screen Recording IA ao Vivo" (FRIO + TOPO)
- **Formato:** Gravação de tela mostrando IA trabalhando
- **Script:** "Olha isso: acabei de pedir pro Claude Code criar uma campanha inteira de Facebook Ads. [mostra a tela]. Em 2 minutos ele criou tudo. Isso é o que eu ensino no meu workshop de 2 dias."
- **Por que funciona:** Prova visual é mais forte que palavras. MOSTRA ele funcionando.

### CRIATIVO 5 — "Oferta Direta / VSL Curto" (REMARKETING + FRIO)
- **Formato:** Vídeo direto ao ponto 60-90 seg
- **Script:** "Por R$ [valor] você vai passar 2 dias comigo ao vivo aprendendo a usar IA pra montar seu negócio do zero. Você vai sair com produto, oferta, página de vendas, campanhas de anúncio, e seu próprio app de copy. Sem enrolação. 100% prática. Dia [X] e [Y], das 9h às 18h, ao vivo no Zoom. Clica no link e garante sua vaga."
- **Por que funciona:** VSL curto em vídeo dizendo exatamente o que a pessoa ganha. Oferta direta.

## Creative Optimization Logic

### Semana 1: Subir tudo
- 7 campeões existentes + 5 novos = 12 criativos
- Colocar em TODAS as campanhas
- Deixar Meta otimizar por 3-5 dias

### Semana 2: Analisar
- Identificar top 3 criativos por CPA
- Identificar bottom 3 (pausar)
- Para cada campeão: criar 2-3 variações (mesmo hook, ângulo diferente)

### Semana 3+: Escalar e Testar
- Campeões → aumentar budget
- Criar novos criativos baseados nos ângulos que funcionam
- Testar novos hooks, thumbnails, primeiros 3 segundos
- Manter ciclo: criar → testar → escalar → criar

## Optimization Logic (Weekly Cycle)

### Semana 1: Subir tudo
- 7 campeões existentes + 5 novos = 12 criativos
- Colocar em TODAS as campanhas
- Deixar Meta otimizar por 3-5 dias

### Semana 2: Analisar CRIATIVO x PÚBLICO
- Desligar criativos com CPA > R$100 em cada conjunto
- Escalar os que tão funcionando (aumentar budget)

### Semana 3: Variações dos TOP 3
- Mesmo hook, ângulo diferente
- Mesmo vídeo, copy diferente
- Testar thumbnails diferentes

### Contínuo: A cada 7 dias
- Matar o que não vende
- Escalar o que vende
- Testar 2-3 criativos novos por semana

## Landing Page Integration
- Analisar URL da página de vendas pra sugerir criativos que conectam com o conteúdo
- Quando gravar criativos novos, subir direto nas campanhas via API
- Trocar link da página antiga pela nova quando atualizar

## Naming Convention
Format: `[TIPO] [PÚBLICO] [CRIATIVO] - [CAMPANHA]`
Example: `[REMKT] [Checkout 10D] [VSL Urgência] - WIA 9 IMERSÃO`

## Rules for Creative Distribution
1. **Criativo campeão vai em TODOS os ad sets** — se converte no público A, testa em B, C, D
2. **Mínimo 3 criativos por ad set** — nunca rodar com 1 só
3. **Após 1000 impressões:** se CTR < 1% → pausar
4. **Após 3 dias:** se CPA > 2x meta → pausar
5. **Criativo com 0 vendas após R$50 gasto** → pausar
6. **Criativo campeão com CPA < meta** → duplicar pra outros conjuntos
7. **Vídeo > Imagem** para remarketing (prova social, urgência)
8. **Catálogo dinâmico** para remarketing de produto (se aplicável)

## Estratégia: UTM Dinâmico + Headline Dinâmica (Landing Page Única)

**Fonte:** Instagram Reel (01/03/2026) — Método Andrômeda

### Conceito
Uma **única landing page** que troca automaticamente a headline de acordo com o anúncio clicado, usando UTM parameters. Elimina a necessidade de criar dezenas de páginas diferentes para cada segmento.

### Como funciona
1. **Cada anúncio** tem uma UTM específica no link (ex: `?utm_headline=profissionais-de-saude`)
2. **A landing page** tem um script JavaScript que lê a UTM e substitui a headline
3. **Resultado:** A pessoa vê uma página personalizada para o segmento dela, mas é a mesma página

### Implementação

**No anúncio (Meta Ads):**
```
https://suapagina.com/vendas?utm_headline=profissionais+de+saude
https://suapagina.com/vendas?utm_headline=donos+de+ecommerce
https://suapagina.com/vendas?utm_headline=social+medias
https://suapagina.com/vendas?utm_headline=infoprodutores
```

**Na landing page (JavaScript):**
```html
<script>
  const params = new URLSearchParams(window.location.search);
  const headline = params.get('utm_headline');
  if (headline) {
    const el = document.querySelector('.headline-dynamic');
    if (el) el.textContent = `Como ${headline.replace(/\+/g, ' ')} estão crescendo 10 mil seguidores`;
  }
</script>

<!-- Headline padrão (fallback) -->
<h1 class="headline-dynamic">Como profissionais estão crescendo 10 mil seguidores</h1>
```

### Vantagens
- **1 página = infinitos segmentos** — escala sem criar páginas
- **Teste AB massivo** — testa headline por segmento sem duplicar
- **Mensagem = promessa certa pra pessoa certa** — aumenta conversão
- **Manutenção zero** — muda 1 página, muda tudo
- **Combina com Advantage+** — Meta distribui os anúncios, cada um leva pra headline certa

### Variações avançadas
- Trocar **imagem hero** além da headline
- Trocar **depoimentos** de acordo com o segmento
- Trocar **CTA** (ex: "Agendar consulta" vs "Começar teste grátis")
- Usar `utm_content` e `utm_term` pra variações mais granulares
- Combinar com **Pixel events customizados** pra rastrear qual segmento converte mais

### Aplicação no DeFiZero / Degenerados
```
?utm_headline=traders+de+crypto → "Como traders de crypto estão gerando renda passiva com DeFi"
?utm_headline=investidores → "Como investidores estão diversificando com pools de liquidez"
?utm_headline=iniciantes → "Como iniciantes estão entrando no mundo DeFi do zero"
```

### Quando usar
- Produto serve múltiplos nichos/segmentos
- Quer testar qual segmento converte melhor sem criar N páginas
- Escala horizontal de anúncios (muitos ad sets com públicos diferentes)
- Campanhas Advantage+ onde Meta entrega pra públicos variados

---

## Adapting for DeFiZero / Degenerados
Replace context for crypto/DeFi niche:
- **Antes/Depois:** "Antes eu ficava perdido em crypto, sem saber por onde começar..." → "Agora eu tenho pools gerando yield 24/7"
- **Screen Recording:** Mostrar Krystal/DeFi tools funcionando ao vivo
- **Depoimento:** Membros da comunidade Degenerados mostrando resultados
- **Urgência:** "A comunidade fecha para novos membros em [data]"
- **Oferta Direta:** "DeFiZero é o curso gratuito. Degenerados é onde o jogo real acontece."
