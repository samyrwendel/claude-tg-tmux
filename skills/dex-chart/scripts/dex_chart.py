#!/usr/bin/env python3
"""
DEX Chart - Gráfico de candlestick de pools em DEX
Usa GeckoTerminal API (gratuita)
Suporta proxy rotation para contornar rate limit
"""
import argparse
import requests
import pandas as pd
import mplfinance as mpf
import matplotlib.dates as mdates
from datetime import datetime
import json
import os
import random
from pathlib import Path

# Proxy rotation
PROXY_LIST = []
PROXY_INDEX = 0

def load_proxies(proxy_file: str = None):
    """Carrega lista de proxies de arquivo ou env"""
    global PROXY_LIST
    
    # Tentar arquivo primeiro
    if proxy_file and Path(proxy_file).exists():
        with open(proxy_file, 'r') as f:
            PROXY_LIST = [line.strip() for line in f if line.strip() and not line.startswith('#')]
        print(f"🔄 {len(PROXY_LIST)} proxies carregados de {proxy_file}")
        return
    
    # Tentar arquivo padrão
    default_file = Path.home() / ".config" / "dex-chart" / "proxies.txt"
    if default_file.exists():
        with open(default_file, 'r') as f:
            PROXY_LIST = [line.strip() for line in f if line.strip() and not line.startswith('#')]
        print(f"🔄 {len(PROXY_LIST)} proxies carregados de {default_file}")
        return
    
    # Tentar env
    env_proxies = os.environ.get("DEX_CHART_PROXIES", "")
    if env_proxies:
        PROXY_LIST = [p.strip() for p in env_proxies.split(",") if p.strip()]
        print(f"🔄 {len(PROXY_LIST)} proxies carregados de env")

def get_proxy():
    """Retorna próximo proxy (round-robin com shuffle)"""
    global PROXY_INDEX
    
    if not PROXY_LIST:
        return None
    
    proxy = PROXY_LIST[PROXY_INDEX % len(PROXY_LIST)]
    PROXY_INDEX += 1
    
    return {"http": proxy, "https": proxy}

def get_random_proxy():
    """Retorna proxy aleatório"""
    if not PROXY_LIST:
        return None
    
    proxy = random.choice(PROXY_LIST)
    return {"http": proxy, "https": proxy}

# Cache de info de pares
CACHE_DIR = Path.home() / ".cache" / "dex-chart"
CACHE_FILE = CACHE_DIR / "pairs_cache.json"
CACHE_TTL = 86400  # 24 horas em segundos

def load_cache():
    """Carrega cache de pares"""
    try:
        if CACHE_FILE.exists():
            with open(CACHE_FILE, 'r') as f:
                return json.load(f)
    except:
        pass
    return {}

def save_cache(cache):
    """Salva cache de pares"""
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        with open(CACHE_FILE, 'w') as f:
            json.dump(cache, f, indent=2)
    except:
        pass

def get_cached_pair_info(pair_address: str, network: str):
    """Busca info do par no cache"""
    cache = load_cache()
    key = f"{network}:{pair_address.lower()}"
    
    if key in cache:
        entry = cache[key]
        # Verificar TTL
        if datetime.now().timestamp() - entry.get("ts", 0) < CACHE_TTL:
            return entry.get("name"), entry.get("dex")
    
    return None, None

def cache_pair_info(pair_address: str, network: str, name: str, dex: str):
    """Salva info do par no cache"""
    cache = load_cache()
    key = f"{network}:{pair_address.lower()}"
    cache[key] = {
        "name": name,
        "dex": dex,
        "ts": datetime.now().timestamp()
    }
    save_cache(cache)

# Mapeamento de redes
NETWORKS = {
    "eth": "eth",
    "ethereum": "eth",
    "bsc": "bsc",
    "binance": "bsc",
    "arbitrum": "arbitrum",
    "arb": "arbitrum",
    "base": "base",
    "polygon": "polygon_pos",
    "matic": "polygon_pos",
    "optimism": "optimism",
    "op": "optimism",
    "avalanche": "avax",
    "avax": "avax"
}

# Pares default por rede
DEFAULT_PAIRS = {
    "eth": "0x99ac8cA7087fA4A2A1FB6357269965A2014ABc35",  # WBTC/USDC Uniswap
    "bsc": "0x16b9a82891338f9bA80E2D6970FddA79D1eb0daE",  # BNB/USDT PancakeSwap
    "arbitrum": "0xC31E54c7a869B9FcBEcc14363CF510d1c41fa443",  # ETH/USDC
    "base": "0xd0b53D9277642d899DF5C87A3966A349A798F224",  # ETH/USDC
    "polygon_pos": "0xA374094527e1673A86dE625aa59517c5dE346d32"  # WMATIC/USDC
}

def get_ohlcv(pair_address: str, network: str = "eth", timeframe: str = "1h", max_retries: int = 3, use_proxy: bool = True):
    """
    Pega OHLCV do GeckoTerminal (com retry, backoff e proxy rotation)
    """
    import time
    
    # Mapear timeframe
    tf_map = {
        "1m": ("minute", 1),
        "5m": ("minute", 5),
        "15m": ("minute", 15),
        "30m": ("minute", 30),
        "1h": ("hour", 1),
        "4h": ("hour", 4),
        "1d": ("day", 1),
    }
    
    if timeframe not in tf_map:
        raise ValueError(f"Timeframe inválido. Use: {list(tf_map.keys())}")
    
    tf_type, aggregate = tf_map[timeframe]
    
    url = f"https://api.geckoterminal.com/api/v2/networks/{network}/pools/{pair_address}/ohlcv/{tf_type}"
    params = {"aggregate": aggregate, "limit": 100, "currency": "usd"}
    headers = {"Accept": "application/json", "User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"}
    
    resp = None
    last_error = None
    
    # Se tem proxies, aumentar tentativas
    actual_retries = max_retries * 3 if PROXY_LIST else max_retries
    
    for attempt in range(actual_retries):
        # Pegar proxy se disponível
        proxy = get_proxy() if use_proxy and PROXY_LIST else None
        
        try:
            resp = requests.get(url, params=params, headers=headers, proxies=proxy, timeout=30)
            
            if resp.status_code == 200:
                if proxy:
                    print(f"✅ Sucesso via proxy")
                break
            elif resp.status_code == 429:
                # Rate limit - trocar proxy ou esperar
                if PROXY_LIST:
                    print(f"⏳ Rate limit no proxy, tentando próximo... (tentativa {attempt + 1}/{actual_retries})")
                    time.sleep(1)
                else:
                    wait_time = min((attempt + 1) * 10, 30)
                    print(f"⏳ Rate limit, aguardando {wait_time}s... (tentativa {attempt + 1}/{actual_retries})")
                    time.sleep(wait_time)
            else:
                last_error = f"Erro API: {resp.status_code} - {resp.text}"
                raise Exception(last_error)
        except requests.exceptions.ProxyError as e:
            print(f"⚠️ Proxy falhou, tentando próximo...")
            last_error = str(e)
            continue
        except requests.exceptions.Timeout:
            print(f"⚠️ Timeout, tentando novamente...")
            last_error = "Timeout"
            continue
        except requests.exceptions.RequestException as e:
            print(f"⚠️ Erro de conexão: {e}")
            last_error = str(e)
            continue
    
    if resp is None or resp.status_code != 200:
        # Fallback: tentar sem proxy
        if PROXY_LIST and use_proxy:
            print("🔄 Proxies falharam, tentando direto...")
            try:
                resp = requests.get(url, params=params, headers=headers, timeout=30)
                if resp.status_code == 200:
                    print("✅ Sucesso sem proxy")
            except:
                pass
        
        if resp is None or resp.status_code != 200:
            raise Exception(f"Erro API após {actual_retries} tentativas: {last_error}")
    
    data = resp.json()
    ohlcv_list = data.get("data", {}).get("attributes", {}).get("ohlcv_list", [])
    
    if not ohlcv_list:
        raise Exception("Sem dados OHLCV")
    
    # Formato: [timestamp, open, high, low, close, volume]
    df = pd.DataFrame(ohlcv_list, columns=["timestamp", "Open", "High", "Low", "Close", "Volume"])
    df["Date"] = pd.to_datetime(df["timestamp"], unit="s")
    df = df.set_index("Date")
    df = df[["Open", "High", "Low", "Close", "Volume"]].astype(float)
    df = df.sort_index()
    
    return df

def get_pair_info(pair_address: str, network: str = "eth"):
    """Pega info do par pra título (com cache)"""
    
    # Tentar cache primeiro
    cached_name, cached_dex = get_cached_pair_info(pair_address, network)
    if cached_name:
        return cached_name, cached_dex
    
    # Buscar na API
    url = f"https://api.geckoterminal.com/api/v2/networks/{network}/pools/{pair_address}"
    headers = {"Accept": "application/json"}
    
    try:
        resp = requests.get(url, headers=headers)
        if resp.status_code == 200:
            data = resp.json()
            attrs = data.get("data", {}).get("attributes", {})
            name = attrs.get("name", "")
            # Tentar múltiplos campos para o nome da DEX
            dex = attrs.get("dex_id", "") or attrs.get("dex", {}).get("name", "")
            if not dex:
                # Extrair do relationships se disponível
                rels = data.get("data", {}).get("relationships", {})
                dex_data = rels.get("dex", {}).get("data", {})
                dex = dex_data.get("id", "DEX")
            
            dex = dex.upper().replace("_", " ")
            
            # Salvar no cache
            if name:
                cache_pair_info(pair_address, network, name, dex)
            
            return name, dex
    except:
        pass
    
    return None, None

def plot_chart(df: pd.DataFrame, title: str, timeframe: str, output: str = "dex_chart.png"):
    """Gera gráfico de candlestick com datas formatadas"""
    
    # Estilo dark degen
    mc = mpf.make_marketcolors(
        up='#00ff88', down='#ff4444',
        edge='inherit',
        wick='inherit',
        volume={'up': '#00ff8844', 'down': '#ff444444'}
    )
    
    style = mpf.make_mpf_style(
        base_mpf_style='nightclouds',
        marketcolors=mc,
        gridstyle='-',
        gridcolor='#333333',
        facecolor='#1a1a2e',
        figcolor='#1a1a2e',
        rc={
            'axes.labelcolor': 'white',
            'axes.edgecolor': '#333333',
            'xtick.color': 'white',
            'ytick.color': 'white'
        }
    )
    
    # Configurar formato de data baseado no timeframe E no range dos dados
    # Lógica: mostrar a unidade que faz sentido pro período
    first_date = df.index[0]
    last_date = df.index[-1]
    days_range = (last_date - first_date).days
    
    if timeframe in ["1m", "5m", "15m", "30m"]:
        if days_range >= 1:
            # Range > 1 dia → mostrar dia + hora
            date_format = "%d/%m %Hh"
            rotation = 45
        else:
            # Mesmo dia → só hora
            date_format = "%H:%M"
            rotation = 0
    elif timeframe in ["1h", "4h"]:
        if days_range >= 2:
            # Range > 2 dias → mostrar dia + hora
            date_format = "%d/%m %Hh"
            rotation = 45
        elif days_range >= 1:
            # Range 1-2 dias → mostrar dia abreviado + hora
            date_format = "%a %Hh"
            rotation = 30
        else:
            # Mesmo dia → só hora
            date_format = "%Hh"
            rotation = 0
    elif timeframe == "1d":
        if days_range > 365:
            # Range > 1 ano → mostrar mês/ano
            date_format = "%b/%y"
            rotation = 45
        elif days_range > 60:
            # Range > 2 meses → mostrar dia/mês
            date_format = "%d/%m"
            rotation = 45
        else:
            # Range mensal → dia/mês
            date_format = "%d/%m"
            rotation = 0
    else:
        date_format = "%d/%m %Hh"
        rotation = 45
    
    fig, axes = mpf.plot(
        df,
        type='candle',
        style=style,
        title=title,
        volume=True,
        savefig=dict(fname=output, dpi=150, bbox_inches='tight', facecolor='#1a1a2e'),
        figsize=(12, 8),
        returnfig=True,
        datetime_format=date_format,
        xrotation=rotation
    )
    
    print(f"✅ Gráfico salvo: {output}")
    return output

def main():
    parser = argparse.ArgumentParser(description="Gera gráfico de DEX com suporte a proxy rotation")
    parser.add_argument("--chain", "-c", default="eth", help="Rede (eth, bsc, arbitrum, base, polygon)")
    parser.add_argument("--pair", "-p", default=None, help="Endereço do par")
    parser.add_argument("--timeframe", "-t", default="1h", help="Timeframe (1m, 5m, 15m, 30m, 1h, 4h, 1d)")
    parser.add_argument("--output", "-o", default="dex_chart.png", help="Arquivo de saída")
    parser.add_argument("--title", default=None, help="Título do gráfico")
    parser.add_argument("--proxy-file", "-P", default=None, help="Arquivo com lista de proxies (um por linha)")
    parser.add_argument("--no-proxy", action="store_true", help="Desabilitar uso de proxies")
    
    args = parser.parse_args()
    
    # Carregar proxies
    if not args.no_proxy:
        load_proxies(args.proxy_file)
    
    # Normalizar rede
    network = NETWORKS.get(args.chain.lower(), args.chain.lower())
    
    # Par default se não especificado
    pair = args.pair or DEFAULT_PAIRS.get(network, DEFAULT_PAIRS["eth"])
    
    print(f"📊 Buscando: {network} | {pair[:10]}...{pair[-6:]} | {args.timeframe}")
    
    # Pegar dados
    df = get_ohlcv(pair, network, args.timeframe)
    print(f"📈 {len(df)} candles carregados")
    
    # Info do par pra título
    # Incluir range de datas/horas
    first_date = df.index[0]
    last_date = df.index[-1]
    
    if args.timeframe in ["1m", "5m", "15m", "30m", "1h", "4h"]:
        # Mostrar range de dias e horas
        if first_date.date() == last_date.date():
            range_str = f"{first_date.strftime('%d/%m')} ({first_date.strftime('%H:%M')} - {last_date.strftime('%H:%M')})"
        else:
            range_str = f"{first_date.strftime('%d/%m %H:%M')} → {last_date.strftime('%d/%m %H:%M')}"
    else:
        range_str = f"{first_date.strftime('%d/%m')} → {last_date.strftime('%d/%m')}"
    
    if args.title:
        title = args.title
    else:
        name, dex = get_pair_info(pair, network)
        if name:
            title = f"{name} ({dex}) | {args.timeframe} | {range_str}"
        else:
            title = f"DEX Chart | {args.timeframe} | {range_str}"
    
    # Gerar gráfico
    plot_chart(df, title, args.timeframe, args.output)
    
    # Mostrar último preço
    last = df.iloc[-1]
    print(f"💰 Último: ${last['Close']:,.2f}")

if __name__ == "__main__":
    main()
