#!/bin/bash
#
# Install build dependencies on a cluster node. Must run as root.
#
# Usage: sudo bash install_deps.sh [-v] [-l LOGFILE]
#   -v          verbose: trace every command (set -x) and show apt package versions
#   -l LOGFILE  log file (default: /var/log/install_deps.log)
#
# All terminal output (stdout and stderr, including the -v trace) is appended to the log.

# Safety switches for the whole script:
#   -e          exit immediately if any command fails
#   -u          treat use of an undefined variable as an error
#   -o pipefail a pipeline fails if ANY command in it fails, not just the last one
set -euo pipefail

# Default settings, which the options below may override.
VERBOSE=0                          # 0 = normal output, 1 = verbose (set by -v)
LOG=/var/log/install_deps.log      # where all output is saved (changed by -l)

# Parse command-line options. The string "vl:h" means:
#   v  = flag with no argument,  l: = option that takes an argument (the colon),  h = flag
while getopts "vl:h" opt; do
    case "$opt" in
        v) VERBOSE=1 ;;            # -v given: turn on verbose mode
        l) LOG="$OPTARG" ;;        # -l FILE given: $OPTARG holds FILE
        h|*) sed -n '2,8p' "$0"; exit 1 ;;   # -h or an unknown option: print the usage lines above and quit
    esac
done

# "id -u" prints the numeric user ID; root is 0. Refuse to run as anyone else,
# because apt-get install needs root.
if [ "$(id -u)" -ne 0 ]; then
    echo "Run as root: sudo bash $0" >&2     # >&2 sends the message to stderr
    exit 1                                    # non-zero exit code = failure
fi

# Duplicate everything the script prints (stdout and stderr) into the log file:
#   exec > >(...)   redirects all later stdout into a background "tee" process
#   tee -a "$LOG"   writes each line to the terminal AND appends it to the log
#   2>&1            sends stderr to the same place as stdout, so errors are logged too
exec > >(tee -a "$LOG") 2>&1

# Tell apt/dpkg never to open interactive configuration dialogs,
# which would hang an unattended run.
export DEBIAN_FRONTEND=noninteractive

# Build the list of options passed to every apt-get install command.
APT_OPTS=(-y)                      # -y answers "yes" to confirmation prompts
if [ "$VERBOSE" -eq 1 ]; then
    APT_OPTS+=(-V)                 # -V shows the version of every package being installed
    export PS4='+ [$(date +%T)] '  # PS4 is the prefix printed before each traced command; this adds a time stamp
    set -x                         # trace mode: print every command before running it
else
    APT_OPTS+=(-q)                 # -q makes apt print less (no progress bars)
fi

# Header line in the log: date (ISO format), node name, and the settings in use.
echo "=== $(date -Is) install_deps on $(hostname) (verbose=$VERBOSE, log=$LOG) ==="


#######################################################################################
# USER INPUT NEEDED !                                                                 #
#                                                                                     #
# Adjust the argument of the apt-get install command to suit your specific needs, and #
# add additional command you want to execute on each node                             #
#######################################################################################

# Refresh the package index so apt knows the current versions and names.
apt-get update

# Install the main set of packages. "${APT_OPTS[@]}" expands to the options built above.
# The backslashes at the end of each line continue the command onto the next line.
#   bison flex                     parser/lexer generators
#   clang llvm                     C/C++ compiler and the LLVM toolchain
#   git make cmake                 version control and build tools
#   maven default-jdk              Java build tool and the Java compiler/runtime
#   swig                           generates wrappers that connect C/C++ to other languages
#   curl zip                       download and archive utilities
#   g++                            GNU C++ compiler
#   libx11-dev libxt-dev           X11 development headers
#   libmotif-common libmotif-dev   Motif GUI toolkit and its headers
#   libxml2-dev                    XML parser headers
#   python3-dev                    Python 3 headers, needed to build Python extensions
#   zlib1g-dev                     compression library headers
#   llvm-dev libclang-dev          LLVM and Clang development headers
#   libudunits2-dev                unit conversion library headers
apt-get install "${APT_OPTS[@]}" \
    bison clang flex git llvm make maven swig cmake \
    curl g++ libx11-dev libxml2-dev libxt-dev libmotif-common libmotif-dev \
    python3-dev zlib1g-dev llvm-dev libclang-dev libudunits2-dev \
    default-jdk zip libgtest-dev hdf5-tools libhdf5-dev libgsl-dev

# PYTHON_VERSION=3 steers configure scripts to python3 instead of python2.7.
# An export inside this script dies with the script, so persist it for login shells:
# every file in /etc/profile.d/ is read by bash at login.
echo 'export PYTHON_VERSION=3' > /etc/profile.d/python_version.sh
chmod 0644 /etc/profile.d/python_version.sh   # owner read/write, everyone else read-only

# Footer line in the log with the finish time.
echo "=== $(date -Is) done on $(hostname) ==="
