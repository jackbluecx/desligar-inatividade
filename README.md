📄 Configuração e Inicialização do Projeto (Atualizado)
Este projeto utiliza Python e a instalação agora garante que os arquivos de código sejam movidos para a pasta Home do usuário para um acesso mais padronizado antes da configuração de inicialização.

🚀 Inicialização Automática e Configuração
Para instalar as dependências e configurar o sistema de inicialização, utilize o script de automação instalar.sh.

Torne o Script Executável:

Garanta que o script de automação, que deve estar no mesmo diretório dos arquivos de código, tenha permissão de execução:

Bash

chmod +x instalar.sh
Execute a Instalação:

Execute o script instalar.sh. Ele moverá os arquivos auto_off.sh e gui_simple.py para a sua pasta Home ~/ e fará a instalação e configuração.

Bash

./instalar.sh
O script vai solicitar permissão de superusuário sudo para instalar pacotes de sistema se necessário e fará o seguinte:

Moverá os arquivos auto_off.sh e gui_simple.py para a pasta Home do usuário ~/.

Instalará as dependências listadas no requirements.txt se ele existir.

Criará um arquivo de atalho .desktop na pasta de inicialização automática do seu usuário, garantindo que o programa execute o comando nohup python3 ~/gui_simple.py &.

O uso do comando nohup é crucial para que o script continue sendo executado em segundo plano mesmo depois de você fechar a sessão.
