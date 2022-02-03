#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]
  then echo "Please run with sudo"
  exit
fi

export SHELLHUB_EXECUTABLE_PATH=/usr/bin/shellhub_agent
export SHELLHUB_KEYS_FOLDER=/data/shellhub_keys
export PREFERRED_HOSTNAME="$(hostname)"

function show_help {
    echo "Install shellhub."
    echo "    USAGE: $0 SERVER_ADDRESS TENANT_ID"
}

function parse_command_line {
    if [ $# -lt 2 ]; then
        show_help
        exit 1
    fi
    export SHELLHUB_SERVER_ADDRESS="$1"
    export SHELLHUB_TENANT_ID="$2"
}

function get_shellhub_based_on_user_input() {
   [ ! -d ${HOME}/shellhub ] && git clone -b v0.6.0 https://github.com/shellhub-io/shellhub.git ~/shellhub

   echo -e "Do you want to build shellhub from sources (y/N)?.\nIf \"n\" is answered, a pre-built version will be used (might not be the lattest version)."
   read  -n1 -p "[y,N]" yn
   case $yn in
      y|Y) install_shellhub_from_sources ;;
      *) install_prebuilt_shellhub ;;
   esac
}

function install_prebuilt_shellhub() {
   ARCH="$(uname -m)"
   MY_PATH="`dirname \"$0\"`"

   if [ "$ARCH" == "aarch64" ]; then
      export SHELLHUB_FILE=${MY_PATH}/shellhub_agent_aarch64
   elif [ "$ARCH" == "armv7l" ]; then
      export SHELLHUB_FILE=${MY_PATH}/shellhub_agent_armv7
   else
      echo "Architecture not supported: $(uname -m)"
      exit -1
   fi

   cp -f "${SHELLHUB_FILE}" "${SHELLHUB_EXECUTABLE_PATH}"
}

function install_shellhub_from_sources() {
   install_go_compiler

   cd ~/shellhub/agent
   echo "Building shellhub..."
   go build -ldflags "-X main.AgentVersion=v0.6.0"

   cp -f ./agent "${SHELLHUB_EXECUTABLE_PATH}"
   cd -
}

function install_go_compiler() {
   echo "Installing Go compiler..."
   ARCH="$(uname -m)"
   if [ "$ARCH" == "aarch64" ]; then
      export GO_COMPILER_FILE=go1.14.15.linux-arm64.tar.gz
   elif [ "$ARCH" == "armv7l" ]; then
      export GO_COMPILER_FILE=go1.14.15.linux-armv6l.tar.gz
   else
      echo "Architecture not supported: $(uname -m)"
      exit -1
   fi

   rm -rf "${GO_COMPILER_FILE}" && wget "https://golang.org/dl/${GO_COMPILER_FILE}"
   rm -rf ~/go/
   tar -C ~ -xzf "${GO_COMPILER_FILE}"
   export PATH=$PATH:~/go/bin
}

function install_shellhub_service() {
   cd ~/shellhub
   make keygen
   # By now, three files should have been created ssh_private_key, api_public_key and api_private_key.
   mkdir -p "${SHELLHUB_KEYS_FOLDER}"
   mv ssh_private_key "${SHELLHUB_KEYS_FOLDER}"
   mv api_public_key "${SHELLHUB_KEYS_FOLDER}"
   mv api_private_key "${SHELLHUB_KEYS_FOLDER}"

   chmod +x "${SHELLHUB_EXECUTABLE_PATH}"
   echo "Installing shellhub service."
   cat << EOF > /etc/systemd/system/shellhub_agent.service
[Unit]
Description=Shellhub Agent

[Service]
Environment = SHELLHUB_SERVER_ADDRESS="${SHELLHUB_SERVER_ADDRESS}"
Environment = SHELLHUB_TENANT_ID="${SHELLHUB_TENANT_ID}"
Environment = SHELLHUB_PRIVATE_KEY="${SHELLHUB_KEYS_FOLDER}/ssh_private_key"
Environment = PREFERRED_HOSTNAME="${PREFERRED_HOSTNAME}"

Restart=always
RestartSec=5
ExecStart="${SHELLHUB_EXECUTABLE_PATH}"
SyslogIdentifier = shellhub_agent

[Install]
WantedBy=multi-user.target

EOF
   cd -
}

function start_shellhub_service() {
   echo "Setting up shellhub service."
   chmod +x "${SHELLHUB_EXECUTABLE_PATH}"
   systemctl daemon-reload || true
   systemctl enable shellhub_agent || true
   systemctl restart shellhub_agent || true
}

parse_command_line $@
get_shellhub_based_on_user_input
install_shellhub_service
start_shellhub_service
