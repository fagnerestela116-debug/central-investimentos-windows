from pathlib import Path
import requests
from flask import Flask, jsonify

app = Flask(__name__)

BASE = Path("/home/fagner/Investimentos/Central")
TOKEN_FILE = BASE / "brapi0token.txt"
DADOS_FILE = BASE / "central-dados.json"

def ler_dados():
    import json
    if not DADOS_FILE.exists():
        return {"carteira": [], "historico": []}
    try:
        dados = json.loads(DADOS_FILE.read_text(encoding="utf-8"))
        if not isinstance(dados, dict):
            return {"carteira": [], "historico": []}
        return {
            "carteira": dados.get("carteira") if isinstance(dados.get("carteira"), list) else [],
            "historico": dados.get("historico") if isinstance(dados.get("historico"), list) else []
        }
    except Exception:
        return {"carteira": [], "historico": []}

def gravar_dados(dados):
    import json
    temporario = DADOS_FILE.with_suffix(".tmp")
    temporario.write_text(
        json.dumps(dados, ensure_ascii=False, indent=2),
        encoding="utf-8"
    )
    temporario.replace(DADOS_FILE)


def obter_token():
    if not TOKEN_FILE.exists():
        return None
    token = TOKEN_FILE.read_text(encoding="utf-8").strip()
    return token or None

@app.route("/")
def inicio():
    return (BASE / "central-investimentos.html").read_text(encoding="utf-8")


def obter_gold11_b3():
    """Obtém exclusivamente a cotação do GOLD11 diretamente da página da B3."""
    try:
        import re

        url = "https://borainvestir.b3.com.br/cotacoes/etfs/GOLD11/"
        r = requests.get(
            url,
            headers={
                "User-Agent": "Mozilla/5.0",
                "Accept": "text/html,application/xhtml+xml"
            },
            timeout=15
        )

        if not r.ok:
            return None

        m = re.search(
            r'<span[^>]*asset__info__value[^>]*>\s*([0-9]+,[0-9]+)\s*</span>\s*'
            r'<p[^>]*>\s*Valor atual\s*\(R\$\)',
            r.text,
            re.I | re.S
        )

        if not m:
            return None

        return float(m.group(1).replace(".", "").replace(",", "."))

    except Exception:
        return None

@app.get("/cotacao/<tickers>")
def cotacao(tickers):
    token = obter_token()

    simbolos = tickers.upper().replace(" ", "")
    url = "https://brapi.dev/api/v2/stocks/quote"

    headers = {}
    if token:
        headers["Authorization"] = f"Bearer {token}"

    try:
        r = requests.get(
            url,
            params={"symbols": simbolos},
            headers=headers,
            timeout=10
        )

        # BRAPI funcionando normalmente
        if r.ok:
            return jsonify(r.json())

        # Se a BRAPI estiver limitada, usa automaticamente
        # a fonte alternativa já existente na Central.
        if r.status_code == 429:
            resultados = []

            for ticker in simbolos.split(","):
                ticker = ticker.strip().upper()

                if not ticker:
                    continue

                try:
                    # GOLD11: fonte B3 quando BRAPI estiver em 429
                    if ticker == "GOLD11":
                        preco_gold = obter_gold11_b3()

                        if preco_gold is not None:
                            resultados.append({
                                "symbol": "GOLD11",
                                "regularMarketPrice": preco_gold,
                                "preco": preco_gold,
                                "tipo": "etf",
                                "fonte": "B3"
                            })
                            continue

                    url_capital = f"https://capitalagora.com.br/api/ativo/{ticker}"
                    rc = requests.get(url_capital, timeout=10)

                    if rc.ok:
                        dados = rc.json()
                        preco = dados.get("preco")

                        if preco is not None:
                            resultados.append({
                                "symbol": ticker,
                                "regularMarketPrice": preco,
                                "preco": preco,
                                "data": dados.get("data"),
                                "tipo": dados.get("tipo")
                            })
                            continue

                    resultados.append({
                        "symbol": ticker,
                        "erro": f"Falha na fonte alternativa HTTP {rc.status_code}"
                    })

                except Exception as e:
                    resultados.append({
                        "symbol": ticker,
                        "erro": str(e)
                    })

            return jsonify({
                "results": resultados,
                "fonte": "Capital Agora (fallback BRAPI)"
            })

        return jsonify(r.json()), r.status_code

    except requests.RequestException as e:
        # Falha de conexão com BRAPI: tenta fonte alternativa.
        resultados = []

        for ticker in simbolos.split(","):
            ticker = ticker.strip().upper()

            if not ticker:
                continue

            try:
                if ticker == "GOLD11":
                    preco_gold = obter_gold11_b3()

                    if preco_gold is not None:
                        resultados.append({
                            "symbol": "GOLD11",
                            "regularMarketPrice": preco_gold,
                            "preco": preco_gold,
                            "tipo": "etf",
                            "fonte": "B3"
                        })
                        continue

                url_capital = f"https://capitalagora.com.br/api/ativo/{ticker}"
                rc = requests.get(url_capital, timeout=10)

                if rc.ok:
                    dados = rc.json()
                    preco = dados.get("preco")

                    if preco is not None:
                        resultados.append({
                            "symbol": ticker,
                            "regularMarketPrice": preco,
                            "preco": preco,
                            "data": dados.get("data"),
                            "tipo": dados.get("tipo")
                        })
                        continue

                resultados.append({
                    "symbol": ticker,
                    "erro": f"Falha na fonte alternativa HTTP {rc.status_code}"
                })

            except Exception as erro:
                resultados.append({
                    "symbol": ticker,
                    "erro": str(erro)
                })

        return jsonify({
            "results": resultados,
            "fonte": "Capital Agora (fallback por conexão)"
        })


@app.get("/cripto")
def cripto():
    url = "https://api.coingecko.com/api/v3/simple/price"
    parametros = {
        "ids": "bitcoin,shiba-inu",
        "vs_currencies": "brl",
        "include_last_updated_at": "true"
    }

    try:
        r = requests.get(
            url,
            params=parametros,
            timeout=10
        )

        dados = r.json()

        if not r.ok:
            return jsonify({
                "erro": "Falha ao consultar criptomoedas",
                "detalhe": dados
            }), r.status_code

        return jsonify(dados)

    except requests.RequestException as e:
        return jsonify({
            "erro": "Falha ao acessar serviço de criptomoedas",
            "detalhe": str(e)
        }), 502


@app.get("/renda-fixa")
def renda_fixa():
    """
    Retorna a taxa CDI mais recente disponível na série 12 do
    Banco Central do Brasil e sua equivalência anual aproximada.
    Série 12 = Interest rate - CDI (% ao dia útil).
    """
    url = "https://api.bcb.gov.br/dados/serie/bcdata.sgs.12/dados/ultimos/1"

    try:
        r = requests.get(url, timeout=10)

        if not r.ok:
            return jsonify({
                "erro": "Falha ao consultar CDI no Banco Central",
                "status": r.status_code
            }), r.status_code

        dados = r.json()

        if not dados:
            return jsonify({
                "erro": "Banco Central não retornou dados do CDI"
            }), 502

        registro = dados[-1]

        valor_diario = float(
            str(registro["valor"]).replace(",", ".")
        )

        # Conversão aproximada da taxa diária para taxa anual
        # considerando 252 dias úteis.
        taxa_diaria = valor_diario / 100.0
        taxa_anual = ((1 + taxa_diaria) ** 252 - 1) * 100

        return jsonify({
            "fonte": "Banco Central do Brasil",
            "serie": 12,
            "data": registro.get("data"),
            "cdi_diario": valor_diario,
            "cdi_anual": round(taxa_anual, 6)
        })

    except (requests.RequestException, ValueError, KeyError) as e:
        return jsonify({
            "erro": "Falha ao consultar CDI",
            "detalhe": str(e)
        }), 502


@app.get("/capital/<tickers>")
def cotacao_capital(tickers):
    resultados = []

    for ticker in tickers.upper().replace(" ", "").split(","):
        if not ticker:
            continue

        try:
            url = f"https://capitalagora.com.br/api/ativo/{ticker}"
            r = requests.get(url, timeout=10)

            if not r.ok:
                resultados.append({
                    "symbol": ticker,
                    "erro": f"HTTP {r.status_code}"
                })
                continue

            dados = r.json()
            preco = dados.get("preco")

            if preco is None:
                resultados.append({
                    "symbol": ticker,
                    "erro": "Cotação não encontrada"
                })
                continue

            resultados.append({
                "symbol": ticker,
                "regularMarketPrice": preco,
                "preco": preco,
                "data": dados.get("data"),
                "tipo": dados.get("tipo")
            })

        except Exception as e:
            resultados.append({
                "symbol": ticker,
                "erro": str(e)
            })

    return jsonify({
        "results": resultados,
        "fonte": "Capital Agora"
    })

@app.get("/status")
def status():
    return jsonify({
        "central": "online",
        "brapi_token": bool(obter_token()),
        "servidor": True,
        "crypto_endpoint": True
    })


# RV415_GARE_BRAPI_FIX_START
@app.route("/cotacao_gare/<ticker>")
def cotacao_gare_especifica(ticker):
    ticker = ticker.upper().strip()

    if ticker != "GARE11":
        return jsonify({"erro": "ticker não permitido nesta rota"}), 400

    import requests

    token = ""
    for nome in ("brapi0token.txt", "brapi_token.txt", "brapi@token.txt"):
        arq = Path(nome)
        if arq.exists():
            token = arq.read_text(encoding="utf-8").strip()
            if token:
                break

    try:
        headers = {}
        if token:
            headers["Authorization"] = f"Bearer {token}"

        r = requests.get(
            "https://brapi.dev/api/quote/GARE11",
            headers=headers,
            timeout=8
        )

        if r.ok:
            dados = r.json()
            resultados = dados.get("results") or []

            if resultados:
                item = resultados[0]
                preco = item.get("regularMarketPrice") or item.get("price")

                if preco is not None and float(preco) > 0:
                    return jsonify({
                        "fonte": "BRAPI /api/quote/GARE11",
                        "symbol": "GARE11",
                        "preco": float(preco),
                        "regularMarketPrice": float(preco)
                    })

    except Exception:
        pass

    return jsonify({
        "fonte": "BRAPI GARE11 indisponível",
        "symbol": "GARE11",
        "preco": None,
        "regularMarketPrice": None
    }), 503
# RV415_GARE_BRAPI_FIX_END

app.run(host="0.0.0.0", port=8765)
