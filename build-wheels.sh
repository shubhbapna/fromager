#!/bin/bash

set -xe

# Redirect stdout/stderr to logfile
logfile=".build_wheels_$(date '+%Y-%m-%d_%H-%M-%S').log"
exec > >(tee "$logfile") 2>&1

VENV=$(basename $(mktemp --dry-run --directory --tmpdir=. venvXXXX))
PYTHON=python3.9
HTTP_SERVER_PID=
WHEEL_MIRROR_TMPDIR=
WHEEL_BUILD_TMPDIR=

on_exit() {
  [ "$HTTP_SERVER_PID" ] && kill $HTTP_SERVER_PID
  #[ $WHEEL_MIRROR_TMPDIR ] && rm -rf $WHEEL_MIRROR_TMPDIR
  [ $WHEEL_BUILD_TMPDIR ] && rm -rf $WHEEL_BUILD_TMPDIR
  rm -rf $VENV/
}
trap on_exit EXIT

setup() {
  $PYTHON -m venv $VENV
  . ./$VENV/bin/activate
  pip install -U pip
}

setup

pip install -U python-pypi-mirror

WHEEL_MIRROR_TMPDIR=$(realpath $(mktemp --tmpdir=. --directory wheelmirrorXXXX))
mkdir $WHEEL_MIRROR_TMPDIR/downloads

# Ensure the repo has a pip wheel to avoid warnings when pip checks for an update
# FIXME: this should be a re-built pip wheel, not one from PyPI
# FIXME: or just use --disable-pip-version-check
#pip -vvv download --dest $WHEEL_MIRROR_TMPDIR/downloads pip

update_mirror() {
  pypi-mirror create -d $WHEEL_MIRROR_TMPDIR/downloads -m $WHEEL_MIRROR_TMPDIR/simple
}

update_mirror
$PYTHON -m http.server -d $WHEEL_MIRROR_TMPDIR &
HTTP_SERVER_PID=$!

PACKAGES="flit_core wheel setuptools calver tomli packaging typing-extensions setuptools-scm trove-classifiers editables pathspec pluggy hatchling"

build_wheel() {
  local pkg=$1; shift

  WHEEL_BUILD_TMPDIR=$(mktemp --tmpdir=. --directory wheelbuildXXXX)
  pushd $WHEEL_BUILD_TMPDIR

  # FIXME: --no-cache-dir should be sufficient, but I don't trust it yet!
  rm -rf ~/.cache/pip

  # Note this is going to download build dependencies and build wheels, etc.
  # none of which we want happening at this stage
  # FIXME: this sdist should be downloaded in advance, outside of this script
  local sdist=$(pip download --no-binary :all: $pkg | grep Saved | cut -d ' ' -f 2-)

  pip -vvv --disable-pip-version-check wheel --index-url http://localhost:8000/simple ${sdist}

  # FIXME: this should only ever be one wheel?
  mv *.whl $WHEEL_MIRROR_TMPDIR/downloads
  update_mirror

  popd
  rm -rf $WHEEL_BUILD_TMPDIR
}

for p in $PACKAGES; do
  build_wheel $p
done