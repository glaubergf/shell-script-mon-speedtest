<!---
Projeto: shell-script-mon-speedtest
---
Descrição: Este script Bash automatiza o teste de velocidade da conexão à internet
utilizando o Speedtest CLI oficial da Ookla (binário distribuído pelo site da Speedtest). 
A mudança em relação à versão anterior baseada no pacote speedtest-cli do repositório Debian 
foi motivada por maior confiabilidade, consistência de métricas e redução de erros 
intermitentes. Os resultados e falhas são coletados de forma robusta e armazenados em um 
banco de dados MariaDB (MySQL), permitindo monitoramento contínuo via Grafana.
---
Autor: Glauber GF (@mcnd2)
Data: 15/07/2024
Atualizado: 28/12/2025
--->

# Script para Teste de Velocidade com Speedtest by Ookla e Monitoramento via Grafana.

![Image](https://github.com/glaubergf/shell-script-mon-speedtest/blob/main/images/speedtest_ookla_results.png)
![Image](https://github.com/glaubergf/shell-script-mon-speedtest/blob/main/images/speedtest_ookla_grafana1.png)
![Image](https://github.com/glaubergf/shell-script-mon-speedtest/blob/main/images/speedtest_ookla_grafana2.png)

A **[Speedtest by Ookla](https://www.speedtest.net/pt)** é uma ferramenta amplamente reconhecida para medir o desempenho e a qualidade de conexões de internet. O **Speedtest CLI oficial da Ookla** é um aplicativo nativo para Linux, mantido pela própria Ookla, oferecendo maior fidelidade nos testes, métricas mais completas e melhor compatibilidade com a infraestrutura atual dos servidores Speedtest.

Este projeto foi originalmente baseado no **speedtest-cli** disponível nos repositórios do Debian. No entanto, após análises e testes práticos, o script foi migrado para utilizar o **Speedtest CLI oficial da Ookla**, obtido diretamente do site do fornecedor.

Além disso, o projeto utiliza ferramentas clássicas de shell como **awk**, **sed** e **grep** para extração robusta de métricas a partir do log do Speedtest, armazenando os dados em tabelas MariaDB para posterior visualização e análise no Grafana.

## Motivo da migração: speedtest-cli (Debian) → speedtest (Ookla)

A troca não foi apenas estética ou de preferência, mas técnica e operacional.

### Limitações do speedtest-cli (Debian)

- Projeto não oficial, mantido por terceiros.
- Saída de texto inconsistente entre versões.
- Erros recorrentes de execução em determinados horários (00 e 30 minutos).
- Falhas frequentes como:

  * `Unable to connect to servers to test latency`
  * `HTTP Error 403: Forbidden`

- Dependência do campo `Hosted by`, que em diversos cenários não é retornado, causando:

  * Execução travada
  * Registro incorreto de erro

- Métricas limitadas, sem informações detalhadas de jitter, packet loss e latência por fase.

### Vantagens do Speedtest CLI oficial (Ookla)

- Ferramenta oficial mantida pela Ookla.
- Formato de saída estável e previsível.
- Métricas avançadas de qualidade de conexão:

  * Idle Latency
  * Jitter (download e upload)
  * Packet Loss
  * Latência mínima, média e máxima

- Menor incidência de bloqueios e erros 403.
- Melhor aderência a ambientes de monitoramento contínuo.

## Exemplo de saída – Speedtest CLI (Ookla)

```bash
$ speedtest 

   Speedtest by Ookla

      Server: MegaOnda Telecom - São Gonçalo (id: 47921)
         ISP: Elevalink Telecomunicacoes LTDA - ME
Idle Latency:     6.95 ms   (jitter: 0.26ms, low: 6.70ms, high: 7.17ms)
    Download:   365.28 Mbps (data used: 267.2 MB)                                                   
                 23.97 ms   (jitter: 1.29ms, low: 7.42ms, high: 39.92ms)
      Upload:   351.78 Mbps (data used: 565.7 MB)                                                   
                 14.87 ms   (jitter: 2.43ms, low: 6.04ms, high: 230.09ms)
 Packet Loss:     0.0%
  Result URL: https://www.speedtest.net/result/c/f70ee69b-b848-4f7f-af34-8c5aa171d4c2
```

## Etapas (atualizadas)

### 1. Instalação do Speedtest CLI (Ookla)

- Remover dependência do pacote `speedtest-cli` do repositorio Debian.

```bash
sudo apt remove -y speedtest-cli
```

- Realizar download e instalação do binário oficial da Ookla.

    * URL do [Speedtest CLI](https://www.speedtest.net/apps/cli)
    8 No momento da escrita deste README, a versão mais recente é a [ookla-speedtest-1.2.0-linux-x86_64](https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz)

```bash
wget https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz
```

- Descompacte o arquivo `.tgz` baixado.

    * Este binário garante compatibilidade com sistemas Debian/Ubuntu modernos.

```bash
tar -xvzf ookla-speedtest-1.2.0-linux-x86_64.tgz
```

- Mover para /usr/local/bin/ e dar permissão de execução.

```bash
sudo mv speedtest /usr/local/bin/
```

```bash
sudo install -m 0755 speedtest /usr/local/bin/speedtest
```

### 2. Configuração do Banco de Dados MariaDB (MySQL)

Requisitos para o script funcionar corretamente:

- MySQL/MariaDB instalado e em execução

    * Caso não tenha o MariaDB instalado, utilize o comando abaixo ou o script de instalação ```mariadb_install.sh``` disponível no repositório principal do projeto.

```bash
sudo apt install -y mariadb-server mariadb-client
```

- Com isso, o script realiza as seguintes ações:

    * Define variáveis de conexão com o MariaDB (MySQL).
    * Cria o banco de dados `speedtest_grafana`.
    * Cria tabelas separadas para:

        * Resultados bem-sucedidos (`speedtest_results`)
        * Erros de execução (`speedtest_errors`)

### 3. Execução do teste e coleta de dados

O scriopt `ookla-speedtest.sh` implementa:

- Execução controlada do comando `speedtest`.
- Captura de stdout e stderr em arquivos de log distintos.
- Extração robusta de métricas utilizando `awk` e `sed`, evitando dependência de strings frágeis.
- Registro detalhado no banco de dados, incluindo:

    * ISP
    * Servidor
    * Latência idle
    * Jitter de download e upload
    * Velocidades de download e upload
    * Packet loss
    * URL do resultado

### 4. Tratamento de erros

Com o resultado da tabela `speedtest_errors`, o script oferece via dashboard Grafana:

- Detecção explícita de falhas de resolução DNS, socket e configuração.
- Registro de erros mesmo quando não há mudança de estado (visibilidade operacional).
- Evita travamentos do script em casos de falha parcial do Speedtest.

![Image](https://github.com/glaubergf/shell-script-mon-speedtest/blob/main/images/speedtest_ookla_grafana7.png)

### 5. CronJob

Um **[CronJob](https://sempreupdate.com.br/linux/tutoriais/o-que-e-um-cronjob-e-como-funciona/)** permite a execução automática do script em intervalos definidos.

- Exemplo para executar a cada 5 minutos:

```bash
*/5 * * * * /bin/bash /path/do/seu/projeto/ookla-speedtest.sh
```

- Reiniciar o crontab:

```bash
sudo service cron restart
```

## Observações importantes

- O Speedtest CLI oficial reduz drasticamente erros intermitentes observados na versão do repositório do Debian.
- Métricas de jitter e latência agora são coletadas de forma confiável.
- O script foi projetado para uso contínuo em ambientes de monitoramento (24x7).
- Recomenda-se execução em ambiente dedicado ou VM para evitar interferência de carga local.

## Licença

**GNU General Public License v3.0**

Este programa é um software livre: você pode redistribuí-lo e/ou modificá-lo sob os termos da GNU GPL conforme publicada pela Free Software Foundation, seja a versão 3 da Licença, ou qualquer versão posterior.

Este programa é distribuído na esperança de que seja útil, mas SEM QUALQUER GARANTIA; sem mesmo a garantia implícita de COMERCIALIZAÇÃO ou ADEQUAÇÃO A UM DETERMINADO FIM.

Consulte: [https://www.gnu.org/licenses/gpl-3.0.html](https://www.gnu.org/licenses/gpl-3.0.html)

---

Copyright (c) 2024 Glauber GF (mcnd2)