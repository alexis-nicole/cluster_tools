#!/bin/bash
# ^ "Shebang": run this file with bash.
#
# Deploy and run install_deps.sh as root on the compute nodes, from blade00.
#
# Usage: ./deploy_install_deps.sh [-v] [-n "blade01 blade02"]
#   -v          pass verbose mode to install_deps.sh
#   -n NODES    space-separated node list (default: blade01..blade05)
#
# The full terminal output for each node is saved to ~/install_logs/<node>_<timestamp>.log
# (the node also keeps its own copy in /var/log/install_deps.log).

# Directory this script lives in, so install_deps.sh is found next to it
# no matter where you run the script from.
#   dirname "$0"  = folder of this script;  cd + pwd = turn it into an absolute path
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Defaults, which the options below may override.
NODES="blade01 blade02 blade03 blade04 blade05"   # nodes to install on
FLAGS=""                                          # extra flags passed to install_deps.sh

# Parse options: "vn:h" = -v (flag), -n NODES (takes an argument), -h (help).
while getopts "vn:h" opt; do
    case "$opt" in
        v) FLAGS="-v" ;;                     # verbose mode on the nodes
        n) NODES="$OPTARG" ;;                # replace the node list with the one given after -n
        h|*) sed -n '2,9p' "$0"; exit 1 ;;   # print the usage lines above and quit
    esac
done

LOGDIR="$HOME/install_logs"        # per-node logs are kept on this machine
mkdir -p "$LOGDIR"                 # create the folder if it does not exist (no error if it does)
STAMP=$(date +%Y%m%d_%H%M%S)       # timestamp so repeated runs do not overwrite old logs
FAILED=()                          # empty array that collects the names of nodes that fail

# Handle one node at a time (sequentially, so password prompts do not interleave).
for n in $NODES; do
    echo "== $n  (log: $LOGDIR/${n}_${STAMP}.log)"

    # Copy the install script to the node. If the copy fails (node down, bad key, etc.),
    # record the node as failed and skip to the next one.
    scp "$SCRIPT_DIR/install_deps.sh" "$n:/tmp/install_deps.sh" || { FAILED+=("$n"); continue; }

    # Run the script on the node as root:
    #   ssh -t           allocates a terminal so the sudo password prompt works
    #   sudo bash ...    runs the install script as root, passing $FLAGS (for example -v)
    #   rc=$?            saves the install script's exit code
    #   rm -f ...        deletes the copied script afterwards, even if the install failed
    #   exit $rc         makes ssh return the install script's exit code (the \$ escapes
    #                    stop the LOCAL shell from expanding them, so the REMOTE shell does)
    #   2>&1 | tee ...   show the output on screen AND save it to this node's log file
    ssh -t "$n" "sudo bash /tmp/install_deps.sh $FLAGS; rc=\$?; rm -f /tmp/install_deps.sh; exit \$rc" \
        2>&1 | tee "$LOGDIR/${n}_${STAMP}.log"

    # In a pipeline, $? would be tee's exit code. PIPESTATUS[0] is ssh's, which is the
    # one that says whether the install worked. Non-zero means it failed.
    [ "${PIPESTATUS[0]}" -eq 0 ] || FAILED+=("$n")
done

echo    # blank line before the summary

# Summary: ${#FAILED[@]} is the number of failed nodes.
if [ ${#FAILED[@]} -eq 0 ]; then
    echo "All nodes completed. Logs in $LOGDIR"
else
    echo "FAILED on: ${FAILED[*]}  (see $LOGDIR/*_${STAMP}.log)"
    exit 1    # exit with a failure code so callers and scripts can detect the problem
fi
