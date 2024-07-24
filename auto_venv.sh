# Script auto_venv.sh à activer dans .bashrc.
# Activation automatique d'un environnement virtuel.
# Rajouter dans le répertoire un fichier .auto_venv contenant
# la variable AUTO_VENV.
# Exemple pour un répertoire dont l'environnement virtuel a été créé
# avec `python -m venv .` : AUTO_VENV=$PWD
# avec `python -m venv .env` : AUTO_VENV=$PWD/.env

if [[ -d /opt/python/bin ]] ; then
  export AUTO_VENV_PYTHON_SEARCH_PATH="/opt/python/bin"
fi
if [[ -z $AUTO_VENV_PYTHON_SEARCH_PATH ]] ; then
  echo "[auto_venv] Veuillez spécifier le chemin de recherche des versions
de python avec la variable AUTO_VENV_PYTHON_SEARCH_PATH."
fi

__find_auto_venv_file() {
  local current_dir="$PWD"
  while [ "$current_dir" != "/" ]; do
    local file_path="$current_dir/.auto_venv"
    if [ -f "$file_path" ]; then
      . "$file_path"
    fi
    current_dir=$(dirname "$current_dir")
  done
}

function __auto_venv_show() {
  if [[ ! -z "$AUTO_VENV" ]] ; then
    echo -n "[auto_venv] $AUTO_VENV"
    if [[ ! -z "$VIRTUAL_ENV" ]] ; then
      echo " activé (`python --version 2>& 1`)"
    else
      echo " désactivé"
    fi
  fi
}

function __auto_venv_activate() {
  source "$AUTO_VENV/bin/activate"
  __auto_venv_show
}

function cd() {
  builtin cd "$@"
  unset AUTO_VENV
  __find_auto_venv_file
  if [[ -z "$VIRTUAL_ENV" ]] ; then
    __auto_venv_activate
  else
    if [[ "$PWD" != `dirname "$VIRTUAL_ENV"`* ]] ; then
      deactivate
    fi
    if [[ "$VIRTUAL_ENV" != "$AUTO_VENV" && ! -z "$AUTO_VENV" ]] ; then
      __auto_venv_activate
    fi
  fi
}

function auto_venv() {
  if [[ -z "$AUTO_VENV" ]] ; then
    echo "Versions Python disponibles :"
    ls "$AUTO_VENV_PYTHON_SEARCH_PATH"
    VENV_MODULE="venv"
    read -p "Version à utiliser pour l'environnement virtuel ? " PYTHON_VERSION
    if [[ "$PYTHON_VERSION" == "python2.7" ]] ; then
      VENV_MODULE="virtualenv"
    fi
    read -p "Chemin de l'environnement virtuel : " VENV_PATH
    $AUTO_VENV_PYTHON_SEARCH_PATH/$PYTHON_VERSION -m $VENV_MODULE "$VENV_PATH"
    if [[ "$VENV_PATH" != /* ]] ; then
      AUTO_VENV="$PWD/$VENV_PATH"
    else
      AUTO_VENV="$VENV_PATH"
    fi
    echo "AUTO_VENV=\"$AUTO_VENV\"" > "$PWD/.auto_venv"
    __auto_venv_activate
  else
    __auto_venv_show
  fi
}
