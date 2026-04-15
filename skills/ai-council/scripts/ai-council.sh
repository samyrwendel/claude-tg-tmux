#!/bin/bash
# AI Council — Send a question to multiple models, then judge the responses
# Usage: ai-council.sh "Your question here" [model1,model2,model3] [judge_model]

set -euo pipefail

QUESTION="${1:?Usage: $0 \"question\" [models] [judge]}"
MODELS="${2:-openai/gpt-4o,anthropic/claude-opus-4-6,x-ai/grok-3}"
JUDGE="${3:-google/gemini-2.5-pro}"
API_KEY="${OPENROUTER_API_KEY:?Set OPENROUTER_API_KEY first}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
OUTPUT_DIR="/tmp/ai-council-$(date +%s)"
mkdir -p "$OUTPUT_DIR"

echo "🏛️ AI Council"
echo "📝 Question: $QUESTION"
echo "🤖 Models: $MODELS"
echo "⚖️ Judge: $JUDGE"
echo ""

# Function to query a model via OpenRouter
query_model() {
    local model="$1"
    local question="$2"
    local output_file="$3"
    
    local response
    response=$(curl -s "https://openrouter.ai/api/v1/chat/completions" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d "$(python3 -c "
import json
print(json.dumps({
    'model': '$model',
    'messages': [{'role': 'user', 'content': '''$question'''}],
    'max_tokens': 2000
}))
")" 2>&1)
    
    echo "$response" | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    content = data['choices'][0]['message']['content']
    print(content)
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    print(json.dumps(data, indent=2) if 'data' in dir() else 'No response', file=sys.stderr)
    sys.exit(1)
" > "$output_file"
    
    echo "✅ $model responded ($(wc -c < "$output_file") bytes)"
}

# Query all models in parallel
IFS=',' read -ra MODEL_ARRAY <<< "$MODELS"
PIDS=()

for model in "${MODEL_ARRAY[@]}"; do
    safe_name=$(echo "$model" | tr '/' '_')
    query_model "$model" "$QUESTION" "$OUTPUT_DIR/$safe_name.txt" &
    PIDS+=($!)
done

# Wait for all models
for pid in "${PIDS[@]}"; do
    wait "$pid" || echo "⚠️ A model failed (pid $pid)"
done

echo ""
echo "📊 All models responded. Sending to judge..."
echo ""

# Build judge prompt
JUDGE_PROMPT="Question asked to all models:\n\"$QUESTION\"\n\n---\n"

for model in "${MODEL_ARRAY[@]}"; do
    safe_name=$(echo "$model" | tr '/' '_')
    response_file="$OUTPUT_DIR/$safe_name.txt"
    if [ -f "$response_file" ]; then
        JUDGE_PROMPT+="### Response from $model:\n$(cat "$response_file")\n\n---\n"
    fi
done

JUDGE_PROMPT+="\nAnalyze all responses above. Identify agreements, disagreements, and hallucinations. Provide your verdict with: Consensus, Disagreements, Hallucinations Detected, Model Rankings, and Final Answer."

# Query the judge
JUDGE_RESPONSE=$(curl -s "https://openrouter.ai/api/v1/chat/completions" \
    -H "Authorization: Bearer $API_KEY" \
    -H "Content-Type: application/json" \
    -d "$(python3 -c "
import json, sys
prompt = sys.stdin.read()
print(json.dumps({
    'model': '$JUDGE',
    'messages': [
        {'role': 'system', 'content': 'You are an impartial AI Judge. Analyze responses from multiple AI models, identify agreements, disagreements, hallucinations, rank models, and synthesize the best answer.'},
        {'role': 'user', 'content': prompt}
    ],
    'max_tokens': 3000
}))
" <<< "$JUDGE_PROMPT")" 2>&1)

echo "$JUDGE_RESPONSE" | python3 -c "
import sys, json
data = json.load(sys.stdin)
print(data['choices'][0]['message']['content'])
" | tee "$OUTPUT_DIR/verdict.txt"

echo ""
echo "📁 Full results saved to: $OUTPUT_DIR"
