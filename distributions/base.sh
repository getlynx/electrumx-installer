# Contains functions that should work on all POSIX-compliant systems
function create_db_dir {
	mkdir -p $1
	chown electrumx:electrumx $1
}

function check_pyrocksdb {
	_py="${ELECTRUMX_PYTHON:-$python}"
    $_py -B -c "import rocksdb"
}

function setup_venv {
	VENV_DIR="${VENV_DIR:-/opt/electrumx-venv}"
	if [ ! -d "$VENV_DIR" ]; then
		$python -m venv "$VENV_DIR" || _error "Unable to create virtual environment at $VENV_DIR" 4
	fi
	ELECTRUMX_PYTHON="$VENV_DIR/bin/python"
	ELECTRUMX_PIP="$VENV_DIR/bin/pip"
	$ELECTRUMX_PIP install -U pip wheel > /dev/null 2>&1 || _error "Unable to prepare pip in virtual environment" 4
}

function pip_cmd {
	if [ -n "$ELECTRUMX_PIP" ]; then
		$ELECTRUMX_PIP "$@"
	else
		$python -m pip "$@"
	fi
}

APT="apt"

function install_pip {
	$APT install python3-pip
	if $python -m pip > /dev/null 2>&1; then
		_info "Installed pip3 for $python"
	else
		_error "Unable to install pip3"
	fi
}

function install_electrumx {
	_DIR=$(pwd)
	rm -rf "/tmp/electrumx/"
	git clone $ELECTRUMX_GIT_URL /tmp/electrumx
	cd /tmp/electrumx
	if [ -n "$ELECTRUMX_GIT_BRANCH" ]; then
		git checkout $ELECTRUMX_GIT_BRANCH
	else
		git checkout $(git describe --tags)
	fi
	if [ $USE_ROCKSDB == 1 ]; then
		# We don't necessarily want to install plyvel
		sed -i "s/'plyvel',//" setup.py
	fi
	if [ "$USE_VENV" == "1" ] && [ -n "$ELECTRUMX_PYTHON" ]; then
		sed -i "s:usr/bin/env python3:$ELECTRUMX_PYTHON:" electrumx_rpc
		sed -i "s:usr/bin/env python3:$ELECTRUMX_PYTHON:" electrumx_server
	elif [ "$python" != "python3" ]; then
		sed -i "s:usr/bin/env python3:usr/bin/env python3.9:" electrumx_rpc
		sed -i "s:usr/bin/env python3:usr/bin/env python3.9:" electrumx_server
	fi
	pip_cmd install . --upgrade > /dev/null 2>&1
	if ! pip_cmd install . --upgrade; then
		_error "Unable to install electrumx" 7
	fi
	if [ "$USE_VENV" == "1" ] && [ -n "$VENV_DIR" ]; then
		ln -sf "$VENV_DIR/bin/electrumx_server" /usr/local/bin/electrumx_server
		ln -sf "$VENV_DIR/bin/electrumx_rpc" /usr/local/bin/electrumx_rpc
	fi
	cd $_DIR
}

function install_python_rocksdb {
    pip_cmd install "Cython>=0.20"
	pip_cmd install python-rocksdb || _error "Could not install python_rocksdb" 1
}

function add_user {
	useradd electrumx
	id -u electrumx || _error "Could not add user account" 1
}

function generate_cert {
	if ! which openssl > /dev/null 2>&1; then
		_info "OpenSSL not found. Skipping certificates.."
		return
	fi
	_DIR=$(pwd)
	mkdir -p /etc/electrumx/
	cd /etc/electrumx
	openssl genrsa -des3 -passout pass:xxxx -out server.pass.key 2048
	openssl rsa -passin pass:xxxx -in server.pass.key -out server.key
	rm server.pass.key
	openssl req -new -key server.key -batch -out server.csr
	openssl x509 -req -days 1825 -in server.csr -signkey server.key -out server.crt
	rm server.csr
	chown electrumx:electrumx /etc/electrumx -R
	chmod 600 /etc/electrumx/server*
	cd $_DIR
	echo -e "\nSSL_CERTFILE=/etc/electrumx/server.crt" >> /etc/electrumx.conf
	echo "SSL_KEYFILE=/etc/electrumx/server.key" >> /etc/electrumx.conf
    echo "SERVICES=tcp://:50001,ssl://:50002,wss://:50004,rpc://" >> /etc/electrumx.conf
}

function ver { printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' '); }
