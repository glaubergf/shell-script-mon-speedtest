#!/bin/bash

## Caminho do script a ser adicionado ao cron.
PATH_SCRIPT="/home/mcnd2/Projetos/shell-script-mon-speedtest/db-grafana/speedtest.sh"
CRON_ENTRY="*/5 * * * * /bin/bash $PATH_SCRIPT"
CRON_COMMENT="# Essa linha executa a cada 5 minutos o speedtest salvando o resultado no banco de dados speedtest_grafana de acordo com o script."

## Verificar se a entrada já existe no crontab.
if ! sudo crontab -u root -l 2>/dev/null | grep -Fxq "$CRON_ENTRY"; then
    # Se a entrada não existir, adicione-a com o comentário.
    (sudo crontab -u root -l 2>/dev/null; echo "$CRON_COMMENT"; echo "$CRON_ENTRY") | sudo crontab -u root -
fi
