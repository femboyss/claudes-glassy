#!/usr/bin/env bash
# claudes-glassy: Modelle von LM Studio (lokaler Server) als JSON-Liste ausgeben.
# $1 = API-Basis, Standard http://localhost:1234/v1
# Leere Ausgabe = LM Studio-Server laeuft nicht.
base="${1:-http://localhost:1234/v1}"
curl -s --max-time 2 "${base%/}/models" 2>/dev/null \
    | jq -c '[.data[]?.id | select(test("embed"; "i") | not)]' 2>/dev/null \
    | grep -v '^\[\]$'
