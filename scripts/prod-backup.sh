#!/usr/bin/env bash

set -e

current_date=$(date +%s)
project_dir=$(git rev-parse --show-toplevel)
data_dir="$project_dir/data"
dest_file="$data_dir/music_library_prod_$current_date.db"

scp music-library-prod:/data/coolify/applications/music-library/music_library_prod.db "$dest_file"
rm "$data_dir/music_library_dev.db" || true
rm "$data_dir/music_library_dev.db-shm" || true
rm "$data_dir/music_library_dev.db-wal" || true
cp "$dest_file" "$data_dir/music_library_dev.db
