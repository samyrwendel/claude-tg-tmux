# Campaign Templates — Ready to Deploy

## Template: Full Funnel (7 Campaigns)

### CAMPANHA 1: [REMARKETING] Checkout Abandonado — A MAIS URGENTE
- **Objetivo:** Sales (Purchase)
- **Orçamento:** R$150/dia
- **Otimização:** Conversão → Purchase
- **Plataforma:** Instagram + Facebook
- **Conjunto 1 — Checkout 10D (super quente):**
  - Público: Initiate Checkout 10D
  - Excluir: Purchase 90D
  - Advantage+: LIGADO
- **Conjunto 2 — Checkout 30D (quente):**
  - Público: Initiate Checkout 30D
  - Excluir: Purchase 90D + Initiate Checkout 10D (pra não sobrepor com conjunto 1)
- **Criativos (3):**
  1. Vídeo de urgência — "Você começou a inscrição mas não finalizou. As vagas estão acabando"
  2. Depoimento forte — usar criativo que mais vendeu
  3. Catálogo dinâmico — se disponível
- **CPA esperado:** R$5-15

### CAMPANHA 2: [REMARKETING] VV 95% + Perfil Visitors — Público Super Engajado
- **Objetivo:** Sales (Purchase)
- **Orçamento:** R$100/dia
- **Otimização:** Conversão → Purchase
- **Plataforma:** Instagram (Feed, Stories, Reels)
- **Conjunto 1 — VV 95% recente:**
  - Público: VV 95% 30D + Visitaram perfil IG 30D
  - Excluir: Page View Site 30D + Initiate Checkout 30D + Purchase 90D
  - Só Instagram, Android + iOS, 25-55
- **Criativos (3):**
  1. Best seller creative (maior número de vendas)
  2. Creative com menor CPA
  3. Remarketing-specific creative
- **CPA esperado:** R$15-30

### CAMPANHA 3: [ADVANTAGE+] Shopping Máquina de Vendas
- **Objetivo:** Sales (Purchase)
- **Orçamento:** R$300/dia
- **Otimização:** Meta otimiza (Advantage+ Shopping)
- **Plataforma:** Todas
- **Config:** Advantage+ LIGADO, sem segmentação manual
- **Criativos:** Todos os 12 campeões — Meta escolhe
- **CPA esperado:** R$15-25
- **NOTA:** A partir de v25 (fev 2025) Advantage+ Shopping não pode mais ser criado via API — criar via Ads Manager

### CAMPANHA 4: [FRIO QUALIFICADO] LAL Compradores
- **Objetivo:** Sales (Purchase)
- **Orçamento:** R$200/dia
- **Otimização:** Conversão → Purchase
- **Plataforma:** Instagram + Facebook
- **Conjunto 1 — LAL 1% Purchase:**
  - Público: Lookalike 1% de Purchase 90D
  - Excluir: Todos os custom audiences de remarketing
  - Idade: 25-55, Brasil
- **Conjunto 2 — LAL 2% Purchase:**
  - Público: Lookalike 2% de Purchase 90D
  - Excluir: LAL 1% + remarketing
- **Criativos:** 5 melhores + variações
- **CPA esperado:** R$30-50

### CAMPANHA 5: [FRIO QUALIFICADO] LAL VV95% + Interação
- **Objetivo:** Sales (Purchase)
- **Orçamento:** R$150/dia
- **Otimização:** Conversão → Purchase
- **Conjunto 1 — LAL 1% VV95% + Interação IG:**
  - Público: LAL 1% de VV 95% 30D + Interação IG 30D
  - Excluir: Remarketing + LAL compradores
- **CPA esperado:** R$30-50

### CAMPANHA 6: [FRIO PURO] Broad Total
- **Objetivo:** Sales (Purchase)
- **Orçamento:** R$200/dia
- **Otimização:** Conversão → Purchase
- **Conjunto 1 — Broad:**
  - Público: Brasil 25-55, sem segmentação
  - Excluir: Todos os custom audiences
  - Advantage+: DESLIGADO
- **Criativos (4):**
  1. Best seller creative
  2. Antes/Depois storytelling
  3. Screen recording IA ao vivo
  4. VSL curto oferta direta
- **CPA esperado:** R$40-60

### CAMPANHA 7: [TOPO] Video Views IA — Máquina de Público
- **Objetivo:** Video Views (ThruPlay)
- **Orçamento:** R$150/dia
- **Otimização:** ThruPlay
- **Plataforma:** Instagram (Reels + Feed)
- **Conjunto 1 — Interesse IA + Empreendedorismo:**
  - Público: Interesses em IA, Marketing Digital, Empreendedorismo, ChatGPT, Automação
  - Excluir: Interagiram IG 365D (pra pegar só gente nova)
  - Idade: 25-55, Brasil
- **Conjunto 2 — LAL 3% VV IA 70%:**
  - Público: Semelhantes (BB, 1%) → Vídeo view IA 70% 30D — 3.9M-4.6M
  - Excluir: Interagiram IG 365D
- **Criativos (3-5 vídeos orgânicos):**
  - Reels que performam bem organicamente
  - Conteúdo educativo sobre o tema
  - Depoimentos de alunos/membros
- **CPA por ThruPlay esperado:** R$0.03-0.08
- **Função:** NÃO vende diretamente. Enche os públicos de remarketing (VV 25%, 50%, 75%, 95%) que convertem nas campanhas de venda.

---

## Budget Summary
| Campanha | Orçamento/Dia | Vendas Esperadas |
|----------|---------------|------------------|
| 1. Checkout Abandonado | R$150 | 15-20 |
| 2. VV 95% + Perfil | R$100 | 5-8 |
| 3. Advantage+ Shopping | R$300 | 15-20 |
| 4. LAL Compradores | R$200 | 8-12 |
| 5. LAL VV95% + Interação | R$150 | 5-8 |
| 6. Broad Total | R$200 | 5-10 |
| 7. Video Views (topo) | R$150 | 0 (alimenta funil) |
| + Campanhas atuais escaladas | +R$400 | 30-35 |
| **TOTAL** | **R$1.650/dia** | **83-113 vendas** |

Investimento mensal: ~R$49.500
Receita front-end: 100 × R$47 × 30 = R$141.000 + high ticket na ponta

## Audiences to Create (7 new)
| # | Nome | Tipo | Semente |
|---|------|------|---------|
| 1 | LAL 1% Purchase 90D (Pixel) | Lookalike 1% | Purchase 90D |
| 2 | LAL 2% Purchase 90D (Pixel) | Lookalike 2% | Mesmo |
| 3 | LAL 1% Initiate Checkout 30D | Lookalike 1% | Initiate Checkout 30D |
| 4 | LAL 1% VV 95% 30D IA | Lookalike 1% | VV 95% 30D |
| 5 | LAL 1% Salvaram Posts 30D | Lookalike 1% | Pessoas que salvaram posts 30D |
| 6 | Initiate Checkout 7D | Website Custom | Pixel — evento InitiateCheckout, últimos 7 dias |
| 7 | Page View 7D | Website Custom | Pixel — evento PageView, últimos 7 dias |
