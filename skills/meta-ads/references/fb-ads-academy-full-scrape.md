# Facebook Ads Academy — Scrape Completo
> Fonte: facebookads.iacomtata.com.br (Tata Gonçalves)
> Scrape: 2026-02-22

---

## Página: https://facebookads.iacomtata.com.br/ (Home)

### As 4 Fases da Jornada
Clique em qualquer passo para ir direto ao conteúdo

**Fase 1: Setup** — Configuração do ambiente — 3 passos
- #01 Criar App do Facebook — App tipo Business com Marketing API (10 min)
- #02 Gerar Token de Acesso — Graph API Explorer com 5 permissões (5 min)
- #03 Configurar Projeto Python — Ambiente, .env e dependências (10 min)

**Fase 2: Análise** — Extrair dados do Facebook — 6 passos
- #04 Análise de Criativos — Script 01 — Top/Bottom performers (15 min)
- #05 Análise de Horários — Script 02 — Melhores horas e dias (10 min)
- #06 Análise de Posicionamentos — Script 03 — Feed vs Stories vs Reels (10 min)
- #07 Análise Demográfica — Script 04 — Heatmap idade x gênero (10 min)
- #08 Análise de Fadiga — Script 05 — Declínio de CTR e frequência (10 min)
- #09 Análise de Funil — Script 06 — 8 estágios de conversão (15 min)

**Fase 3: Insights** — Dashboards e estratégia — 4 passos
- #10 Dashboard Geral — Script 07 — Chart.js, KPIs, 8 gráficos (15 min)
- #11 Comparativo de Imersões — Script 08 — 8 ciclos lado a lado (15 min)
- #12 Dashboard CEO — Script 09 — 10 KPIs, 13 gráficos, projeções (20 min)
- #13 Estratégia de Públicos — Script 10 — Ranking Elite/Good/OK (15 min)

**Fase 4: Execução** — Criar campanhas via API — 3 passos
- #14 Criar Campanhas via API — Script 11 — 4 campanhas + 13 adsets (20 min)
- #15 Guia Visual de Ads — Script 12 — HTML com thumbnails (10 min)
- #16 Criar 56 Ads via API — Script 13 — Ads automáticos, tudo pausado (20 min)

---

## Página: https://facebookads.iacomtata.com.br/journey (Jornada)

### 1. Setup
Configuração do ambiente — 0/3 passos (0%)
- #01 Criar App do Facebook — App tipo Business com Marketing API (10 min)
- #02 Gerar Token de Acesso — Graph API Explorer com 5 permissões (5 min)
- #03 Configurar Projeto Python — Ambiente, .env e dependências (10 min)

### 2. Análise
Extrair dados do Facebook — 0/6 passos (0%)
- #04 Análise de Criativos — Script 01 — Top/Bottom performers (15 min)
- #05 Análise de Horários — Script 02 — Melhores horas e dias (10 min)
- #06 Análise de Posicionamentos — Script 03 — Feed vs Stories vs Reels (10 min)
- #07 Análise Demográfica — Script 04 — Heatmap idade x gênero (10 min)
- #08 Análise de Fadiga — Script 05 — Declínio de CTR e frequência (10 min)
- #09 Análise de Funil — Script 06 — 8 estágios de conversão (15 min)

### 3. Insights
Dashboards e estratégia — 0/4 passos (0%)
- #10 Dashboard Geral — Script 07 — Chart.js, KPIs, 8 gráficos (15 min)
- #11 Comparativo de Imersões — Script 08 — 8 ciclos lado a lado (15 min)
- #12 Dashboard CEO — Script 09 — 10 KPIs, 13 gráficos, projeções (20 min)
- #13 Estratégia de Públicos — Script 10 — Ranking Elite/Good/OK (15 min)

### 4. Execução
Criar campanhas via API — 0/3 passos (0%)
- #14 Criar Campanhas via API — Script 11 — 4 campanhas + 13 adsets (20 min)
- #15 Guia Visual de Ads — Script 12 — HTML com thumbnails (10 min)
- #16 Criar 56 Ads via API — Script 13 — Ads automáticos, tudo pausado (20 min)

---

## Página: https://facebookads.iacomtata.com.br/journey/setup (Fase 1: Setup)

### Fase 1: Setup — Configuração do ambiente

Passos:
- #01 Criar App do Facebook — App tipo Business com Marketing API (10 min)
- #02 Gerar Token de Acesso — Graph API Explorer com 5 permissões (5 min)
- #03 Configurar Projeto Python — Ambiente, .env e dependências (10 min)

---

## Página: https://facebookads.iacomtata.com.br/journey/setup/create-app (#01)

### Fase 1: Setup — 10 min

## #01 Criar App do Facebook
O primeiro passo é criar um App do Facebook do tipo Business. Apps do tipo Game NÃO funcionam com a Marketing API — esse é o erro #1 mais comum.

### ⚠️ Erro Crítico #1
NUNCA crie App tipo "Game". Apenas "Business" tem acesso à Marketing API. Erro 1815694 é o resultado de usar app errado.

### Passo a passo (Método 1: developers.facebook.com)
Siga esta sequência exata:
1. Acessar developers.facebook.com
2. Clicar "Criar App"
3. Selecionar tipo "Business" (NÃO Game!)
4. Adicionar produto "Marketing API"
5. Ir em Configurações > Básico
6. Mudar modo para "Live" (NÃO Development)
7. Salvar alterações

### Por que "Live"?
Apps em modo Development têm limitações severas. Erro 1885183 aparece quando o app está em dev mode e tenta acessar dados reais de ads.

### Método 2: Criar App via Meta Business Suite
Alternativa ao developers.facebook.com — você pode criar o App de Negócios diretamente pelo Meta Business Suite. Siga os passos abaixo:

#### 1. Acessar o Meta Business Suite
Primeiro, entre na plataforma:
1. Acessar business.facebook.com
2. Fazer login com sua conta do Facebook
3. Selecionar a conta [Nome da Empresa] (ou a conta de negócios correta)

#### 2. Ir para Configurações de Negócios
Navegue até as configurações:
1. No menu lateral esquerdo, clicar em Configurações (ícone de engrenagem)
2. Ou acessar direto: business.facebook.com/settings

#### 3. Criar o App
Crie o app de negócios:
1. No menu lateral, procurar Contas → Apps
2. Clicar em Adicionar → Criar novo app
3. Tipo do app: Selecionar "Negócios" (Business)
4. Nome do app: Definir um nome como [Nome da Empresa] Ads Manager ou [Nome do Projeto] Automacao
5. E-mail de contato: [Seu E-mail]
6. Portfólio de negócios: Selecionar o portfólio da [Nome da Empresa]
7. Clicar em "Criar app"

#### 4. Adicionar o Produto "Marketing API"
Libere o acesso à API de anúncios:
1. No Painel do App, rolar até "Adicionar produtos ao seu app"
2. Procurar "Marketing API" e clicar em "Configurar"
3. Isso libera o acesso à API de anúncios

### ℹ️ Dois caminhos, mesmo resultado
Tanto o Método 1 (developers.facebook.com) quanto o Método 2 (Meta Business Suite) criam o mesmo tipo de App Business. Use o caminho que for mais familiar para você.

---

## Página: https://facebookads.iacomtata.com.br/journey/setup/generate-token (#02)

### Fase 1: Setup — 5 min

## #02 Gerar Token de Acesso
Gerar um User Access Token com as 5 permissões necessárias para acessar todos os endpoints da Marketing API.

### Gerar Token
No Graph API Explorer:
1. Acessar developers.facebook.com/tools/explorer
2. Selecionar seu App Business
3. Adicionar permissão: `ads_management`
4. Adicionar permissão: `ads_read`
5. Adicionar permissão: `business_management`
6. Adicionar permissão: `pages_read_engagement`
7. Adicionar permissão: `pages_show_list`
8. Clicar "Generate Access Token"
9. Autorizar no popup

### 🔒 Segurança do Token
O token dá acesso TOTAL à sua conta de ads. NUNCA compartilhe, commite no Git, ou coloque em código público. Use SEMPRE arquivo .env com .gitignore.

### ✅ Validação rápida
Use a página /validate deste app para verificar se seu token está correto e tem todas as permissões necessárias.

---

## Página: https://facebookads.iacomtata.com.br/journey/setup/configure-project (#03)

### Fase 1: Setup — 10 min

## #03 Configurar Projeto Python

### Instalar dependências
```bash
# Terminal — Clique em Play para iniciar...
pip install facebook-business==19.0.0 python-dotenv pandas
```

### Criar arquivo .env
```bash
# .env - NUNCA commitar este arquivo!
FACEBOOK_ACCESS_TOKEN=seu_token_aqui
FACEBOOK_AD_ACCOUNT_ID=act_123456789
FACEBOOK_APP_ID=123456789
FACEBOOK_APP_SECRET=seu_secret_aqui
```

### Código base de conexão (config.py)
```python
from facebook_business.api import FacebookAdsApi
from facebook_business.adobjects.adaccount import AdAccount
from dotenv import load_dotenv
import os

load_dotenv()

FacebookAdsApi.init(
    app_id=os.getenv("FACEBOOK_APP_ID"),
    app_secret=os.getenv("FACEBOOK_APP_SECRET"),
    access_token=os.getenv("FACEBOOK_ACCESS_TOKEN"),
)

account = AdAccount(os.getenv("FACEBOOK_AD_ACCOUNT_ID"))
```

### .gitignore essencial
```text
.env
__pycache__/
*.pyc
*.csv
*.html
*.json
!package.json
```

### Verificação
Confirme que:
- ✅ Python 3.9+ instalado
- ✅ facebook-business==19.0.0 instalado
- ✅ Arquivo .env criado com credenciais
- ✅ .env está no .gitignore
- ✅ Teste de conexão executado sem erro

---

## Página: https://facebookads.iacomtata.com.br/journey/analysis (Fase 2: Análise)

### Fase 2: Análise — Extrair dados do Facebook (0%)

Passos:
- #04 Análise de Criativos — Script 01 — Top/Bottom performers (15 min)
- #05 Análise de Horários — Script 02 — Melhores horas e dias (10 min)
- #06 Análise de Posicionamentos — Script 03 — Feed vs Stories vs Reels (10 min)
- #07 Análise Demográfica — Script 04 — Heatmap idade x gênero (10 min)
- #08 Análise de Fadiga — Script 05 — Declínio de CTR e frequência (10 min)
- #09 Análise de Funil — Script 06 — 8 estágios de conversão (15 min)

---

## Página: https://facebookads.iacomtata.com.br/journey/analysis/creatives (#04)

### Fase 2: Análise — 15 min

## #04 Análise de Criativos (Script 01)

### Código — Script 01: Top/Bottom performers

```python
from facebook_business.adobjects.adaccount import AdAccount
from facebook_business.adobjects.ad import Ad

# Campos necessários para análise de criativos
fields = [
    "ad_name",
    "adset_name",
    "campaign_name",
    "spend",
    "impressions",
    "clicks",
    "actions",
    "cost_per_action_type",
    "video_30_sec_watched_actions",
]

# Parâmetros: últimos 90 dias, breakdown por ad
params = {
    "time_range": {"since": "2024-12-01", "until": "2025-02-28"},
    "level": "ad",
    "filtering": [{"field": "spend", "operator": "GREATER_THAN", "value": "0"}],
}

insights = account.get_insights(fields=fields, params=params)
```

---

## Página: https://facebookads.iacomtata.com.br/journey/analysis/schedules (#05)

### Fase 2: Análise — 10 min

## #05 Análise de Horários (Script 02)
Descobrir os horários e dias da semana com melhor performance para otimizar o agendamento de anúncios.

### O que este script faz
O script 02 analisa performance por hora do dia e dia da semana usando o breakdown "hourly_stats_aggregated_by_advertiser_time_zone". Permite identificar janelas de alta conversão.

### Resultados esperados
Ao final:
- Heatmap hora x dia da semana
- Top 5 horários por conversão
- Horários para evitar (alto custo)
- CSV com dados horários

---

## Página: https://facebookads.iacomtata.com.br/journey/analysis/placements (#06)

### Fase 2: Análise — 10 min

## #06 Análise de Posicionamentos (Script 03)

### Código — Script 03: Feed vs Stories vs Reels

```python
params = {
    "time_range": {"since": "2024-12-01", "until": "2025-02-28"},
    "breakdowns": ["publisher_platform", "platform_position"],
    "level": "account",
}

fields = ["spend", "impressions", "clicks", "actions",
          "cost_per_action_type", "ctr"]
insights = account.get_insights(fields=fields, params=params)

# Resultado: Feed Instagram, Stories, Reels, Facebook Feed, etc.
# Cada um com suas métricas de performance
```

---

## Página: https://facebookads.iacomtata.com.br/journey/analysis/demographics (#07)

### Fase 2: Análise — 10 min

## #07 Análise Demográfica (Script 04)

### Código — Script 04: Heatmap idade x gênero

```python
params = {
    "time_range": {"since": "2024-12-01", "until": "2025-02-28"},
    "breakdowns": ["age", "gender"],
    "level": "account",
}

fields = ["spend", "impressions", "clicks", "actions",
          "cost_per_action_type"]
insights = account.get_insights(fields=fields, params=params)

# Resultado: cada combinação idade x gênero
# Ex: female 25-34, male 35-44, etc.
```

---

## Página: https://facebookads.iacomtata.com.br/journey/analysis/fatigue (#08)

### Fase 2: Análise — 10 min

## #08 Análise de Fadiga (Script 05)

### Código — Script 05: Declínio de CTR e frequência

```python
# Análise diária por ad
params = {
    "time_range": {"since": "2024-12-01", "until": "2025-02-28"},
    "time_increment": 1,  # dia a dia
    "level": "ad",
    "filtering": [{"field": "spend", "operator": "GREATER_THAN", "value": "0"}],
}

fields = ["ad_name", "impressions", "clicks", "frequency", "ctr"]
insights = account.get_insights(fields=fields, params=params)

# Indicadores de fadiga:
# - Frequência > 3.0
# - CTR caiu 30%+ do pico
# - CPV subindo nos últimos 7 dias
```

---

## Página: https://facebookads.iacomtata.com.br/journey/analysis/funnel (#09)

### Fase 2: Análise — 15 min

## #09 Análise de Funil (Script 06)
Mapear os 8 estágios do funil de conversão: Impressões → Clicks → Page Views → View Content → Add to Cart → Initiate Checkout → Leads → Purchases.

### O que este script faz
O script 06 extrai dados de cada estágio do funil para identificar onde está o maior "vazamento" — onde as pessoas abandonam o processo de compra.

### ℹ️ Dashboard CEO usa estes dados
O funil completo alimenta o Dashboard CEO (passo 12). As taxas de conversão entre estágios são KPIs críticos para o cliente.

### Resultados esperados
Ao final:
- Funil visual com 8 estágios
- Taxa de conversão entre cada estágio
- Identificação do maior gargalo
- CSV com dados do funil por campanha

---

## Página: https://facebookads.iacomtata.com.br/journey/insights (Fase 3: Insights)

### Fase 3: Insights — Dashboards e estratégia (0%)

Passos:
- #10 Dashboard Geral — Script 07 — Chart.js, KPIs, 8 gráficos (15 min)
- #11 Comparativo de Imersões — Script 08 — 8 ciclos lado a lado (15 min)
- #12 Dashboard CEO — Script 09 — 10 KPIs, 13 gráficos, projeções (20 min)
- #13 Estratégia de Públicos — Script 10 — Ranking Elite/Good/OK (15 min)

---

## Página: https://facebookads.iacomtata.com.br/journey/insights/dashboard (#10)

### Fase 3: Insights — 15 min

## #10 Dashboard Geral (Script 07)
Gerar um dashboard HTML interativo com Chart.js contendo KPIs principais e 8 gráficos de performance.

### O que este script faz
O script 07 consolida todos os CSVs gerados nos scripts de análise e gera um arquivo dashboard.html com visualizações interativas usando Chart.js via CDN.

### Resultados esperados
Ao final:
- Arquivo dashboard.html gerado
- 8 gráficos interativos
- KPI cards com valores reais
- Abrir no navegador para visualizar

---

## Página: https://facebookads.iacomtata.com.br/journey/insights/comparative (#11)

### Fase 3: Insights — 15 min

## #11 Comparativo de Imersões (Script 08)

### Código — Script 08: 8 ciclos lado a lado

```python
IMERSOES = [
    {"nome": "Imersao 1", "data": "17-18 Mai", "inicio": "2024-05-01", "fim": "2024-05-18"},
    {"nome": "Imersao 2", "data": "Jun", "inicio": "2024-05-19", "fim": "2024-06-30"},
    {"nome": "Imersao 3", "data": "Jul-Ago", "inicio": "2024-07-01", "fim": "2024-08-31"},
    {"nome": "Imersao 4", "data": "Set", "inicio": "2024-09-01", "fim": "2024-09-30"},
    {"nome": "Imersao 5", "data": "Out", "inicio": "2024-10-01", "fim": "2024-10-31"},
    {"nome": "Imersao 6", "data": "Nov-Dez", "inicio": "2024-11-01", "fim": "2024-12-31"},
    {"nome": "Imersao 7", "data": "Jan", "inicio": "2025-01-01", "fim": "2025-01-31"},
    {"nome": "Imersao 8", "data": "21-22 Fev", "inicio": "2025-02-01", "fim": "2025-02-22"},
]

# Para cada imersão, buscar insights no período
for imersao in IMERSOES:
    params = {
        "time_range": {"since": imersao["inicio"], "until": imersao["fim"]},
        "level": "account",
    }
    insights = account.get_insights(fields=fields, params=params)
```

---

## Página: https://facebookads.iacomtata.com.br/journey/insights/dashboard-ceo (#12)

### Fase 3: Insights — 20 min

## #12 Dashboard CEO (Script 09)
O dashboard executivo completo: 10 KPIs, 13 gráficos, projeções de mentoria, análise de desperdício e unit economics.

### O que este script faz
O script 09 gera o dashboard mais completo do sistema: dashboard_ceo.html com 7 seções, 10 KPI cards, 13 gráficos e projeções de receita de mentoria em 3 cenários.

### Resultados esperados
Ao final:
- dashboard_ceo.html gerado (completo)
- relatorio_ceo.csv com dados por imersão
- relatorio_ceo_publicos.csv com dados por público
- 10 KPI cards com valores reais
- 13 gráficos interativos
- 3 cenários de projeção de mentoria

---

## Página: https://facebookads.iacomtata.com.br/journey/insights/strategy (#13)

### Fase 3: Insights — 15 min

## #13 Estratégia de Públicos (Script 10)
Classificar todos os públicos em tiers (Elite, Good, OK, Cold) e definir a estratégia de alocação para 4 campanhas.

### O que este script faz
O script 10 analisa todos os públicos (Custom Audiences e Interests) e classifica em tiers baseado no CPV histórico e número de conversões.

### Resultados esperados
Ao final:
- estrategia_imersao9.html com visualização
- estrategia_imersao9.json com plano
- Ranking de públicos por tier
- 4 campanhas definidas com públicos alocados
- Budget alocado por campanha

---

## Página: https://facebookads.iacomtata.com.br/journey/execution (Fase 4: Execução)

### Fase 4: Execução — Criar campanhas via API (0%)

Passos:
- #14 Criar Campanhas via API — Script 11 — 4 campanhas + 13 adsets (20 min)
- #15 Guia Visual de Ads — Script 12 — HTML com thumbnails (10 min)
- #16 Criar 56 Ads via API — Script 13 — Ads automáticos, tudo pausado (20 min)

---

## Página: https://facebookads.iacomtata.com.br/journey/execution/create-campaigns (#14)

### Fase 4: Execução — 20 min

## #14 Criar Campanhas via API (Script 11)
Criar automaticamente 4 campanhas e 13 ad sets via Marketing API, tudo em modo PAUSADO para revisão.

### ⚠️ TUDO PAUSADO
Todas as campanhas e adsets são criados com status PAUSED. Isso é CRÍTICO — nunca crie campanhas ativas automaticamente. Revise TUDO antes de ativar.

### Erros comuns na criação
- **Erro #5:** Campos duplicados no targeting. Use excluded_custom_audiences no root level.
- **Erro #6:** Adsets de interesse PRECISAM de bid_strategy.
- **Erro #7:** Campanhas PRECISAM de is_adset_budget_sharing_enabled: False.

### Resultados esperados
Ao final:
- 4 campanhas criadas (PAUSED)
- 13 adsets criados (PAUSED)
- log_criacao_imersao9.json gerado
- Nenhum erro na criação
- Verificar no Ads Manager que tudo aparece

---

## Página: https://facebookads.iacomtata.com.br/journey/execution/visual-guide (#15)

### Fase 4: Execução — 10 min

## #15 Guia Visual de Ads (Script 12)
Gerar um guia visual HTML com thumbnails de todos os criativos e checkboxes para marcar quais já foram verificados.

### O que este script faz
O script 12 gera um guia_ads_imersao9.html com cards visuais de cada criativo, mostrando thumbnail, métricas de performance, e checkboxes para o operador marcar quais foram verificados.

### Resultados esperados
Ao final:
- guia_ads_imersao9.html gerado
- Todos os criativos com thumbnails
- Checkboxes para verificação
- Organizado por campanha/adset

---

## Página: https://facebookads.iacomtata.com.br/journey/execution/create-ads (#16)

### Fase 4: Execução — 20 min

## #16 Criar 56 Ads via API (Script 13)

### Código — Script 13: Ads automáticos, tudo pausado

```python
import requests
import time
import json

# 15 top criativos identificados no script 01
TOP_CRIATIVOS = [
    {"name": "Video Depoimento Ana", "object_story_id": "123_456"},
    {"name": "Carrossel Resultados", "object_story_id": "123_789"},
    # ... 13 mais
]

def criar_ad(adset_id, criativo, token):
    url = f"https://graph.facebook.com/v21.0/act_{ACCOUNT_ID}/ads"
    payload = {
        "name": f"WIA9-{adset_key} | {criativo['name']}",
        "adset_id": adset_id,
        "status": "PAUSED",
        "creative": {"object_story_id": criativo["object_story_id"]},
        "access_token": token,
    }
    response = requests.post(url, json=payload)
    time.sleep(1)  # Evitar rate limit!
    return response.json()

# Loop: para cada adset, criar ads com os criativos relevantes
for adset in adsets:
    for criativo in adset["criativos"]:
        resultado = criar_ad(adset["id"], criativo, TOKEN)
        log.append(resultado)
```

---

## Página: https://facebookads.iacomtata.com.br/errors (Erros Comuns)

# 10 Erros Documentados
Erros comuns ao trabalhar com a Facebook Marketing API e como evitá-los

### Severidade: Critical

**#1 — Erro 1815694**
App tipo Game não tem Marketing API

**#2 — Erro 1487194**
Conta UNSETTLED (saldo pendente)

**#3 — Erro 1885183**
App em modo Development

### Severidade: High

**#4** — Placement "reels" inválido

**#5** — Campos de targeting duplicados

**#6** — Missing bid em adsets de interesse

### Severidade: Medium

**#7** — Missing is_adset_budget_sharing_enabled

**#8** — Dynamic creative sem product set

**#9** — Rate limit "User request limit reached"

### Severidade: Low

**#10** — Pixel não compartilhado entre contas

---

## Página: https://facebookads.iacomtata.com.br/flow (Fluxo de Dados)

## Diagrama de Fluxo
Clique em qualquer nó para ver inputs, outputs e descrição. Passe o mouse sobre uma fase para destacá-la.

### Fluxo dos Scripts:
```
.env Config
    ↓
01 Criativos → 02 Horários → 03 Posicionamentos → 04 Demográfico → 05 Fadiga → 06 Funil
    ↓
07 Dashboard → 08 Comparativo → 09 Dashboard CEO → 10 Estratégia
    ↓
11 Campanhas → 12 Guia Visual → 13 Criar Ads
```

---

## Página: https://facebookads.iacomtata.com.br/calculator (Calculadora)

## Calculadora de ROI

### Inputs:
- **Budget Diário:** R$1.500
- **Dias de Captação:** 35 dias
- **CPV Meta:** R$150
- **Preço do Ticket:** R$497
- **Preço Mentoria:** R$28.000
- **Taxa Conversão Mentoria:** 10%

### Outputs:
- Budget Total: R$0 (calculado)
- Vendas Estimadas: 0
- Receita Total: R$0
- ROAS: 0.0x

### Cenários de Projeção:

#### Conservador (7%)
- Vendas: 350
- Mentorias: 24
- Receita Mentoria: R$672.000
- Receita Total: R$845.950
- ROAS: 16.1x

#### Realista (10%)
- Vendas: 350
- Mentorias: 35
- Receita Mentoria: R$980.000
- Receita Total: R$1.153.950
- ROAS: 22.0x

#### Otimista (14%)
- Vendas: 350
- Mentorias: 49
- Receita Mentoria: R$1.372.000
- Receita Total: R$1.545.950
- ROAS: 29.4x

#### Curva de Receita vs Investimento
(Gráfico interativo no site)

---

## Página: https://facebookads.iacomtata.com.br/validate (Validar Token)

## Validar Token & Conta
Verifique se seu token e conta de anúncios estão configurados corretamente

### Campos:
- **Access Token** — O token NÃO é salvo. Apenas usado para validação client-side.
- **Ad Account ID** (opcional)

### Como funciona:
- A validação é feita diretamente no seu navegador (client-side)
- O token NÃO é salvo em nenhum lugar — apenas usado para validação
- A chamada vai direto para graph.facebook.com via HTTPS
- Verificamos: validade do token, permissões, e status da conta
