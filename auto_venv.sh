# Script auto_venv.sh à activer dans .bashrc.
# Activation automatique d'un environnement virtuel.
# Rajouter dans le répertoire un fichier .auto_venv contenant
# la variable AUTO_VENV.
# Exemple pour un répertoire dont l'environnement virtuel a été créé
# avec `python -m venv .` : AUTO_VENV=$PWD
# avec `python -m venv .env` : AUTO_VENV=$PWD/.env

if [[ -z $AUTO_VENV_PYTHON_SEARCH_PATH ]] ; then
  echo "[auto_venv] Veuillez spécifier le chemin de recherche des versions
de python avec la variable AUTO_VENV_PYTHON_SEARCH_PATH."
fi

function autoactivate_venv() {
  if [[ -f "$PWD/.auto_venv" ]] ; then
    . "$PWD/.auto_venv"
  else
    unset AUTO_VENV
  fi
  if [[ -f "$AUTO_VENV/bin/activate" ]] ; then
    source $AUTO_VENV/bin/activate
    echo "[auto_venv] venv trouvé et activé : $AUTO_VENV"
    python --version
  fi
}

function cd() {
  builtin cd "$@"

  if [[ -z "$VIRTUAL_ENV" ]] ; then
    autoactivate_venv
  else
    if [[ "$PWD" != "$VIRTUAL_ENV"/* ]] ; then
      deactivate
      autoactivate_venv
    fi
  fi
}

function auto_venv() {
  echo "Versions Python disponibles :"
  ls $AUTO_VENV_PYTHON_SEARCH_PATH
  VENV_MODULE="venv"
  read -p "Version à utiliser pour l'environnement virtuel ? " PYTHON_VERSION
  if [[ $PYTHON_VERSION == "python2.7" ]] ; then
    VENV_MODULE="virtualenv"
  fi
  read -p "Chemin de l'environnement virtuel : " VENV_PATH
  $AUTO_VENV_PYTHON_SEARCH_PATH/$PYTHON_VERSION -m $VENV_MODULE $VENV_PATH
  if [[ $VENV_PATH != /* ]] ; then
    echo "AUTO_VENV=\$PWD/$VENV_PATH" > $PWD/.auto_venv
  else
    echo "AUTO_VENV=$VENV_PATH" > $PWD/.auto_venv
  fi
  autoactivate_venv
}
