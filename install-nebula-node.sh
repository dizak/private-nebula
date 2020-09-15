#! /usr/bin/env bash

NEBULA_BINARIES_TARGET_DIR=/opt/nebula/
NEBULA_CERT_CONFIG_TARGET_DIR=/etc/nebula/
NEBULA_BINARY_FILENAME=nebula
NEBULA_CONFIG_FILENAME=config.yml
NEBULA_SERVICE_FILENAME=nebula.service

create-target-directories(){
# Create target directories for nebula binaries, config and certificates. Make
# sure the directories have proper permissions
# $1 Directory for nebula certificates and config
# $2 Directory for nebula binaries
    [ -e "${1}" ] || mkdir -p "${1}"
    [ -e "${2}" ] || mkdir -p "${2}"
    chown -R root:root "${1}"
    chown -R root:root "${2}"
    chmod 600 "${1}"
}

get-last-from-url(){
# Get the last element from a web-link after when splitting slashes
#$1 Web-link
    IFS="/" ;
    read -a link_arr <<< "${1}" ;
    echo "${link_arr[-1]}" ;
}

get-arch(){
# Determine cpu architecture
    arch=$(awk '/model name/ {print $4}' /proc/cpuinfo | head -n 1) ;
    echo "${arch}" ;
}

download-nebula-binaries(){
# Download nebula binaries right for the architecture.
# $1 Download directory
# $2 Target directory
    NEBULA_BINS_LINUX_AMD64="https://github.com/slackhq/nebula/releases/download/v1.2.0/nebula-linux-arm-6.tar.gz"
    NEBULA_BINS_LINUX_ARMv6="https://github.com/slackhq/nebula/releases/download/v1.2.0/nebula-linux-arm-6.tar.gz" 
    NEBULA_BINS_LINUX_ARMv7="https://github.com/slackhq/nebula/releases/download/v1.2.0/nebula-linux-arm-7.tar.gz" 

    ARCH=$(get-arch)

    case "${ARCH}" in
	"ARMv6-compatible")
	    NEBULA_BINS_LINK="${NEBULA_BINS_LINUX_ARMv6}"
	    NEBULA_BINS_OUTPUT_FILENAME=$(get-last-from-url "${NEBULA_BINS_LINK}")
	    ;;
	"ARMv7")
	    NEBULA_BINS_LINK="${NEBULA_BINS_LINUX_ARMv7}"
	    NEBULA_BINS_OUTPUT_FILENAME=$(get-last-from-url "${NEBULA_BINS_LINK}")
	    ;;
	"Intel(R)")
	    NEBULA_BINS_LINK="${NEBULA_BINS_LINUX_AMD64}"
	    NEBULA_BINS_OUTPUT_FILENAME=$(get-last-from-url "${NEBULA_BINS_LINK}")
	    ;;
    esac
    wget "${NEBULA_BINS_LINK}" -O /"${1}"/"${NEBULA_BINS_OUTPUT_FILENAME}"
    tar -x -C "${2}" -f "${1}${NEBULA_BINS_OUTPUT_FILENAME}"
}

create-nebula-config(){
# Generate nebula config and put it in desired path
# $1 Target path
# $2 Root certificate path
# $3 Node certificate path
# $4 Node key path
cat << EOF > "${1}"
pki:
  ca: "${2}"
  cert: "${3}"
  key: "${4}"
static_host_map:
  "192.168.101.1": ["161.35.170.249:4242"]
lighthouse:
  am_lighthouse: false
  interval: 60
  hosts:
  - "192.168.101.1"
listen:
  host: 0.0.0.0
  port: 4242
punchy:
  punch: true
tun:
  dev: nebula1
  drop_local_broadcast: false
  drop_multicast: false
  tx_queue: 500
  mtu: 1300
  routes:
  unsafe_routes:
logging:
  level: info
  format: text
firewall:
  conntrack:
    tcp_timeout: 12m
    udp_timeout: 3m
    default_timeout: 10m
    max_connections: 100000
  outbound:
    - port: any
      proto: any
      host: any
  inbound:
    - port: any
      proto: any
      host: any
EOF
}

create-systemd-service(){
# Create systemd service file, enable and start the service. Tested on Debian
# $1 Service name
# $2 Nebula binary path
# $3 Nebula config path
cat << EOF > /etc/systemd/system/"${1}"
[Unit]
Description=Nebula Network Overlay Node

[Service]
ExecStart="${2}" -config "${3}"

[Install]
WantedBy=default.target
EOF

systemctl enable "${1}"
systemctl start "${1}"
}
# CLI for certificate files paths
usage(){
    echo "Usage: $0 [-r path to root certificate] [-n path to node certificate] [-k path to node key]" 1>&2 ; exit 1 ;
}

while getopts ":r:n:k:" o; do
    case "${o}" in
	r)
	    ROOT_CERT=${OPTARG}
	    ;;
	n)
	    NODE_CERT=${OPTARG}
	    ;;
	k)
	    NODE_KEY=${OPTARG}
	    ;;
	*)
	    usage
	    ;;
    esac
done
shift $((OPTIND-1))

if [ -z "${ROOT_CERT}" ] || [ -z "${NODE_CERT}" ] || [ -z "${NODE_KEY}" ]; then
    usage
fi

NEBULA_ROOT_CRT_NAME=$(get-last-from-url "${ROOT_CERT}")
NEBULA_NODE_CRT_NAME=$(get-last-from-url "${NODE_CERT}")
NEBULA_NODE_KEY_NAME=$(get-last-from-url "${NODE_KEY}")

# Create target directories
create-target-directories "${NEBULA_CERT_CONFIG_TARGET_DIR}" "${NEBULA_BINARIES_TARGET_DIR}"
# Determine CPU architecture and download proper nebula binaries
download-nebula-binaries /tmp/ "${NEBULA_BINARIES_TARGET_DIR}"
# Create config YAML inside /etc/nebeula/
create-nebula-config "${NEBULA_CERT_CONFIG_TARGET_DIR}${NEBULA_CONFIG_FILENAME}" "${NEBULA_CERT_CONFIG_TARGET_DIR}${NEBULA_ROOT_CRT_NAME}" "${NEBULA_CERT_CONFIG_TARGET_DIR}${NEBULA_NODE_CRT_NAME}" "${NEBULA_CERT_CONFIG_TARGET_DIR}${NEBULA_NODE_KEY_NAME}"
# Move certificates to target directory
mv "${ROOT_CERT}" "${NEBULA_CERT_CONFIG_TARGET_DIR}"
mv "${NODE_CERT}" "${NEBULA_CERT_CONFIG_TARGET_DIR}"
mv "${NODE_KEY}" "${NEBULA_CERT_CONFIG_TARGET_DIR}"
# Create systemd service file
create-systemd-service "${NEBULA_SERVICE_FILENAME}" "${NEBULA_BINARIES_TARGET_DIR}${NEBULA_BINARY_FILENAME}" "${NEBULA_CERT_CONFIG_TARGET_DIR}${NEBULA_CONFIG_FILENAME}"
