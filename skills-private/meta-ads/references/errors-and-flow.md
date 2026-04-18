# Meta Ads API — Erros Comuns & Fluxo de Dados
> Fonte: Facebook Ads Academy (Tata Gonçalves) — facebookads.iacomtata.com.br

## 10 Erros Documentados

### CRITICAL
| # | Erro | Causa | Solução |
|---|------|-------|---------|
| 1 | Erro 1815694 — App tipo Game | Apps Game NÃO têm Marketing API | Criar App tipo "Business" + adicionar produto "Marketing API" |
| 2 | Erro 1487194 — Conta UNSETTLED | account_status: 3, saldo pendente | Gerenciador > Cobrança > pagar saldo. Volta pra ACTIVE (status 1) |
| 3 | Erro 1885183 — App em Development | Modo dev não acessa dados reais | developers.facebook.com > App > Configurações > Básico > modo "Live" |

### HIGH
| # | Erro | Causa | Solução |
|---|------|-------|---------|
| 4 | Placement "reels" inválido | API não aceita "reels" como placement direto | NÃO especificar posicionamentos. Usar Advantage+ Placements (automático) |
| 5 | Targeting duplicado | excluded_custom_audiences dentro de flexible_spec | Colocar excluded_custom_audiences no ROOT LEVEL do targeting |
| 6 | Missing bid em interest adsets | Adsets por interesses precisam bid_strategy | Adicionar bid_strategy: "LOWEST_COST_WITHOUT_CAP" em todos os adsets de interesse |

### MEDIUM
| # | Erro | Causa | Solução |
|---|------|-------|---------|
| 7 | Missing is_adset_budget_sharing_enabled | Campanhas sem este campo falham silenciosamente | Adicionar is_adset_budget_sharing_enabled: False em toda campanha via API |
| 8 | Dynamic creative sem product set | dynamic_creative: true sem catálogo | Usar creative com object_story_id, não dynamic_creative |
| 9 | Rate limit "User request limit reached" | Muitas chamadas por token/app | time.sleep(1) entre chamadas. Se bater, aguardar 2-5 min |

### LOW
| # | Erro | Causa | Solução |
|---|------|-------|---------|
| 10 | Pixel não compartilhado | Pixel em conta diferente da conta de ads | Verificar com /{account_id}/adspixels. Compartilhar via Business Manager |

## Fluxo de Dados (14 scripts)

```
.env Config
    ↓
[ANALYSIS]
01 Criativos → 02 Horários → 03 Posicionamentos → 04 Demográfico
05 Fadiga → 06 Funil
    ↓
[INSIGHTS]
07 Dashboard → 08 Comparativo → 09 Dashboard CEO → 10 Estratégia
    ↓
[EXECUTION]
11 Campanhas → 12 Guia Visual → 13 Criar Ads
```

## Funil de Conversão (referência R$1.500/dia)
| Estágio | Volume | Taxa |
|---------|--------|------|
| Impressões | 5.000.000 | — |
| Clicks | 150.000 | 3.0% |
| Page Views | 97.500 | 65.0% |
| View Content | 39.000 | 40.0% |
| Add to Cart | 7.800 | 20.0% |
| Checkout | 3.900 | 50.0% |
| Leads | 2.340 | 60.0% |
| Purchases | 780 | 33.3% |

## Alocação de Budget (R$1.500/dia)
| Tier | Budget | % |
|------|--------|---|
| ELITE | R$600/dia | 40% |
| GOOD | R$450/dia | 30% |
| OK | R$300/dia | 20% |
| COLD | R$150/dia | 10% |

## Estrutura de Campanhas (4 campanhas × 3-4 adsets = 13 adsets × ~4 criativos = 56 ads)

| Campanha | Budget | Adsets (públicos) |
|----------|--------|-------------------|
| **WIA9-ELITE** | R$600/dia (40%) | Engajamento IG 30d, Visitaram perfil 180d, VV 95% Reels 7d, PV 7d |
| **WIA9-GOOD** | R$450/dia (30%) | VV 70% 30d, VV Thruplay 365d, Salvaram 30d, PV 30d |
| **WIA9-OK** | R$300/dia (20%) | VV 25% 30d, IC 180d, PV 180d |
| **WIA9-COLD** | R$150/dia (10%) | Marketing Digital (interesse), Empreendedorismo (interesse) |

## Calculadora de Receita (referência Degenerados R$497)
- Budget: R$1.500/dia × 35 dias = R$52.500
- Meta CPV: R$150
- Vendas estimadas: 350
- Receita ticket: R$173.950
- Com mentoria (R$28.000, 10% conversão = 35 mentorias): R$980.000
- **Receita total realista: R$1.153.950 | ROAS 22x**
- Cenários: Conservador 16.1x | Realista 22x | Otimista 29.4x

## Validar Token (ferramenta client-side)
- URL: facebookads.iacomtata.com.br/validate
- Verifica: validade, permissões, status da conta
- Token NÃO é salvo — validação direto no browser via graph.facebook.com
