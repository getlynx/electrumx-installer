APT="apt"

function install_git {
	$APT install -y git unzip liblz4-dev || _error "Could not install packages"
}

function install_script_dependencies {
	$APT update
	$APT install -y openssl wget python3 python3-venv python3-pip python3-dev pkg-config || _error "Could not install packages"
}

function install_rocksdb_dependencies {
	$APT install -y libsnappy-dev libzstd-dev liblz4-dev zlib1g-dev libbz2-dev libgflags-dev || _error "Could not install packages"
}

function install_compiler {
	$APT update
	$APT install -y bzip2 build-essential gcc || _error "Could not install packages"
}
