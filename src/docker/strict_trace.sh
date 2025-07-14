#!/usr/bin/env bash
# Common safety + tracing header  (import with:  source strict_trace.sh)

set -xeuo pipefail
export PS4='[$(printf "%(%H:%M:%S)T" -1)] ${BASH_SOURCE##*/}:${LINENO}> '
