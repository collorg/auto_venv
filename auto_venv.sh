# Script auto_venv.sh to be activated in .bashrc (source <path>/auto_venv.sh)

if [[ -z $AUTO_VENV_PYTHON_SEARCH_PATH ]] ; then
  export AUTO_VENV_PYTHON_SEARCH_PATH="/usr/bin"
fi

__find_auto_venv_file() {
  # Function to find the .auto_venv conf file from the current directory up to the root.
  # Triggers __auto_venv_deactivate if no .auto_venv is found.

  local current_dir="$PWD"
  while [ "$current_dir" != "/" ]; do
    local file_path="$current_dir/.auto_venv"
    if [ -f "$file_path" ]; then
      AUTO_VENV_BASE_DIR=$current_dir
      AUTO_VENV_PATH=$(cat "$file_path")
      if [[ "$AUTO_VENV_PATH" != /* ]] ; then
        AUTO_VENV="$AUTO_VENV_BASE_DIR/$AUTO_VENV_PATH"
      else
        AUTO_VENV="$AUTO_VENV_PATH"
      fi
      return
    fi
    current_dir=$(dirname "$current_dir")
  done
  __auto_venv_deactivate
}

function __auto_venv_show() {
  if [[ -n "$AUTO_VENV" ]] ; then
    echo -n "[auto_venv] $AUTO_VENV"
    if [[ -n "$VIRTUAL_ENV" ]] ; then
      echo " activated ($(python --version 2>& 1))"
    else
      echo " deactivated"
    fi
  fi
}

function __auto_venv_activate() {
  if [ -n "$AUTO_VENV" ] ; then
    source "$AUTO_VENV/bin/activate"
    if [[ "$OLD_AUTO_VENV_BASE_DIR" != "$AUTO_VENV_BASE_DIR" || -z "$OLD_AUTO_VENV_BASE_DIR" ]] ; then
      __auto_venv_show
    fi
  fi
}

function __auto_venv_deactivate() {
  unset AUTO_VENV
  unset AUTO_VENV_BASE_DIR
  unset OLD_AUTO_VENV_BASE_DIR
}

function cd() {
  builtin cd "$@" || exit
  OLD_AUTO_VENV_BASE_DIR=$AUTO_VENV_BASE_DIR
  unset AUTO_VENV
  __find_auto_venv_file
  if [[ -z "$VIRTUAL_ENV" ]] ; then
    __auto_venv_activate
  else
    if [[ -n "$OLD_AUTO_VENV_BASE_DIR"* && -z "$AUTO_VENV_BASE_DIR" ]] ; then
      deactivate
    fi
    if [[ "$AUTO_VENV_BASE_DIR" != "$OLD_AUTO_VENV_BASE_DIR" && -n "$AUTO_VENV" ]] ; then
      __auto_venv_activate
    fi
  fi
}

function auto_venv() {
  if [[ "$1" == "--new" ]] ; then
    echo "Versions Python disponibles :"
    ls "$AUTO_VENV_PYTHON_SEARCH_PATH" | grep -E '^python[23]\.?[0-9]*$'
    VENV_MODULE="venv"
    read -p "Python version to use? " PYTHON_VERSION
    ls "$AUTO_VENV_PYTHON_SEARCH_PATH/$PYTHON_VERSION" | grep -E '^python[23]\.?[0-9]*$'
    if [[ $PYTHON_VERSION == "python"* ]] ; then
      if [[ $? != 0 ]] ; then
        echo "Please choose a Python version among those proposed."
        exit 1
      fi
    fi
    if [[ "$PYTHON_VERSION" == "python2.7" ]] ; then
      VENV_MODULE="virtualenv"
    fi
    read -p "Virtual environment path [.]: " VENV_PATH
    if [ -z "$VENV_PATH" ] ; then
      VENV_PATH='.'
    fi
    $AUTO_VENV_PYTHON_SEARCH_PATH/$PYTHON_VERSION -m $VENV_MODULE "$VENV_PATH"
    echo "$VENV_PATH" > "$PWD/.auto_venv"
    __find_auto_venv_file
    __auto_venv_activate
  else
    __auto_venv_show
    if [ -z "$AUTO_VENV" ]; then
      echo "No auto_venv found."
    fi
    if [[ "$AUTO_VENV_BASE_DIR" != "$PWD" ]]; then
      echo "Use 'auto_venv --new' to create a new auto_venv in $PWD."
    fi
  fi
}
