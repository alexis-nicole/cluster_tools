#!/bin/bash
# Gracefully shut down selected compute nodes from the head node (node00).
# The head node itself is never shut down.
#
# Usage: shutdown_compute_nodes.sh [-n NODELIST] [-d] [-f] [-h]
#   -n NODELIST  nodes to shut down; comma list or Slurm range notation
#                (e.g. node01,node03  or  node[01-03]).
#                Default: node[01-05]
#   -d           dry run: show what would happen, change nothing
#   -f           force: shut down even if jobs are running on the nodes
#   -h           show this help
#
# Passwords:
#   - you are prompted for your sudo password on node00 (Slurm drain)
#   - for each node you are prompted for the SSH password and then the
#     sudo password on that node (no passwordless setup needed)

NODESPEC="node[01-05]"
DRY_RUN=0
FORCE=0

usage() { sed -n '2,16p' "$0" | sed 's/^# \{0,1\}//'; }

while getopts "n:dfh" opt; do
  case "$opt" in
    n) NODESPEC="$OPTARG" ;;
    d) DRY_RUN=1 ;;
    f) FORCE=1 ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

if [ "$(hostname -s)" != "node00" ]; then
  echo "This script must be run on the head node (node00)."
  exit 1
fi

# Expand ranges like node[01-03] into individual hostnames
mapfile -t NODES < <(scontrol show hostnames "$NODESPEC" 2>/dev/null)
if [ "${#NODES[@]}" -eq 0 ]; then
  echo "No valid nodes in: $NODESPEC"
  exit 1
fi

for node in "${NODES[@]}"; do
  if [ "$node" = "node00" ]; then
    echo "Refusing to shut down the head node (node00)."
    exit 1
  fi
done

run() {
  if [ "$DRY_RUN" -eq 1 ]; then
    echo "[dry-run] $*"
  else
    "$@"
  fi
}

NODELIST=$(IFS=,; echo "${NODES[*]}")
echo "Target nodes: $NODELIST"

# 1. Check for running jobs on the target nodes
RUNNING=$(squeue -h -w "$NODELIST" -t RUNNING -o "%i %u %j" 2>/dev/null)
if [ -n "$RUNNING" ]; then
  echo "Jobs are running on the target nodes:"
  echo "$RUNNING"
  if [ "$FORCE" -ne 1 ]; then
    echo "Aborting. Wait for them to finish, or use -f."
    exit 1
  fi
  echo "-f given, continuing."
fi

# 2. Drain nodes so Slurm stops scheduling new work on them
echo "Draining nodes in Slurm: $NODELIST"
run sudo scontrol update NodeName="$NODELIST" State=DRAIN Reason="planned shutdown"

# 3. Power off each node
for node in "${NODES[@]}"; do
  echo "Shutting down $node ..."
  # -t allocates a terminal so SSH and sudo can prompt for passwords.
  # ssh may exit non-zero even on success because the connection drops as
  # the node powers off, so verify with ping/sinfo afterwards.
  run ssh -t -o ConnectTimeout=10 "$node" "sudo systemctl poweroff" \
    || echo "  NOTE: ssh to $node exited non-zero (login failed, unreachable, or the connection dropped during shutdown)"
done

echo "Done. Nodes will show as down in 'sinfo' once slurmctld notices."
echo "After powering them back on, return them to service with:"
echo "  sudo scontrol update NodeName=$NODELIST State=RESUME"
