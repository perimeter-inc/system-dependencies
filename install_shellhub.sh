#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]
  then echo "Please run with sudo"
  exit
fi

export SHELLHUB_EXECUTABLE_PATH=/usr/bin/shellhub_agent
export SHELLHUB_KEYS_FOLDER=/root/keys
export SHELLHUB_TENANT_ID=65e34c46-869b-459b-9833-660b8c39522c
export SHELLHUB_SERVER_ADDRESS=http://ec2-13-56-77-247.us-west-1.compute.amazonaws.com/

function get_shellhub_based_on_user_input() {
   echo -e "Do you want to build shellhub from sources (y/n)?.\nIf \"n\" is answered, a pre-built version will be downloaded (might not be the lattest version)."
   read -n1 -p "[y,n]" yn
   case $yn in
      y|Y) build_shellhub_from_sources ;;
      n|N) download_prebuilt_shellhub ;;
      *) echo "Please answer y/n (yes/no)." ;;
   esac
}

function download_prebuilt_shellhub() {
   echo "Not implemented!!!"
   echo "TODO: Infer and download based on the architecture."
   exit 1
}

function build_shellhub_from_sources() {
   install_go_compiler
   git clone -b v0.5.1 https://github.com/shellhub-io/shellhub.git shellhub
   cd shellhub/agent
   echo "Building shellhub..."
   go build -ldflags "-X main.AgentVersion=v0.5.1"

   cp -f ./agent "${SHELLHUB_EXECUTABLE_PATH}"
}

function install_go_compiler() {
   echo "Installing Go compiler..."
   ARCH="$(uname -m)"
   if [ "$ARCH" == "aarch64" ]; then
      export GO_COMPILER_FILE=go1.16.2.linux-arm64.tar.gz
   elif [ "$ARCH" == "armv7l" ]; then
      export GO_COMPILER_FILE=go1.16.1.linux-armv6l.tar.gz
   else
      echo "Architecture not supported: $(uname -m)"
      exit -1
   fi

   wget "https://golang.org/dl/${GO_COMPILER_FILE}"
   rm -rf /usr/local/go && tar -C /usr/local -xzf "${GO_COMPILER_FILE}"
   export PATH=$PATH:/usr/local/go/bin
}

function create_key_pair() {
   sh <(curl "https://raw.githubusercontent.com/shellhub-io/shellhub/v0.5.1/bin/keygen")
   # By now, three files should have been created ssh_private_key, api_public_key and api_private_key.
   mkdir -p "${SHELLHUB_KEYS_FOLDER}"
   sudo cp -f ssh_private_key "${SHELLHUB_KEYS_FOLDER}"
   sudo cp -f api_public_key "${SHELLHUB_KEYS_FOLDER}"
   sudo cp -f api_private_key "${SHELLHUB_KEYS_FOLDER}"
}

function install_shellhub_service() {
   echo "Installing shellhub service."
   cat << EOF > /etc/systemd/system/shellhub_agent.service
[Unit]
Description=Shellhub Agent

[Service]
Environment = SHELLHUB_SERVER_ADDRESS="${SHELLHUB_SERVER_ADDRESS}"
Environment = SHELLHUB_TENANT_ID="${SHELLHUB_TENANT_ID}"
Environment = SHELLHUB_PRIVATE_KEY="${SHELLHUB_KEYS_FOLDER}/ssh_private_key"

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

get_shellhub_based_on_user_input
install_shellhub_service
create_key_pair
start_shellhub_service
