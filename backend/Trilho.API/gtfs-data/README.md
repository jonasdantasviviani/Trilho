# GTFS Data Drop Folder

Coloque aqui os arquivos `.txt` extraídos do GTFS da SPTrans.

## Como atualizar

1. Baixe o GTFS em: https://www.sptrans.com.br/desenvolvedores/
2. Extraia o `.zip` diretamente nesta pasta
3. A API detecta automaticamente que os arquivos são mais novos que a última sync e reimporta tudo

## Arquivos esperados

| Arquivo            | Descrição                          |
|--------------------|-------------------------------------|
| `agency.txt`       | Operadoras                          |
| `routes.txt`       | Linhas de ônibus                    |
| `stops.txt`        | Paradas (ônibus + referências metro)|
| `trips.txt`        | Viagens                             |
| `calendar.txt`     | Calendário de serviço               |
| `stop_times.txt`   | Horários por parada                 |
| `frequencies.txt`  | Frequências (opcional)             |
| `shapes.txt`       | Traçados (opcional, não importado) |

## Status da última sync

Após cada importação bem-sucedida, o arquivo `.sync.json` é criado aqui com:
- `syncedAt` — data/hora UTC da importação
- `fileModifiedAt` — data do arquivo mais recente na pasta
- `source` — origem dos dados
- `counts` — quantidade de registros importados por tabela
