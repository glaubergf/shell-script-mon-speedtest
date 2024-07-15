---
Projeto: shell-script-mon-speedtest
Descrição: Este script Bash automatiza o teste de velocidade da conexão à internet usando o speedtest-cli
           da Ookla. Ele instala o speedtest-cli do repositório do Debian para obter resultados dos testes.
           Além disso, cria um banco de dados MariaDB (MySQL) para armazenar resultados bem-sucedidos e erros dos testes extraindo os dados com o comando sed.
           Este script automatiza o teste de velocidade e a gestão de dados resultantes em um ambiente MariaDB (MySQL), adequado para monitoramento contínuo de conexões de internet.
Autor: Glauber GF (@mcnd2)
Data: 15/07/2024
---

# Script de Monitoramento de Teste de Velocidade com Speedtest

![Image](https://github.com/glaubergf/shell-script-mon-speedtest/blob/main/images/speedtest_results.png)
![Image](https://github.com/glaubergf/shell-script-mon-speedtest/blob/main/images/speedtest_grafana1.png)
![Image](https://github.com/glaubergf/shell-script-mon-speedtest/blob/main/images/speedtest_grafana2.png)

A Ookla **[Speedtest](https://www.speedtest.net/pt)** é uma maneira de testar o desempenho e 
a qualidade de uma conexão de internet. O Speedtest CLI traz a tecnologia confiável e a rede de servidores 
globais do Speedtest para a linha de comando. Voltado a desenvolvedores de software, administradores de sistema
e aficionados por computação, o Speedtest CLI é o primeiro aplicativo Speedtest nativo para Linux oferecido 
pela Ookla. 

Este projeto utiliza o comando **[sed](https://www.gnu.org/software/sed/manual/sed.html)** que é uma ferramenta poderosa de linha de comando em sistemas Unix e Linux, utilizada para manipulação de texto. O nome "sed" vem de "stream editor", ou seja, é um editor de fluxo de texto que processa texto linha por linha e permite fazer substituições, inserções, exclusões e outras operações de transformação de texto de forma automatizada. Com o comando sed vamos extrair os dados do log gerado pela execução do speedtest-cli, assim, salvando os dados em tabelas no banco de dados para posterior monitoramento no grafana.

## Etapas do script

* **Instalação do speedtest-cli**
   - Verifica e instala o pacote _speedtest-cli_ se não estiver presente no sistema Debian.

* **Configuração do Banco de Dados**
   - Define variáveis de conexão e cria um novo usuário com privilégios no MariaDB (MySQL).
   - Cria o banco de dados _speedtest_grafana_ e suas tabelas _speedtest_results_ e _speedtest_errors_.

* **Execução do Speedtest e Registro de Dados**
   - Executa o comando _speedtest-cli_ de forma segura, salvando resultados e erros em arquivos de log.
   - Registra os resultados no banco de dados, incluindo informações como provedor, IP, servidor, cidade,
   distância, ping, velocidades de download e upload, e URL do resultado.

Lembre-se de já ter o MariaDB (MySQL) instalado e configurado o usuário root para a execução do script.

## speedtest-cli (_Debian_) X speedtest (_Ookla_)

Abaixo segue informações das diferenças nas informações fornecidas pelo **speedtest-cli** (repositório Debian) e 
pelo **speedtest** (repositório Ookla).

* **speedtest-cli (Debian)**
    - Informações Fornecidas -> O ***speedtest-cli*** geralmente fornece informações básicas como velocidade de
    download, velocidade de upload, latência (ping) e o servidor utilizado para o teste.
    
    - Informações Adicionais -> Em alguns casos, pode mostrar o IP do provedor de internet que está sendo usado 
    para realizar o teste, assim como a distância aproximada até o servidor de teste. Essas informações podem
    ser úteis para entender a geolocalização do teste e qual infraestrutura está sendo utilizada pela 
    sua conexão.

            :~$ speedtest-cli --share
            Retrieving speedtest.net configuration...
            Testing from Elevalink Telecomunicacoes LTDA - ME (xx.xxx.xxx.xxx)...
            Retrieving speedtest.net server list...
            Selecting best server based on ping...
            Hosted by PLANETY INTERNET (São Pedro da Aldeia) [93.11 km]: 10.212 ms
            Testing download speed................................................................................
            Download: 87.34 Mbit/s
            Testing upload speed......................................................................................................
            Upload: 94.27 Mbit/s
            Share results: http://www.speedtest.net/result/0123456789.png
            :~$ 

* **speedtest (Ookla)**
    - Informações Fornecidas -> O ***speedtest*** da Ookla oferece uma interface mais detalhada que inclui velocidade 
    de download, velocidade de upload, latência (ping), perda de pacotes e, às vezes, a localização
    aproximada do servidor de teste.

    - Diferenças -> Não é comum que o speedtest da Ookla forneça diretamente o IP do provedor ou a distância até 
    o servidor de teste. Ele se concentra mais na qualidade da conexão medida através de métricas como
    latência e perda de pacotes, além das velocidades de download e upload.

            :~$ speedtest

               Speedtest by Ookla

                  Server: Westlink Tecnologia - São Gonçalo (id: 46733)
                     ISP: Elevalink Telecomunicacoes LTDA - ME
            Idle Latency:     1.99 ms   (jitter: 0.11ms, low: 1.88ms, high: 2.12ms)
                Download:    92.05 Mbps (data used: 46.4 MB)                                                   
                            145.20 ms   (jitter: 43.36ms, low: 1.79ms, high: 252.41ms)
                  Upload:    91.97 Mbps (data used: 71.0 MB)                                                   
                              5.43 ms   (jitter: 2.91ms, low: 2.25ms, high: 151.59ms)
             Packet Loss:     0.0%
              Result URL: https://www.speedtest.net/result/c/b39ca341-0f55-4328-99bb-134e8dfe3126
            :~$ 

* **Pontos chave**

    - Informações de localização e provedor -> O ***speedtest-cli*** pode oferecer detalhes mais específicos 
    sobre o local de realização do teste e o provedor de internet utilizado, o que pode ser útil para 
    diagnósticos mais localizados.

    - Métricas de qualidade da conexão -> O ***speedtest*** da Ookla é reconhecido por suas métricas de qualidade
     de conexão, como latência e perda de pacotes, que são fundamentais para entender a estabilidade e 
     confiabilidade da sua internet.

Portanto, a escolha entre o **speedtest-cli** do Debian e o **speedtest** da Ookla depende das suas necessidades específicas de informação. Se você precisa de detalhes como o IP do provedor ou a distância até o servidor de 
teste, o speedtest-cli pode ser mais adequado. Se você está mais interessado na qualidade geral da conexão, 
incluindo latência e perda de pacotes, o speedtest da Ookla pode ser a melhor opção.

****

#### OBSERVAÇÃO

Quando a saída padrão do teste não encontra o "Hosted" ele fica congelado e gera "ERRO" na saida de 
erro (stderr). Isso ocorre a cada 30 minutos, sempre no minuto 00 e 30. Não consegui identificar o 
porque do erro, no entanto, acho que pode ser uma restrição do próprio servidor do speedtest para alta 
demanda de requisições nesse período, mas que ainda não está confirmado.

A saída padrão pausada sem encontrar o "Hosted":

    Retrieving speedtest.net configuration...
    Testing from Elevalink Telecomunicacoes LTDA - ME (xx.xxx.xxx.xxx)...
    Retrieving speedtest.net server list...
    Selecting best server based on ping...

Saída de erro (stderr):

    ERROR: Unable to connect to servers to test latency.

ou

    Cannot retrieve speedtest configuration
    ERROR: HTTP Error 403: Forbidden

## CronJob

Um **[CronJob](https://sempreupdate.com.br/linux/tutoriais/o-que-e-um-cronjob-e-como-funciona/)** é uma funcionalidade amplamente utilizada em sistemas operacionais Unix-like, como o Linux, que permite agendar a execução automática de tarefas em determinados intervalos de tempo. Ele é particularmente útil para realizar tarefas repetitivas, agendadas e automáticas, sem a necessidade de uma intervenção humana direta.

Com isso, configure o script para ser executado no seu cronjob em um intervalo de tempo
de acordo com sua necessidade para coleta de dados do teste.

Para configurar o cronjob, execute o comando abaixo com privilégio de root:

`sudo crontab -l -u root`

Em seguida, adicione no final do arquivo a linha configurada para ser executado a cada 5 minutos.

`*/5 * * * * /bin/bash /path/do/seu/projeto/speedtest.sh`

Salve e feche a cron. Com isso execute o restart da cron para habilitar a mudança feita.

`sudo service cron restart`

## Licença

**GNU General Public License** (_Licença Pública Geral GNU_), **GNU GPL** ou simplesmente **GPL**.

[GPLv3](https://www.gnu.org/licenses/gpl-3.0.html)

------

Copyright (c) 2024 Glauber GF (mcnd2)

Este programa é um software livre: você pode redistribuí-lo e/ou modificar
sob os termos da GNU General Public License conforme publicada por
a Free Software Foundation, seja a versão 3 da Licença, ou
(à sua escolha) qualquer versão posterior.

Este programa é distribuído na esperança de ser útil,
mas SEM QUALQUER GARANTIA; sem mesmo a garantia implícita de
COMERCIALIZAÇÃO ou ADEQUAÇÃO A UM DETERMINADO FIM. Veja o
GNU General Public License para mais detalhes.

Você deve ter recebido uma cópia da Licença Pública Geral GNU
junto com este programa. Caso contrário, consulte <https://www.gnu.org/licenses/>.

*

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see <https://www.gnu.org/licenses/>
