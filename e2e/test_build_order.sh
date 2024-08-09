#!/bin/bash
# -*- indent-tabs-mode: nil; tab-width: 2; sh-indentation: 2; -*-

# Test to show that we get a detailed error message if a dependency is
# not available when setting up to build a package.

SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
source "$SCRIPTDIR/common.sh"

# What are we building?
DIST="stevedore"
VERSION="5.2.0"

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
pypi-mirror create -d "$OUTDIR/wheels-repo/downloads/" -m "$OUTDIR/wheels-repo/simple/"

start_local_wheel_server

# Rebuild everything
fromager \
    --log-file "$OUTDIR/build-logs/${DIST}-build.log" \
    --work-dir "$OUTDIR/work-dir" \
    --sdists-repo "$OUTDIR/sdists-repo" \
    --wheels-repo "$OUTDIR/wheels-repo" \
    build-sequence "$OUTDIR/build-order.json" "https://pypi.org/simple"

find "$OUTDIR/wheels-repo/"

EXPECTED_FILES="
$OUTDIR/wheels-repo/downloads/setuptools-*.whl
$OUTDIR/wheels-repo/downloads/pbr-*.whl
$OUTDIR/wheels-repo/downloads/stevedore-*.whl

$OUTDIR/sdists-repo/downloads/stevedore-*.tar.gz
$OUTDIR/sdists-repo/downloads/setuptools-*.tar.gz
$OUTDIR/sdists-repo/downloads/pbr-*.tar.gz
"

pass=true
for pattern in $EXPECTED_FILES; do
  if [ ! -f "${pattern}" ]; then
    echo "Did not find $pattern" 1>&2
    pass=false
  fi
done

# Rebuild everything with the skip flag and verify we reuse the existing wheels
log="$OUTDIR/build-logs/${DIST}-build-skip.log"
fromager \
    --wheel-server-url $WHEEL_SERVER_URL \
    --log-file "$log" \
    --work-dir "$OUTDIR/work-dir" \
    --sdists-repo "$OUTDIR/sdists-repo" \
    --wheels-repo "$OUTDIR/wheels-repo" \
    build-sequence --skip-existing "$OUTDIR/build-order.json" "https://pypi.org/simple"

find "$OUTDIR/wheels-repo/"

if ! grep -q "skipping builds for versions of packages available" "$log"; then
  echo "Did not find message indicating builds would be skipped" 1>&2
  pass=false
fi
if ! grep -q "skipping building wheels for stevedore" "$log"; then
  echo "Did not find message indicating build of stevedore was skipped" 1>&2
  pass=false
fi


# Rebuild everything with the skip env var and verify we reuse the existing wheels
export FROMAGER_BUILD_SEQUENCE_SKIP_EXISTING=true
log="$OUTDIR/build-logs/${DIST}-build-skip-env.log"
fromager \
    --wheel-server-url $WHEEL_SERVER_URL \
    --log-file "$log" \
    --work-dir "$OUTDIR/work-dir" \
    --sdists-repo "$OUTDIR/sdists-repo" \
    --wheels-repo "$OUTDIR/wheels-repo" \
    build-sequence "$OUTDIR/build-order.json" "https://pypi.org/simple"

find "$OUTDIR/wheels-repo/"

if ! grep -q "skipping builds for versions of packages available" "$log"; then
  echo "Did not find message indicating builds would be skipped" 1>&2
  pass=false
fi
if ! grep -q "skipping building wheels for stevedore" "$log"; then
  echo "Did not find message indicating build of stevedore was skipped" 1>&2
  pass=false
fi

$pass
