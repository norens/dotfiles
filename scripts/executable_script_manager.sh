#!/bin/bash

# Path to your aliases and scripts directory
ALIAS_FILE="$HOME/.zshrc"  # Тепер використовуємо ~/.zshrc для alias
SCRIPTS_DIR="$HOME/scripts" # Директорія для скриптів

# Ensure the scripts directory exists
if [ ! -d "$SCRIPTS_DIR" ]; then
  mkdir -p "$SCRIPTS_DIR"
fi

# Show usage information
function show_usage {
  echo "Usage:"
  echo "  la    - List all aliases"
  echo "  aa <alias_name> <command> - Add alias"
  echo "  ea <alias_name> - Edit alias"
  echo "  ra <alias_name> - Remove alias"
  echo "  ls    - List all scripts"
  echo "  as <script_name> - Add script"
  echo "  es <script_name> - Edit script"
  echo "  rs <script_name> - Remove script"
  echo "  help  - Show this help message"
}

# List all aliases
function la {
  echo "Current aliases:"
  if [ -f "$ALIAS_FILE" ]; then
    grep -E "^alias " "$ALIAS_FILE"
  else
    echo "No aliases found."
  fi
}

# Add alias
function aa {
  if [ $# -lt 2 ]; then
    echo "❌ Error: Provide alias name and command."
    show_usage
    exit 1
  fi
  echo "alias $1='$2'" >> "$ALIAS_FILE"
  echo "✅ Alias '$1' added."
}

# Edit alias
function ea {
  if [ -z "$1" ]; then
    echo "❌ Error: Provide alias name to edit."
    show_usage
    exit 1
  fi
  ALIAS_NAME=$1
  ALIAS_LINE=$(grep -E "^alias $ALIAS_NAME=" "$ALIAS_FILE")
  if [ -z "$ALIAS_LINE" ]; then
    echo "❌ Error: Alias '$ALIAS_NAME' not found."
    exit 1
  fi
  sed -i "/^alias $ALIAS_NAME=/d" "$ALIAS_FILE"
  nano "$ALIAS_FILE"
}

# Remove alias
function ra {
  if [ -z "$1" ]; then
    echo "❌ Error: Provide alias name to remove."
    show_usage
    exit 1
  fi
  sed -i "/^alias $1=/d" "$ALIAS_FILE"
  echo "✅ Alias '$1' removed."
}

# List all scripts
function ls {
  echo "Scripts in $SCRIPTS_DIR:"
  if [ -z "$(ls -A $SCRIPTS_DIR)" ]; then
    echo "No scripts found."
  else
    ls "$SCRIPTS_DIR"
  fi
}

# Add script
function as {
  if [ -z "$1" ]; then
    echo "❌ Error: Provide script name."
    show_usage
    exit 1
  fi
  SCRIPT_PATH="$SCRIPTS_DIR/$1"
  if [ -f "$SCRIPT_PATH" ]; then
    echo "❌ Error: Script '$1' already exists."
    exit 1
  fi
  touch "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
  nano "$SCRIPT_PATH"
  echo "✅ Script '$1' added."
}

# Edit script
function es {
  if [ -z "$1" ]; then
    echo "❌ Error: Provide script name to edit."
    show_usage
    exit 1
  fi
  SCRIPT_PATH="$SCRIPTS_DIR/$1"
  if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ Error: Script '$1' not found."
    exit 1
  fi
  nano "$SCRIPT_PATH"
}

# Remove script
function rs {
  if [ -z "$1" ]; then
    echo "❌ Error: Provide script name to remove."
    show_usage
    exit 1
  fi
  SCRIPT_PATH="$SCRIPTS_DIR/$1"
  if [ ! -f "$SCRIPT_PATH" ]; then
    echo "❌ Error: Script '$1' not found."
    exit 1
  fi
  rm "$SCRIPT_PATH"
  echo "✅ Script '$1' removed."
}

# Autocompletion for commands
function _script_manager_completions {
  local cur
  cur="${COMP_WORDS[COMP_CWORD]}"
  case "$COMP_CWORD" in
    1)
      # Autocomplete command names
      COMPREPLY=($(compgen -W "la aa ea ra ls as es rs help" -- "$cur"))
      ;;
    2)
      # Autocomplete script names
      if [[ "${COMP_WORDS[1]}" == "as" || "${COMP_WORDS[1]}" == "es" || "${COMP_WORDS[1]}" == "rs" ]]; then
        COMPREPLY=($(compgen -W "$(ls $SCRIPTS_DIR)" -- "$cur"))
      fi
      ;;
    3)
      # Autocomplete alias names for adding or editing
      if [[ "${COMP_WORDS[1]}" == "aa" || "${COMP_WORDS[1]}" == "ea" || "${COMP_WORDS[1]}" == "ra" ]]; then
        COMPREPLY=($(compgen -W "$(grep -oP '^alias \K\w+' $ALIAS_FILE)" -- "$cur"))
      fi
      ;;
  esac
}

# Enable autocompletion
complete -F _script_manager_completions script_manager

# Main function to handle commands
case $1 in
  la)
    la
    ;;
  aa)
    aa $2 $3
    ;;
  ea)
    ea $2
    ;;
  ra)
    ra $2
    ;;
  ls)
    ls
    ;;
  as)
    as $2
    ;;
  es)
    es $2
    ;;
  rs)
    rs $2
    ;;
  help)
    show_usage
    ;;
  *)
    echo "❌ Error: Unknown command."
    show_usage
    ;;
esac
