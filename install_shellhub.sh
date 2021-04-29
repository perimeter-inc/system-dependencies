#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]
  then echo "Please run with sudo"
  exit
fi

export SHELLHUB_EXECUTABLE_PATH=/usr/bin/shellhub_agent
export SHELLHUB_KEYS_FOLDER=/root/keys
export PREFERRED_HOSTNAME="$(hostname)"

export SHELLHUB_SERVER_ADDRESS="http://ec2-54-183-118-145.us-west-1.compute.amazonaws.com/"
export SHELLHUB_TENANT_ID="01dda772-8bdf-49ae-8a86-d75307489613"

function install_shellhub_service() {
   cp -f ./shellhub_agent "${SHELLHUB_EXECUTABLE_PATH}"
   rm -rf shellhub && git clone -b v0.6.0 https://github.com/shellhub-io/shellhub.git shellhub
   cd shellhub
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
   chmod +x "${SHELLHUB_EXECUTABLE_PATH}"
}

install_shellhub_service
start_shellhub_service
