#!/usr/bin/env bash

function ensure_working_directory! {
  root_dir="$(git rev-parse --show-toplevel)"

  if [[ "$PWD" != "$root_dir" ]]; then
    echo "Please run the script from the root of the repo: $root_dir"
    exit
  fi
}
