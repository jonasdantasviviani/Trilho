#!/usr/bin/env python3
"""
MITM Proxy Script para capturar requests do app Cittamobi
e descobrir os endpoints da API de posição de trens CPTM.

Uso:
    1. Instale mitmproxy: pip install mitmproxy
    2. Execute este script: mitmdump -s cittamobi_capture.py
    3. Configure o proxy no celular/emulador
    4. Abra o app Cittamobi
    5. Veja os requests capturados em cittamobi_requests.json

Requisitos:
    pip install mitmproxy
"""

import json
from datetime import datetime
from mitmproxy import http, ctx

requests_file = "cittamobi_requests.json"
requests_data = []


def request(flow: http.HTTPFlow):
    """Captura todos os requests para api.cittamobi.com.br"""

    if "cittamobi" in flow.request.pretty_host.lower():
        request_info = {
            "timestamp": datetime.now().isoformat(),
            "method": flow.request.method,
            "url": flow.request.pretty_url,
            "host": flow.request.pretty_host,
            "path": flow.request.path,
            "headers": dict(flow.request.headers),
            "query": flow.request.query,
        }

        # Remove headers sensíveis
        sensitive_headers = ["authorization", "cookie", "x-api-key"]
        for header in sensitive_headers:
            if header in request_info["headers"]:
                request_info["headers"][header] = "[REDACTED]"

        requests_data.append(request_info)

        ctx.log.info(f"Captured: {flow.request.method} {flow.request.path}")

        # Salva periodicamente
        with open(requests_file, "w") as f:
            json.dump(requests_data, f, indent=2)


def response(flow: http.HTTPFlow):
    """Captura as respostas da API"""

    if "cittamobi" in flow.request.pretty_host.lower():
        try:
            response_info = {
                "timestamp": datetime.now().isoformat(),
                "url": flow.request.pretty_url,
                "status_code": flow.response.status_code,
                "content_type": flow.response.headers.get("content-type", ""),
            }

            # Tenta parsear JSON
            try:
                response_info["body_preview"] = flow.response.json()
            except:
                response_info["body_preview"] = (
                    flow.response.text[:500] if flow.response.text else ""
                )

            # Adiciona à lista
            for req in requests_data:
                if req["url"] == flow.request.pretty_url:
                    req["response"] = response_info
                    break

            ctx.log.info(
                f"Response: {flow.response.status_code} for {flow.request.path}"
            )

            with open(requests_file, "w") as f:
                json.dump(requests_data, f, indent=2)

        except Exception as e:
            ctx.log.error(f"Error capturing response: {e}")


def done():
    """Quando o proxy é encerrado"""
    print(f"\n{'=' * 60}")
    print("Capture concluída!")
    print(f"Total de requests capturados: {len(requests_data)}")
    print(f"Dados salvos em: {requests_file}")
    print(f"{'=' * 60}")
