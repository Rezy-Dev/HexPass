#!/usr/bin/env bash
set -euo pipefail

plugin_id="rezydev.hexpass"
source_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
target_dir="${XDG_CONFIG_HOME:-$HOME/.config}/omarchy/plugins/$plugin_id"

mkdir -p "$target_dir"
find "$target_dir" -mindepth 1 -maxdepth 1 -exec rm -rf {} +
cp -a "$source_dir"/. "$target_dir"/
rm -rf "$target_dir/.git"

if command -v omarchy-shell >/dev/null 2>&1; then
  omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
fi

if command -v omarchy >/dev/null 2>&1; then
  omarchy plugin enable "$plugin_id" right >/dev/null 2>&1 || true
fi

printf 'Installed %s in %s\n' "$plugin_id" "$target_dir"
printf 'Open the bar, click the key, or run: omarchy-shell shell toggle %s\n' "$plugin_id"
