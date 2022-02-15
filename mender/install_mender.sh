#!/bin/bash
set -e

if [ "$EUID" -ne 0 ]
  then echo "Please run with sudo"
  exit
fi



function get_mender_connect()
{
   [ ! -d ./mender/mender-connect ] && git clone -b 2.0.1 https://github.com/mendersoftware/mender-connect.git ./mender/mender-connect
   true
}

function install_libs_mender()
{
   apt install ./mender/libffi6_3.2.1-9_arm64.deb
}

function install_mender_client()
{
   cp -R ./mender/mender /etc/
   cp -r ./mender/lib/mender /var/lib/
   apt install ./mender/mender-client_3.1.0-1_arm64.deb
}

function install_mender()
{
   install_libs_mender
   install_mender_client

   install_mender_connect_from_sources
} 


function install_mender_connect_from_sources()
{
   install_go_compiler
#   apt-get install libglib2.0-dev

   echo "Building mender connect..."
   cd ./mender-connect
   make build
   make install
}

function install_go_compiler()
{
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
   rm -rf ./go/
   tar -C ./ -xzf "${GO_COMPILER_FILE}"
   export PATH=$PATH:$PWD/go/bin
}



function start_mender_service()
{
   systemctl enable mender-connect
   systemctl restart mender-connect
}

get_mender_connect
install_mender
start_mender_service
