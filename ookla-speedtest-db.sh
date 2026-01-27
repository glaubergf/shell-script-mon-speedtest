#!/bin/bash

## ==========================================================
## Descrição:
## Script Bash para monitoramento contínuo de qualidade de
## conexão usando o Speedtest oficial da Ookla (CLI).
##
## Necessário ter o speedtest instalado via repositório oficial,
## ou com o binário baixado diretamente do site da Ookla.
## url: https://www.speedtest.net/apps/cli
## Após baixar o binário, certifique-se de movê-lo para
## /usr/local/bin/ e dar permissão de execução:
## sudo install -m 0755 speedtest /usr/local/bin/speedtest
##
## Requisitos:
## - MySQL/MariaDB instalado e em execução
##
## Funcionalidades:
## - Executa teste de velocidade (download, upload, latência)
## - Coleta jitter (latência, download e upload)
## - Armazena resultados em banco MySQL
## - Registra erros de execução
##
## Regras:
## - Idle latency/jitter mostram a saúde da estrada
## - Download/upload jitter mostram o trânsito
## - O jitter ideal é < 20ms, > 20ms indica instabilidade
## - Quanto menor, melhor a qualidade
##
## Ideal para execução via cron facilitando a coleta periódica
## de dados para análise histórica de monitoramento.
## Integração direta com Grafana.
##
## Autor: Glauber GF (@mcnd2)
## Data: 07/07/2024
## Atualização: 28/12/2025
## Nome do arquivo: ookla-speedtest-db.sh
## ==========================================================

set -o pipefail

# ================================
# Configurações gerais
# ================================

# Caminho do binário oficial do Speedtest (Ookla)
SPEEDTEST_BIN="/usr/local/bin/speedtest"

# Diretório base do projeto
BASE_DIR="/root/ookla_speedtest"

# Arquivos de log
LOG_FILE="$BASE_DIR/speedtest.log"
ERROR_LOG_FILE="$BASE_DIR/speedtest-error.log"

# Criar diretório base se não existir
mkdir -p "$BASE_DIR"

# ================================
# Configurações do banco de dados
# ================================

DB_ROOT_USER="root"
DB_ROOT_PASS="root_passwd"

DB_USER="speedtest_user"
DB_PASS="speedtest_passwd"
DB_NAME="speedtest_db"

# ================================
# Funções auxiliares
# ================================

# Sanitiza strings para evitar quebra de SQL
sanitize() {
    echo "$1" | sed "s/'/''/g"
}

# ================================
# Preparação do banco de dados
# ================================

mysql -u"$DB_ROOT_USER" -p"$DB_ROOT_PASS" <<EOF
CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;
CREATE USER IF NOT EXISTS '$DB_USER'@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO '$DB_USER'@'%';
FLUSH PRIVILEGES;
EOF

# Tabela de resultados (Ookla)
mysql -u"$DB_USER" -p"$DB_PASS" -D "$DB_NAME" <<EOF
CREATE TABLE IF NOT EXISTS speedtest_ookla_results (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    provider VARCHAR(255),
    server VARCHAR(255),
    city VARCHAR(255),
    server_id INT,
    latency_ms FLOAT,
    jitter_idle_ms FLOAT,
    download_mbps FLOAT,
    jitter_download_ms FLOAT,
    upload_mbps FLOAT,
    jitter_upload_ms FLOAT,
    packet_loss FLOAT,
    result_url TEXT
);
EOF

# Tabela de erros
mysql -u"$DB_USER" -p"$DB_PASS" -D "$DB_NAME" <<EOF
CREATE TABLE IF NOT EXISTS speedtest_ookla_errors (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    error_message TEXT
);
EOF

# ================================
# Execução do Speedtest
# ================================

"$SPEEDTEST_BIN" > "$LOG_FILE" 2> "$ERROR_LOG_FILE"

# Verificar o código de saída do Speedtest.
SPEEDTEST_EXIT_CODE=$?

# ================================
# Tratamento de erro / sucesso
# ================================

if [ $SPEEDTEST_EXIT_CODE -ne 0 ]; then
    ERROR_MSG=$(sanitize "$(cat "$ERROR_LOG_FILE")")

    mysql -u"$DB_USER" -p"$DB_PASS" -D "$DB_NAME" <<EOF
INSERT INTO speedtest_ookla_errors (error_message)
VALUES ('$ERROR_MSG');
EOF

    exit 1

else
    # Sucesso - gravar linha SEM erro
    mysql -u"$DB_USER" -p"$DB_PASS" -D "$DB_NAME" <<EOF
INSERT INTO speedtest_ookla_errors (error_message)
VALUES (NULL);
EOF
fi

# ================================
# Extração dos dados (sed)
# ================================

SERVER=$(sed -n 's/^ *Server: \(.*\) - .*$/\1/p' "$LOG_FILE")
CITY=$(sed -n 's/^ *Server: .* - \(.*\) (id.*$/\1/p' "$LOG_FILE")
SERVER_ID=$(sed -n 's/^ *Server: .* (id: \([0-9]*\)).*/\1/p' "$LOG_FILE")
PROVIDER=$(sed -n 's/^ *ISP: \(.*\)$/\1/p' "$LOG_FILE")

LATENCY=$(sed -n 's/^Idle Latency:[[:space:]]*\([0-9.]*\) ms.*/\1/p' "$LOG_FILE")
JITTER_IDLE=$(sed -n 's/.*Idle Latency:.*(jitter: \([0-9.]*\)ms.*/\1/p' "$LOG_FILE")

DOWNLOAD=$(sed -n 's/^.*Download: *\([0-9.]\+\) Mbps.*/\1/p' "$LOG_FILE")
UPLOAD=$(sed -n 's/^.*Upload: *\([0-9.]\+\) Mbps.*/\1/p' "$LOG_FILE")

# Download e Upload têm jitter na linha de baixo, não na mesma linha.
# Por isso usamos um bloco (robusto) para capturar o valor correto.
JITTER_DOWNLOAD=$(awk '
/^[[:space:]]*Download:/ {
    getline
    if (match($0, /jitter:[[:space:]]*([0-9.]+)ms/, a))
        print a[1]
}' "$LOG_FILE")

JITTER_UPLOAD=$(awk '
/^[[:space:]]*Upload:/ {
    getline
    if (match($0, /jitter:[[:space:]]*([0-9.]+)ms/, a))
        print a[1]
}' "$LOG_FILE")

PACKET_LOSS=$(sed -n 's/^ Packet Loss:[[:space:]]*\([0-9.]*\)%.*/\1/p' "$LOG_FILE")
RESULT_URL=$(sed -n 's/^ *Result URL: \(.*\)$/\1/p' "$LOG_FILE")

# Sanitização final
PROVIDER=$(sanitize "$PROVIDER")
SERVER=$(sanitize "$SERVER")
CITY=$(sanitize "$CITY")
RESULT_URL=$(sanitize "$RESULT_URL")

# ================================
# Inserção no banco de dados
# ================================

mysql -u"$DB_USER" -p"$DB_PASS" -D "$DB_NAME" <<EOF
INSERT INTO speedtest_ookla_results (
    provider,
    server,
    city,
    server_id,
    latency_ms,
    jitter_idle_ms,
    download_mbps,
    jitter_download_ms,
    upload_mbps,
    jitter_upload_ms,
    packet_loss,
    result_url
) VALUES (
    '$PROVIDER',
    '$SERVER',
    '$CITY',
    '$SERVER_ID',
    '$LATENCY',
    '$JITTER_IDLE',
    '$DOWNLOAD',
    '$JITTER_DOWNLOAD',
    '$UPLOAD',
    '$JITTER_UPLOAD',
    '$PACKET_LOSS',
    '$RESULT_URL'
);
EOF

exit 0
