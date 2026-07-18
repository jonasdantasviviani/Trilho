# Integração Cittamobi - Guia de Reverse Engineering

## Visão Geral

O **Cittamobi** é um aplicativo de transporte público que possui parceria com a CPTM desde março de 2025. O app mostra a posição em tempo real dos trens. Nosso objetivo é descobrir como acessar esses dados.

## Estratégia

1. **Capturar tráfego de rede** do app Cittamobi usando mitmproxy
2. **Identificar endpoints** que retornam posição dos trens
3. **Analisar estrutura da resposta** para mapear campos
4. **Implementar integração** no `CitamobiProvider`

---

## Passo 1: Configurar o Proxy

### No Computador

```bash
# Instalar mitmproxy
pip install mitmproxy

# Executar o script de captura
cd scripts
mitmdump -s cittamobi_capture.py
```

O proxy ficará escutando na porta 8080.

### No Celular/Emulador

1. Configure o proxy Wi-Fi:
   - **Endereço**: IP do seu computador
   - **Porta**: 8080

2. Acesse `http://mitm.it` para instalar o certificado SSL

### Alternativa: Emulador Android Studio

1. Execute o emulador
2. Configure o proxy nas configurações de Wi-Fi do emulador
3. Ou execute via linha de comando:
```bash
emulator -avd Pixel_6 -http-proxy http://localhost:8080
```

---

## Passo 2: Capturar Requests

1. Com o proxy rodando, abra o app **Cittamobi**
2. Selecione uma linha de trem (CPTM)
3. Aguarde a atualização da posição dos trens
4. Os requests serão salvos em `cittamobi_requests.json`

---

## Passo 3: Analisar Resultados

Abra o arquivo `cittamobi_requests.json`:

```json
[
  {
    "timestamp": "2026-03-22T10:30:00",
    "method": "GET",
    "url": "https://api.cittamobi.com.br/v1/...",
    "response": {
      "status_code": 200,
      "body_preview": { ... }
    }
  }
]
```

### Procure por:
- Endpoints com `/trains`, `/vehicles`, `/positions`, `/cptm`
- Respostas com campos `latitude`, `longitude`, `line_code`, `vehicle_id`
- Headers de autenticação (`Authorization`, `X-API-Key`)

---

## Passo 4: Implementar

Quando descobrir o endpoint, atualize `CitamobiProvider.cs`:

```csharp
// Exemplo de estrutura esperada
public class CittamobiResponse
{
    public List<Vehicle>? Vehicles { get; set; }
}

public class Vehicle
{
    public string? LineCode { get; set; }
    public double Latitude { get; set; }
    public double Longitude { get; set; }
    public long Timestamp { get; set; }
}
```

### Configuração

Adicione ao `.env`:
```bash
CITTAMOBI_API_KEY=sua_chave_aqui
```

---

## Dados Atuais

### Mock Implementado

Por enquanto, o `CitamobiProvider` retorna dados mockados para as linhas CPTM:

| Linha | Cód |
|-------|-----|
| 7 - Rubi | 7-RUBI |
| 8 - Diamante | 8-DIAMANTE |
| 9 - Esmeralda | 9-ESMERALDA |
| 10 - Turquesa | 10-TURQUESA |
| 11 - Coral | 11-CORAL |
| 12 - Safira | 12-SAFIRA |
| 13 - Jade | 13-JADE |

### Worker

O `TrainPositionWorker` busca posições a cada 30 segundos e armazena em cache Redis.

### Endpoints

| Método | Endpoint | Descrição |
|--------|----------|-----------|
| GET | `/api/trains/positions` | Todas as posições de trens |
| GET | `/api/lines/{code}/vehicles` | Posições de uma linha específica |

---

## Scripts Disponíveis

| Script | Descrição |
|--------|-----------|
| `cittamobi_capture.py` | Script mitmproxy para capturar requests |

---

## Recursos

- [mitmproxy docs](https://docs.mitmproxy.org/)
- [Cittamobi Play Store](https://play.google.com/store/apps/details?id=br.com.cittamobi)
- [CPTM Open Data](http://www.cptm.sp.gov.br/transparencia/)
