#!/bin/bash
# -*- indent-tabs-mode: nil; tab-width: 2; sh-indentation: 2; -*-

# Test to show that we get a detailed error message if a dependency is
# not available when setting up to build a package.

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

set -x
set -e
set -o pipefail

on_exit() {
  [ "$HTTP_SERVER_PID" ] && kill "$HTTP_SERVER_PID"
}
trap on_exit EXIT SIGINT SIGTERM

# Bootstrap to create the build order file.
OUTDIR="$(dirname "$SCRIPTDIR")/e2e-output"

# What are we building?
DIST="stevedore"
VERSION="5.2.0"

# Recreate output directory
rm -rf "$OUTDIR"
mkdir -p "$OUTDIR/build-logs"

# Set up virtualenv with the CLI and dependencies.
tox -e cli -n
source ".tox/cli/bin/activate"

# Bootstrap the test project
fromager \
    --sdists-repo="$OUTDIR/sdists-repo" \
    --wheels-repo="$OUTDIR/wheels-repo" \
    --work-dir="$OUTDIR/work-dir" \
    bootstrap "${DIST}==${VERSION}"

# Save the build order file but remove everything else.
cp "$OUTDIR/work-dir/build-order.json" "$OUTDIR/"
rm -r "$OUTDIR/work-dir" "$OUTDIR/sdists-repo" "$OUTDIR/wheels-repo"

# Rebuild the wheel mirror to be empty
rm -rf "$OUTDIR/wheels-repo/simple"
.tox/cli/bin/pypi-mirror create -d "$OUTDIR/wheels-repo/downloads/" -m "$OUTDIR/wheels-repo/simple/"

# Start a web server for the wheels-repo. We remember the PID so we
# can stop it later, and we determine the primary IP of the host
# because podman won't see the server via localhost.
.tox/cli/bin/python3 -m http.server --directory "$OUTDIR/wheels-repo/" 9090 &
HTTP_SERVER_PID=$!
IP=$(ip route get 1.1.1.1 | grep 1.1.1.1 | awk '{print $7}')
export WHEEL_SERVER_URL="http://${IP}:9090/simple"

# Define the function used in the build script
build_wheel() {
    local -r dist="$1"
    local -r version="$2"

    # Download the source archive
    fromager \
        --log-file "$OUTDIR/build-logs/${dist}-download-source-archive.log" \
        --work-dir "$OUTDIR/work-dir" \
        --sdists-repo "$OUTDIR/sdists-repo" \
        --wheels-repo "$OUTDIR/wheels-repo" \
        download-source-archive "$dist" "$version" "https://pypi.org/simple"

    # Prepare the source dir for building
    fromager \
        --log-file "$OUTDIR/build-logs/${dist}-prepare-source.log" \
        --work-dir "$OUTDIR/work-dir" \
        --sdists-repo "$OUTDIR/sdists-repo" \
        --wheels-repo "$OUTDIR/wheels-repo" \
        prepare-source "$dist" "$version"

    # Prepare the build environment
    fromager \
        --log-file "$OUTDIR/build-logs/${dist}-prepare-build.log" \
        --work-dir "$OUTDIR/work-dir" \
        --sdists-repo "$OUTDIR/sdists-repo" \
        --wheels-repo "$OUTDIR/wheels-repo" \
        --wheel-server-url "${WHEEL_SERVER_URL}" \
        prepare-build "$dist" "$version"

    # Build the wheel
    fromager \
        --log-file "$OUTDIR/build-logs/${dist}-prepare-build.log" \
        --work-dir "$OUTDIR/work-dir" \
        --sdists-repo "$OUTDIR/sdists-repo" \
        --wheels-repo "$OUTDIR/wheels-repo" \
        --wheel-server-url "${WHEEL_SERVER_URL}" \
        build "$dist" "$version"

    # update the wheel server
    pypi-mirror \
        create \
        -d "$OUTDIR/wheels-repo/downloads/" \
        -m "$OUTDIR/wheels-repo/simple/"

}

# Create and run a script to build everything, one wheel at a time.
#
# This is a little convoluted, but protects us from subshells
# swallowing any errors in individual steps like we would see if we
# passed the output of 'jq' to a while loop.
jq -r '.[] | "build_wheel " + .dist + " " + .version' \
   "$OUTDIR/build-order.json" \
   > "$OUTDIR/build.sh"
source "$OUTDIR/build.sh"