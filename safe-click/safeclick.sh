#!/bin/sh
printf '\033c\033]0;%s\a' SafeClick
base_path="$(dirname "$(realpath "$0")")"
"$base_path/safeclick.x86_64" "$@"
