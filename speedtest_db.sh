#!/bin/bash

## Descrição: Este script Bash automatiza o teste de velocidade da conexão à internet usando o speedtest-cli da Ookla.
## Ele instala o speedtest-cli do repositório do Debian para obter resultados dos testes.
## Além disso, cria um banco de dados MySQL para armazenar resultados bem-sucedidos e erros dos testes.

## Principais funcionalidades incluem:
## Configuração do Speedtest: Verifica e instala o speedtest-cli com o apt.
## - Configuração do Banco de Dados MySQL: Criação de usuário, banco de dados, tabelas para resultados e para erros.
## - Execução do Teste de Velocidade: Utiliza o speedtest-cli para realizar o teste, registrando a saída em
##   speedtest.log e os erros em speedtest_error.log.
## - Armazenamento de Resultados: Insere os dados bem-sucedidos do teste na tabela speedtest_results para análise posterior.
## - Registro de Erros: Captura e registra mensagens de erro na tabela speedtest_errors quando o teste falha.

## Este script facilita a monitorização automatizada da qualidade da conexão à internet,
## permitindo análise e histórico dos resultados e erros ao longo do tempo.

## Autor: Glauber GF (@mcnd2)
## Data: 07/07/2024.
## Atualização: 15/07/2024.

# ========== #

## Instalar o Speedtest.

## Se estiver migrando de instruções de instalação anteriores, execute primeiro.
#sudo rm /etc/apt/sources.list.d/speedtest.list
#sudo apt-get update
#sudo apt-get remove speedtest

## Outros binários não oficiais entrarão em conflito com o Speedtest CLI.
## Exemplo de como remover usando o apt-get
#sudo apt-get remove speedtest-cli

## Repositório da Ookla.
#sudo apt-get install curl -s
#curl -s https://packagecloud.io/install/repositories/ookla/speedtest-cli/script.deb.sh | sudo bash
#sudo apt-get install speedtest

## Repositório do Debian.
## Verifica se o pacote speedtest-cli está instalado.
if ! dpkg -s speedtest-cli &> /dev/null; then
    # Instala speedtest-cli se não estiver instalado
    sudo apt install speedtest-cli -y &> /dev/null
fi

# ========== #

## Variáveis de conexão com o banco de dados.
DB_ROOT_USER="root"
DB_ROOT_PASS="root_passwd"
DB_USER="speedtest_user"
DB_PASS="speedtest_passwd"
DB_NAME="speedtest_db"

## Criar banco de dados se não existir.
CreateBase="CREATE DATABASE IF NOT EXISTS \`$DB_NAME\`;"

mysql -u"$DB_ROOT_USER" -p"$DB_ROOT_PASS" -e "$CreateBase"

## Criar usuário e conceder privilégios.
CreateUser="CREATE USER IF NOT EXISTS \`$DB_USER\`@'%' IDENTIFIED BY '$DB_PASS';
GRANT ALL PRIVILEGES ON \`$DB_NAME\`.* TO \`$DB_USER\`@'%';
FLUSH PRIVILEGES;"

mysql -u"$DB_ROOT_USER" -p"$DB_ROOT_PASS" -e "$CreateUser"

## Criar tabela de resultados se não existir.
CreateTableResults="CREATE TABLE IF NOT EXISTS \`speedtest_results\` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    provider VARCHAR(255),
    ip VARCHAR(45),
    server VARCHAR(255),
    city VARCHAR(255),
    distance FLOAT,
    ping FLOAT,
    download FLOAT,
    upload FLOAT,
    url TEXT
);"

mysql -u"$DB_USER" -p"$DB_PASS" -D "$DB_NAME" -e "$CreateTableResults"

## Criar tabela de erros se não existir.
CreateTableErrors="CREATE TABLE IF NOT EXISTS \`speedtest_errors\` (
    id INT AUTO_INCREMENT PRIMARY KEY,
    timestamp TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    error_message TEXT
);"

mysql -u"$DB_USER" -p"$DB_PASS" -D "$DB_NAME" -e "$CreateTableErrors"

## Caminho completo para os logs.
LOG_FILE="/path/do/seu/projeto/speedtest.log"
ERROR_LOG_FILE="/path/do/seu/projeto/speedtest_error.log"

## Comando para executar speedtest direcionando as saídas padrão e de erro.
speedtest-cli --secure --share > "$LOG_FILE" 2> "$ERROR_LOG_FILE"

## Verificar o código de saída do Speedtest.
speedtest_exit_code=$?

if [ $speedtest_exit_code -ne 0 ]; then
    SpeedtestErro=$(cat "$ERROR_LOG_FILE")

    ## Inserir dados de erro na tabela speedtest_errors.
    EnterError="INSERT INTO \`speedtest_errors\` (error_message) VALUES ('$SpeedtestErro');"
    mysql -u"$DB_USER" -p"$DB_PASS" -D "$DB_NAME" -e "$EnterError"
else
    ## Extrair os dados do speedtest.log.
    SpeedtestProvider=$(sed -n 's/.*from \(.*\) (.*/\1/p' "$LOG_FILE")
    SpeedtestIP=$(sed -n 's/.*from [^(]*(\([^)]*\)).*/\1/p' "$LOG_FILE")
    SpeedtestServer=$(sed -n 's/.*Hosted by \(.*\) (.*/\1/p' "$LOG_FILE")
    SpeedtestCity=$(sed -n 's/.*Hosted by [^(]* (\([^]]*\)).*/\1/p' "$LOG_FILE")
    SpeedtestDistance=$(sed -n '/Hosted by/ { s/.*\[//; s/\s*km.*//; p }' "$LOG_FILE")
    SpeedtestPing=$(sed -n '/Hosted by/ { s/.*\://; s/\s*ms.*//; p }' "$LOG_FILE")
    SpeedtestDownload=$(sed -n 's/^\s*Download:\s*\([0-9.]*\) [A-Za-z]*\/s.*/\1/p' "$LOG_FILE")
    SpeedtestUpload=$(sed -n 's/^\s*Upload:\s*\([0-9.]*\) [A-Za-z]*\/s.*/\1/p' "$LOG_FILE")
    SpeedtestURL=$(sed -n 's/Share results: \(http:\/\/www.speedtest.net\/result\/[0-9]*.png\)/\1/p' "$LOG_FILE")

    ## Inserir dados completos no banco de dados na tabela speedtest_results.
    EnterData="INSERT INTO \`speedtest_results\` (
        provider,
        ip,
        server,
        city,
        distance,
        ping,
        download,
        upload,
        url)
        VALUES (
        '$SpeedtestProvider',
        '$SpeedtestIP',
        '$SpeedtestServer',
        '$SpeedtestCity',
        '$SpeedtestDistance',
        '$SpeedtestPing',
        '$SpeedtestDownload',
        '$SpeedtestUpload',
        '$SpeedtestURL'
    );"

    ## Inserir dados no banco de dados.
    mysql -u"$DB_USER" -p"$DB_PASS" -D "$DB_NAME" -e "$EnterData"
fi
