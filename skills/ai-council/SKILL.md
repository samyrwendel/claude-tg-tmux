---
name: ai-council
description: Create an AI Council (LLM-as-a-Judge) that sends the same prompt to multiple AI models (GPT, Claude, Gemini, Grok, etc.) via OpenRouter, collects all responses, and has a judge model evaluate, compare, and synthesize the best answer. Reduces hallucinations by cross-referencing models. Use when user wants multi-model consensus, fact-checking across AIs, comparing model outputs, reducing hallucination risk, or getting the most reliable answer possible. Trigger words include conselho de IAs, AI council, LLM judge, comparar modelos, multi-model, consensus, cross-check, verificar resposta, qual modelo acerta.
---

# AI Council (LLM-as-a-Judge)

Send a prompt to multiple AI models, then have a judge model evaluate all responses and deliver a synthesized verdict.

## Concept

The "AI Council" technique (LLM-as-a-Judge) reduces hallucinations by:
1. Sending the same question to 3+ different models
2. A judge model analyzes all responses
3. Judge identifies agreements, disagreements, and hallucinations
4. Final verdict synthesizes the best answer

Studies show >80% concordance with human judges when using this technique.

## Quick Start

```bash
# Run the council with a question
{baseDir}/scripts/ai-council.sh "Quando o marco legal da IA vai ser implementado no Brasil?"
```

## How It Works

### Architecture

```
User Question
    │
    ├──→ Model A (e.g. GPT-4o)      ──→ Response A
    ├──→ Model B (e.g. Claude Opus)  ──→ Response B
    └──→ Model C (e.g. Grok)        ──→ Response C
                                          │
                                          ▼
                                    Judge Model (Gemini)
                                          │
                                          ▼
                                    Final Verdict
                                    - Agreements
                                    - Disagreements
                                    - Hallucinations detected
                                    - Synthesized answer
```

### Models via OpenRouter

The script uses OpenRouter API to access multiple models with a single API key.

**Setup:** 
1. Get API key at https://openrouter.ai/keys
2. Add credits (set daily/weekly/monthly limits)
3. Export: `export OPENROUTER_API_KEY="sk-or-..."`

**Default models (configurable):**
- `openai/gpt-4o` — strong reasoning
- `anthropic/claude-opus-4-6` — nuanced analysis
- `x-ai/grok-3` — web-connected, real-time info

**Judge:** `google/gemini-2.5-pro` (via OpenRouter) or local Gemini API

### Manual Usage (No Script)

Can also be done manually by spawning sub-agents:

```
1. sessions_spawn each model with the same question
2. Collect responses
3. Feed all responses to a judge prompt
4. Judge evaluates and synthesizes
```

## Judge Prompt Template

See `references/judge-prompt.md` for the full judge prompt template.

## Configuration

Environment variables:
- `OPENROUTER_API_KEY` — Required. Get from https://openrouter.ai
- `AI_COUNCIL_MODELS` — Optional. Comma-separated model list (default: gpt-4o,claude-opus-4-6,grok-3)
- `AI_COUNCIL_JUDGE` — Optional. Judge model (default: google/gemini-2.5-pro)

## Use Cases

1. **Fact-checking**: Cross-reference facts across models to catch hallucinations
2. **Legal/regulatory**: Get consensus on complex legal questions
3. **Research**: Compare model knowledge on niche topics
4. **Decision-making**: Get multiple AI perspectives before deciding
5. **Content verification**: Verify claims in articles/videos
