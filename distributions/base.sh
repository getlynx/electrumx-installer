# Contains functions that should work on all POSIX-compliant systems
function create_db_dir {
	mkdir -p $1
	chown electrumx:electrumx $1
}

function check_pyrocksdb {
	_py="${ELECTRUMX_PYTHON:-$python}"
    $_py -B -c "import rocksdb"
}

function prompt_ssl_cert {
	if [ -n "$SSL_CERTFILE" ] || [ -n "$SSL_KEYFILE" ]; then
		return
	fi
	_tty_in=""
	if [ -t 0 ]; then
		_tty_in="/dev/stdin"
	elif [ -r /dev/tty ]; then
		_tty_in="/dev/tty"
	else
		return
	fi
	printf "\n\n\n\n\n" >&3
	printf "Use a custom TLS certificate? (y/N) " >&3
	if ! read -r -t 900 _ssl_reply < "$_tty_in"; then
		_warning "No response in 15 minutes. Using self-signed certificate."
		return
	fi
	case "$_ssl_reply" in
		y|Y|yes|YES)
			_ssl_cert_path="/etc/electrumx/custom.crt"
			_ssl_key_path="/etc/electrumx/custom.key"
			mkdir -p /etc/electrumx/

			printf "Paste certificate (end with END CERT or -----END CERTIFICATE-----):\n" >&3
			_ssl_cert_content=""
			while true; do
				if ! read -r -t 900 _line < "$_tty_in"; then
					_warning "No response in 15 minutes. Using self-signed certificate."
					return
				fi
				if [ "$_line" = "END CERT" ]; then
					break
				fi
				_ssl_cert_content="${_ssl_cert_content}${_line}\n"
				if [ "$_line" = "-----END CERTIFICATE-----" ]; then
					break
				fi
			done

			printf "Paste private key (end with END KEY or -----END PRIVATE KEY-----):\n" >&3
			_ssl_key_content=""
			while true; do
				if ! read -r -t 900 _line < "$_tty_in"; then
					_warning "No response in 15 minutes. Using self-signed certificate."
					return
				fi
				if [ "$_line" = "END KEY" ]; then
					break
				fi
				_ssl_key_content="${_ssl_key_content}${_line}\n"
				if [ "$_line" = "-----END PRIVATE KEY-----" ] || [ "$_line" = "-----END RSA PRIVATE KEY-----" ] || [ "$_line" = "-----END EC PRIVATE KEY-----" ]; then
					break
				fi
			done

			if [ -n "$_ssl_cert_content" ] && [ -n "$_ssl_key_content" ]; then
				printf "%b" "$_ssl_cert_content" > "$_ssl_cert_path"
				printf "%b" "$_ssl_key_content" > "$_ssl_key_path"
				chown electrumx:electrumx /etc/electrumx -R
				chmod 600 "$_ssl_key_path"
				SSL_CERTFILE="$_ssl_cert_path"
				SSL_KEYFILE="$_ssl_key_path"
			else
				_warning "Certificate or key input was empty. Using self-signed certificate."
			fi
			;;
	esac
}

function prompt_report_services {
	if [ -n "$REPORT_DOMAIN" ]; then
		return
	fi
	_tty_in=""
	if [ -t 0 ]; then
		_tty_in="/dev/stdin"
	elif [ -r /dev/tty ]; then
		_tty_in="/dev/tty"
	else
		REPORT_DOMAIN="electrumx.example.com"
		return
	fi
	printf "Enter Electrum server domain for REPORT_SERVICES (default: electrumx.example.com): " >&3
	if ! read -r -t 900 _report_domain < "$_tty_in"; then
		_warning "No response in 15 minutes. Using default REPORT_SERVICES domain."
		REPORT_DOMAIN="electrumx.example.com"
		return
	fi
	if [ -n "$_report_domain" ]; then
		REPORT_DOMAIN="$_report_domain"
	else
		REPORT_DOMAIN="electrumx.example.com"
	fi
}

function prompt_coin {
	if [ -n "$COIN" ]; then
		return
	fi
	_tty_in=""
	if [ -t 0 ]; then
		_tty_in="/dev/stdin"
	elif [ -r /dev/tty ]; then
		_tty_in="/dev/tty"
	else
		_error "COIN is required but no interactive terminal is available." 10
	fi
	printf "\n\n\n\n\n" >&3
	printf "Enter the chain or network (e.g., Lynx, DigitalCoin, InfiniLooP). Value is required: " >&3
	if ! read -r -t 900 _coin < "$_tty_in"; then
		_error "No COIN provided within 15 minutes." 10
	fi
	if [ -z "$_coin" ]; then
		_error "COIN cannot be blank." 10
	fi
	COIN="$_coin"
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
	REPORT_DOMAIN="${REPORT_DOMAIN:-electrumx.example.com}"
	if [ -n "$SSL_CERTFILE" ] && [ -n "$SSL_KEYFILE" ]; then
		if [ -f "$SSL_CERTFILE" ] && [ -f "$SSL_KEYFILE" ]; then
			echo -e "\n# SSL_CERTFILE/SSL_KEYFILE: point to your TLS cert and key." >> /etc/electrumx.conf
			echo "# You can replace these files manually (e.g., 15yr Cloudflare Origin Certificate), or" >> /etc/electrumx.conf
			echo "# use Certbot with automation to update these paths as certificates rotate." >> /etc/electrumx.conf
			echo "SSL_CERTFILE=$SSL_CERTFILE" >> /etc/electrumx.conf
			echo "SSL_KEYFILE=$SSL_KEYFILE" >> /etc/electrumx.conf
			echo -e "\n# SERVICES: listeners this server opens (tcp/ssl/wss/rpc). We enable only secure ports:" >> /etc/electrumx.conf
			echo "#  - tcp://:50001 for plaintext TCP clients (optional, not enabled by default)" >> /etc/electrumx.conf
			echo "#  - ssl://:50002 for TLS TCP clients" >> /etc/electrumx.conf
			echo "#  - wss://:50004 for TLS WebSocket clients" >> /etc/electrumx.conf
			echo "# rpc:// is local-only RPC for administration; no public port here." >> /etc/electrumx.conf
			echo "SERVICES=ssl://:50002,wss://:50004,rpc://" >> /etc/electrumx.conf
			echo -e "\n# REPORT_SERVICES: public addresses/ports advertised to peers/clients." >> /etc/electrumx.conf
			echo "# We advertise only secure endpoints (ssl/wss) for clients." >> /etc/electrumx.conf
			echo "# Optional plaintext advertise: tcp://<domain>:50001 (optional, not enabled by default)." >> /etc/electrumx.conf
			echo "REPORT_SERVICES=wss://$REPORT_DOMAIN:50004,ssl://$REPORT_DOMAIN:50002" >> /etc/electrumx.conf
			return
		else
			_warning "Provided SSL cert or key not found. Falling back to self-signed certificate."
		fi
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
	echo -e "\n# SSL_CERTFILE/SSL_KEYFILE: point to your TLS cert and key." >> /etc/electrumx.conf
	echo "# You can replace these files manually (e.g., 15yr Cloudflare Origin Certificate), or" >> /etc/electrumx.conf
	echo "# use Certbot with automation to update these paths as certificates rotate." >> /etc/electrumx.conf
	echo "SSL_CERTFILE=/etc/electrumx/server.crt" >> /etc/electrumx.conf
	echo "SSL_KEYFILE=/etc/electrumx/server.key" >> /etc/electrumx.conf
	echo -e "\n# SERVICES: listeners this server opens (tcp/ssl/wss/rpc). We enable only secure ports:" >> /etc/electrumx.conf
	echo "#  - tcp://:50001 for plaintext TCP clients (optional, not enabled here)" >> /etc/electrumx.conf
	echo "#  - ssl://:50002 for TLS TCP clients" >> /etc/electrumx.conf
	echo "#  - wss://:50004 for TLS WebSocket clients" >> /etc/electrumx.conf
	echo "# rpc:// is local-only RPC for administration; no public port here." >> /etc/electrumx.conf
    echo "SERVICES=ssl://:50002,wss://:50004,rpc://" >> /etc/electrumx.conf
	echo -e "\n# REPORT_SERVICES: public addresses/ports advertised to peers/clients." >> /etc/electrumx.conf
	echo "# We advertise only secure endpoints (ssl/wss) for clients." >> /etc/electrumx.conf
	echo "# Optional plaintext advertise: tcp://<domain>:50001 (not used here)." >> /etc/electrumx.conf
	echo "REPORT_SERVICES=wss://$REPORT_DOMAIN:50004,ssl://$REPORT_DOMAIN:50002" >> /etc/electrumx.conf
}

function ver { printf "%03d%03d%03d%03d" $(echo "$1" | tr '.' ' '); }
