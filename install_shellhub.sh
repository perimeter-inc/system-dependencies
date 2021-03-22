#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]
  then echo "Please run with sudo"
  exit
fi

export SHELLHUB_EXECUTABLE_PATH=/usr/bin/shellhub_agent
export SHELLHUB_KEYS_FOLDER=/root/keys
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
   echo -e "Do you want to build shellhub from sources (y/n)?.\nIf \"n\" is answered, a pre-built version will be downloaded (might not be the lattest version)."
   read -n1 -p "[y,n]" yn
   case $yn in
      y|Y) build_shellhub_from_sources ;;
      n|N) download_prebuilt_shellhub ;;
      *) echo "Please answer y/n (yes/no)." || exit 1;;
   esac
}

function download_prebuilt_shellhub() {
   echo "Not implemented!!!"
   echo "TODO: Infer and download based on the architecture."
   exit 1
}

function build_shellhub_from_sources() {
   install_go_compiler
   cd ~
   rm -rf shellhub && git clone -b v0.6.0 https://github.com/shellhub-io/shellhub.git shellhub
   cd shellhub/agent
   echo "Building shellhub..."
   go build -ldflags "-X main.AgentVersion=v0.6.0"

   cp -f ./agent "${SHELLHUB_EXECUTABLE_PATH}"
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
   sudo cp -f ssh_private_key "${SHELLHUB_KEYS_FOLDER}"
   sudo cp -f api_public_key "${SHELLHUB_KEYS_FOLDER}"
   sudo cp -f api_private_key "${SHELLHUB_KEYS_FOLDER}"

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
}

function start_shellhub_service() {
   echo "Setting up shellhub service."
   sudo systemctl daemon-reload
   sudo systemctl enable shellhub_agent
   sudo systemctl restart shellhub_agent
}

parse_command_line $@
get_shellhub_based_on_user_input
install_shellhub_service
start_shellhub_service
