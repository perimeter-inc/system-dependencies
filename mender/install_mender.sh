#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]
  then echo "Please run with sudo"
  exit
fi

export SCRIPT_PATH=$(dirname $(readlink -f $0))

function get_mender_connect()
{
   [ ! -d ${SCRIPT_PATH}/mender-connect ] && git clone -b 2.0.1 https://github.com/mendersoftware/mender-connect.git ${SCRIPT_PATH}/mender-connect
   true
}

function install_mender_lib_from_package()
{
   echo "Installing lib dependencies for mender client and mender connect."
   apt install ${SCRIPT_PATH}/libffi6_3.2.1-9_arm64.deb
}

function install_mender_client_from_package()
{
   echo "Installing mender client."
   cp -R ${SCRIPT_PATH}/mender /etc/
   cp -r ${SCRIPT_PATH}/lib/mender /var/lib/
   apt install ${SCRIPT_PATH}/mender-client_3.1.0-1_arm64.deb
}

function install_mender()
{
   install_mender_lib_from_package
   install_mender_client_from_package
   install_mender_connect_from_sources
}


function install_mender_connect_from_sources()
{
   echo "Installing mender-connect"
   install_go_compiler
#   apt-get install libglib2.0-dev

   echo "Building mender connect."
   cd ${SCRIPT_PATH}/mender-connect
   make build
   make install
}

function install_go_compiler()
{
   echo "Installing Go compiler."
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
   rm -rf ./go/
   tar -C ./ -xzf "${GO_COMPILER_FILE}"
   export PATH=$PATH:$PWD/go/bin
}



function start_mender_service()
{
   echo "Starting mender connect service."
   systemctl enable mender-connect
   systemctl restart mender-connect
}

get_mender_connect
install_mender
start_mender_service
