#!/bin/bash
if [ -d ~/.electrumx-installer ]; then
    echo "~/.electrumx-installer already exists."
    echo "Either delete the directory or run ~/.electrumx-installer/install.sh directly."
    exit 1
fi
if command -v git > /dev/null 2>&1; then
    git clone https://github.com/getlynx/electrumx-installer ~/.electrumx-installer
    cd ~/.electrumx-installer/
else
    if ! (command -v wget > /dev/null 2>&1 && command -v unzip > /dev/null 2>&1); then
        if command -v apt-get > /dev/null 2>&1; then
            apt-get update
            apt-get install -y git wget unzip
        else
            echo "Please install git or wget and unzip"
            exit 1
        fi
    fi
    wget https://github.com/getlynx/electrumx-installer/archive/master.zip -O /tmp/electrumx-master.zip
    unzip /tmp/electrumx-master.zip -d ~/.electrumx-installer
    rm /tmp/electrumx-master.zip
    cd ~/.electrumx-installer/electrumx-installer-master/ 
fi
if [[ $EUID -ne 0 ]]; then
    which sudo > /dev/null 2>&1 || { echo "You need to run this script as root" && exit 1 ; }
    sudo -H ./install.sh "$@"
else
    ./install.sh "$@"
fi
