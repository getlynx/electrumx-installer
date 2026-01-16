PIP3="${PIP3:-pip3}"
APT="${APT:-apt}"

function install_rocksdb {
	if ! declare -f install_rocksdb_dependencies > /dev/null; then
		_error "install_rocksdb_dependencies needs to be declared in order to use compile-rocksdb/install_rocksdb" 3
	fi
	install_rocksdb_dependencies
	_DIR=$(pwd)
	
	_info "Installing RocksDB... This will take a while."
	$APT install -y librocksdb-dev
	if declare -f pip_cmd > /dev/null; then
		pip_cmd install python-rocksdb
	else
		$PIP3 install python-rocksdb
	fi
}
