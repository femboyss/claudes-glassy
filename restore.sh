#!/usr/bin/env bash
# Kurzform fuer:  bash install.sh --restore
exec bash "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/install.sh" --restore
