#!/usr/bin/env bash

set -euo pipefail

export LANG="en_US.UTF-8"
export OCAML_SWITCH_NAME="5.1.1"
export OPAM_MONO_PATH=$PWD/opam-mono
export TT_REPO="https://github.com/jjm-enterprises/opam-repository.git#terrateam"

if [ ! -d $HOME/.opam ]; then
  echo "Initializing opam..."
  opam init -ayn --bare
fi

if test -n "$(find $HOME/.opam -maxdepth 0 -empty)" ; then
  echo "Initializing opam..."
  opam init -ayn --bare
fi

# I always forget how to match grep
# https://unix.stackexchange.com/a/275333
if opam switch list | grep -q $OCAML_SWITCH_NAME; then
  eval $(opam env --switch=$OCAML_SWITCH_NAME)
else
  echo "Creating OPAM switch for $OCAML_SWITCH_NAME"
  opam repository set-url --set-default default $TT_REPO
  opam switch create -y $OCAML_SWITCH_NAME
  eval $(opam env --switch=$OCAML_SWITCH_NAME)
  opam repository add opam-acsl opam
  opam pin add -y containers 3.12
  opam pin add -y cryptokit 1.20
  opam pin add -y pds 6.54 --no-depexts
  opam pin add -y hll 4.3 --no-depexts
fi

if test ! -d $OPAM_MONO_PATH; then
  eval $(opam env --switch=$OCAML_SWITCH_NAME)
  mkdir -p $OPAM_MONO_PATH/{compilers,packages}
  echo 'opam-version: "2.0"' >$OPAM_MONO_PATH/repo
  opam repository add opam-mono opam-mono
  cd code &&
    hll generate \
      -n monorepo \
      --opam-dir $OPAM_MONO_PATH \
      --tag 1.0 \
      --test-deps-as-regular-deps \
      --url-override file://$PWD
  opam update opam-mono
  opam info monorepo
  opam install -j$(nproc --all) -y --deps-only --no-depexts monorepo
  pds -d && make -j$(nproc --all) release-terrat
fi

eval $(opam env --switch=$OCAML_SWITCH_NAME)

# Now you'll need to install some of the tooling on your own...
# opam install -y ocaml-lsp-server
# opam install -y utop
# opam install -y ocamlformat
# opam install -y odig
