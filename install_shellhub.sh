#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]
  then echo "Please run with sudo"
  exit
fi

export SHELLHUB_PATH=/usr/bin/shellhub_agent

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

   cp -f ./agent ${SHELLHUB_PATH}
}

function install_go_compiler() {
   echo "Installing Go compiler..."
   if (( $(uname -m) == "aarch64" )); then
      wget https://golang.org/dl/go1.16.2.linux-arm64.tar.gz
      export GO_COMPILER_FILE=go1.16.2.linux-arm64.tar.gz
   elif (( $(uname -m) == "armv7l" )); then
      wget https://golang.org/dl/go1.16.1.linux-armv6l.tar.gz
      export GO_COMPILER_FILE=go1.16.1.linux-armv6l.tar.gz
   else
      echo "Architecture not supported: $(uname -m)"
      exit -1
   fi

   wget https://golang.org/dl/go1.16.1.linux-armv6l.tar.gz
   rm -rf /usr/local/go && tar -C /usr/local -xzf ${GO_COMPILER_FILE}
   export PATH=$PATH:/usr/local/go/bin
}

function install_shellhub_service() {
   echo "Installing shellhub service."
   cat << EOF > /etc/systemd/system/shellhub_agent.service
[Unit]
Description=Shellhub Agent

[Service]
Environment = SHELLHUB_SERVER_ADDRESS=http://ec2-3-142-187-112.us-east-2.compute.amazonaws.com
Environment = SHELLHUB_TENANT_ID=a61f31b9-936c-4b18-8b1f-d76d8b1cd144
Environment = SHELLHUB_PRIVATE_KEY=~/.ssh/id_rsa

Restart=always
RestartSec=5
ExecStart=${SHELLHUB_PATH}
SyslogIdentifier = shellhub_agent

[Install]
WantedBy=multi-user.target

EOF
}

function setup_shellhub_service() {
   echo "Setting up shellhub service."
   sudo systemctl daemon-reload
   sudo systemctl enable shellhub_agent
   sudo systemctl restart shellhub_agent
}

get_shellhub_based_on_user_input
install_shellhub_service
setup_shellhub_service
