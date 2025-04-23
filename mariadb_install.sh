#!/bin/bash

# Função para verificar se um pacote está instalado
is_installed() {
    dpkg -l | grep -q "$1"
}

# Verifica se o MariaDB Server e Client já estão instalados
if is_installed mariadb-server && is_installed mariadb-client; then
    echo "MariaDB Server e Client já estão instalados. Abortando a instalação."
    exit 0
fi

# Atualiza a lista de pacotes
echo "Atualizando a lista de pacotes..."
apt update

# Instala o MariaDB Server e Client
echo "Instalando o MariaDB Server e Client..."
apt install -y mariadb-server mariadb-client

# Verifica se a instalação foi bem-sucedida
if is_installed mariadb-server && is_installed mariadb-client; then
    echo "MariaDB Server e Client foram instalados com sucesso."
else
    echo "Falha na instalação do MariaDB Server e/ou Client."
    exit 1
fi

# Cria e configura o MariaDB de forma não interativa
echo "Configurando o MariaDB..."

# Cria um script SQL para configuração
cat <<EOF > /tmp/mariadb_secure_install.sql
-- Cria um novo usuário e atribui uma senha
SET PASSWORD FOR 'root'@'localhost' = PASSWORD('root_passwd');

-- Remove usuários anônimos
DROP USER IF EXISTS ''@'localhost';
DROP USER IF EXISTS ''@'$(hostname)';

-- Remove o banco de dados de teste
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';

-- Recarrega as tabelas de privilégios
FLUSH PRIVILEGES;
EOF

# Executa o script SQL
mysql < /tmp/mariadb_secure_install.sql

# Remove o arquivo SQL temporário
rm /tmp/mariadb_secure_install.sql

echo "Instalação e configuração concluídas."
