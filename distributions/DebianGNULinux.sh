if [ "$VERSION_ID" !=  "12" && "$VERSION_ID" != "13" ]; then
	_warning "Only Debian Bookworm (12) and Trixie (13) are officially supported (but this might work)"
fi

. distributions/base.sh
. distributions/base-systemd.sh
. distributions/base-debianoid.sh
. distributions/base-compile-rocksdb.sh

APT="apt-get"

USE_VENV=1
VENV_DIR="/opt/electrumx-venv"

if [ $(ver "$VERSION_ID") -ge $(ver "12") ]; then
	newer_rocksdb=1
fi

function install_python {
	$APT update
	$APT install -y python3 python3-venv python3-pip python3-dev || _error "Could not install Python" 1
}

function install_leveldb {
	$APT install -y libleveldb-dev build-essential || _error "Could not install packages" 1
}
