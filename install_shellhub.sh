#!/bin/bash
set -e

SHELLHUB_PATH = /usr/bin/shellhub_agent

function get_shellhub_based_on_user_input() {
   while true; do
      read -p "Do you want to build shellhub from sources (y/n)?. If \"n\" is answered, a pre-built version will be downloaded (might not be the lattest version)." yn
      case $yn in
         [Yy]* ) build_shellhub_from_sources;;
         [Nn]* ) download_prebuilt_shellhub;;
         * ) echo "Please answer y/n (yes/no).";;
      esac
   done
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
   go build -ldflags "-X main.AgentVersion=v0.5.1"

   cp -f ./agent ${SHELLHUB_PATH}
}

function install_go_compiler() {
   wget https://golang.org/dl/go1.16.1.linux-armv6l.tar.gz
   rm -rf /usr/local/go && tar -C /usr/local -xzf go1.16.1.linux-armv6l.tar.gz
   export PATH=$PATH:/usr/local/go/bin
}

function install_shellhub_service() {
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
   sudo systemctl daemon-reload
   sudo systemctl enable shellhub_agent
   sudo systemctl restart shellhub_agent
}

get_shellhub_based_on_user_input
install_shellhub_service
setup_shellhub_service
