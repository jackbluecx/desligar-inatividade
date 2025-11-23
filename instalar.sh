#!/bin/bash

# Nome do seu programa e arquivo principal
PROGRAM_NAME="gui_simple"
PYTHON_FILE="gui_simple.py"
SHELL_FILE="auto_off.sh"
ICON_FILE="meu_icone.png" # Nome do seu arquivo de ícone.

# Pasta de ícones padrão do sistema
ICON_DIR="/usr/share/icons/hicolor/scalable/apps/" # Usaremos scalable para alta resolução

# --- 0. Mover Arquivos para a Pasta Home e Instalar Ícone ---

echo "Movendo arquivos de código para a pasta Home e instalando ícone."

# Move os scripts para a pasta Home
mv "$PYTHON_FILE" "$HOME/"
mv "$SHELL_FILE" "$HOME/"
chmod +x "$HOME/$SHELL_FILE"

# Instala o ícone no diretório do sistema (requer sudo)
if [ -f "$ICON_FILE" ]; then
    sudo mkdir -p "$ICON_DIR"
    sudo cp "$ICON_FILE" "$ICON_DIR/$PROGRAM_NAME.png"
    echo "Ícone instalado em: $ICON_DIR/$PROGRAM_NAME.png"
else
    echo "Aviso: Arquivo de ícone '$ICON_FILE' não encontrado. O programa será instalado sem ícone."
fi

# Define o comando de execução final
EXEC_COMMAND="python3 $HOME/$PYTHON_FILE"

# --- 1. Instalação de Dependências ---

# ... (Restante do código de instalação de dependências é o mesmo) ...

echo "Iniciando a instalação de dependências. Será solicitado o uso de sudo."

# Tenta identificar o gerenciador de pacotes e instala o Python e pip, se necessário
if command -v apt-get &> /dev/null; then
    sudo apt-get update
    sudo apt-get install -y python3 python3-pip
elif command -v dnf &> /dev/null; then
    sudo dnf install -y python3 python3-pip
elif command -v pacman &> /dev/null; then
    sudo pacman -Sy --noconfirm python python-pip
else
    echo "Não foi possível identificar um gerenciador de pacotes suportado. Instale python3 e python3-pip manualmente."
fi

# Instala as dependências do projeto listadas no requirements.txt
if [ -f "requirements.txt" ]; then
    pip install -r requirements.txt
    echo "Dependências do projeto instaladas via requirements.txt."
else
    echo "Arquivo requirements.txt não encontrado."
fi

# --- 2. Criação do Arquivo .desktop (Com Ícone) ---

# Cria o conteúdo do arquivo .desktop
DESKTOP_CONTENT="[Desktop Entry]
Name=$PROGRAM_NAME
Comment=Script de inicialização automática do $PROGRAM_NAME
Exec=nohup $EXEC_COMMAND &
Terminal=false
Type=Application
Icon=$PROGRAM_NAME # O nome do ícone sem a extensão, pois foi instalado no sistema
X-GNOME-Autostart-enabled=true
"

# Define o nome do arquivo e o caminho
DESKTOP_FILE="$HOME/.local/share/applications/$PROGRAM_NAME.desktop"

# Escreve o conteúdo no arquivo .desktop
echo "$DESKTOP_CONTENT" > "$DESKTOP_FILE"
chmod +x "$DESKTOP_FILE"

echo "Arquivo .desktop criado em: $DESKTOP_FILE"

# --- 3. Criação do Atalho de Inicialização e Atualização de Menu ---

# Define a pasta de inicialização para o usuário atual
AUTOSTART_DIR="$HOME/.config/autostart"

# Verifica se a pasta existe e a cria se necessário
mkdir -p "$AUTOSTART_DIR"

# Cria um link simbólico do .desktop para a pasta de inicialização
LINK_TARGET="$AUTOSTART_DIR/$PROGRAM_NAME.desktop"
ln -sf "$DESKTOP_FILE" "$LINK_TARGET"

echo "Atalho de inicialização automática criado em: $LINK_TARGET"

# Força a atualização do menu para o ícone aparecer
update-desktop-database ~/.local/share/applications/
echo "Menu do sistema atualizado."
echo "Instalação e configuração de inicialização concluídas com ícone."
