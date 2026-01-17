function install_init {
	if [ ! -d /etc/systemd/system ]; then
		_error "/etc/systemd/system does not exist. Is systemd installed?" 8
	fi
	cp /tmp/electrumx/contrib/systemd/electrumx.service /etc/systemd/system/electrumx.service
	cp /tmp/electrumx/contrib/systemd/electrumx.conf /etc/
	echo -e "\n# Enter the chain/network (e.g. Lynx, DigitalCoin, InfiniLooP, etc). Set to the coin you want to serve. Not case sensitive." >> /etc/electrumx.conf
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
