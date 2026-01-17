function install_init {
	if [ ! -d /etc/systemd/system ]; then
		_error "/etc/systemd/system does not exist. Is systemd installed?" 8
	fi
	cp /tmp/electrumx/contrib/systemd/electrumx.service /etc/systemd/system/electrumx.service
	cp /tmp/electrumx/contrib/systemd/electrumx.conf /etc/
	_conf="/etc/electrumx.conf"
	_doc1="# See https://electrumx-spesmilo.readthedocs.io/en/latest/environment.html for"
	_doc2="# information about other configuration settings you probably want to consider."
	if [ -f "$_conf" ]; then
		_tmp=$(mktemp)
		if grep -q "electrumx-spesmilo.readthedocs.io/en/latest/environment.html" "$_conf"; then
			printf "%s\n" "$_doc1" >> "$_tmp"
			printf "%s\n" "$_doc2" >> "$_tmp"
		fi
		awk '{
			if ($0 == "# default /etc/electrumx.conf for systemd") next
			if ($0 ~ /^# *COIN *=/) next
			if ($0 == "# See https://electrumx-spesmilo.readthedocs.io/en/latest/environment.html for") next
			if ($0 == "# information about other configuration settings you probably want to consider.") next
			print
		}' "$_conf" >> "$_tmp"
		cat "$_tmp" > "$_conf"
		rm -f "$_tmp"
	fi
	echo -e "\n# Enter the chain/network (e.g. Lynx, DigitalCoin, InfiniLooP). Set to the coin you want to serve. Not case sensitive." >> /etc/electrumx.conf
	echo "# Example: COIN=Lynx" >> /etc/electrumx.conf
	if [ -n "$COIN" ]; then
		echo "COIN=$COIN" >> /etc/electrumx.conf
	fi
	if [ $USE_ROCKSDB == 1 ]; then
		echo -e "\nDB_ENGINE=rocksdb" >> /etc/electrumx.conf
	fi
	systemctl daemon-reload
	systemctl enable electrumx
	systemctl status electrumx
	_info "Use service electrumx start to start electrumx once it's configured"
}
