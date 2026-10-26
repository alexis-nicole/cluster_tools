#!/usr/bin/env bash
# get-macs.sh: collect the MAC address of a given interface from each node.
# Run from blade00.
#
# Usage: ./get-macs.sh -i IFACE [-w] NODE [NODE...]
#   -i IFACE   interface name (required)
#   -w         output a MediaWiki table instead of plain text
#
# Example: ./get_macs.sh -i enp2s0f0 noe0{1..5}
:#          ./get_macs.sh -i enp2s0f0 -w node01 node02

usage() {
    echo "Usage: $0 -i IFACE [-w] NODE [NODE...]" >&2
    exit 1
}

IFACE=""
wiki=false

while getopts "i:wh" opt; do
    case "$opt" in
        i) IFACE="$OPTARG" ;;
        w) wiki=true ;;
        *) usage ;;
    esac
done
shift $((OPTIND - 1))

[[ -z "$IFACE" || $# -eq 0 ]] && usage

NODES=("$@")
SSH_OPTS="-o BatchMode=yes -o ConnectTimeout=5"

$wiki && { echo '{| class="wikitable"'; echo '! Node !! Interface !! MAC address'; }

for n in "${NODES[@]}"; do
    mac=$(ssh $SSH_OPTS "$n" "cat /sys/class/net/$IFACE/address" 2>/dev/null)
    [[ -z "$mac" ]] && mac="UNREACHABLE/NO_IFACE"
    if $wiki; then
        echo "|-"
        echo "| $n || $IFACE || $mac"
    else
        printf '%-12s %-12s %s\n' "$n" "$IFACE" "$mac"
    fi
done

$wiki && echo '|}'
