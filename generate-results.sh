#!/usr/bin/env bash
set -euo pipefail
command -v pict >/dev/null || { echo 'ERROR: pict not installed'; exit 1; }
mkdir -p results
(git -C "$HOME/tools/pict" log -1 --format='pict commit %h %ad' --date=short; pict 2>&1 | head -3) > results/pict-build.txt || true
pict browser.model > results/browser-2way.txt
pict browser.model /o:3 > results/browser-3way.txt
pict transfer-nc.model > results/transfer-nc.txt
pict transfer.model > results/transfer.txt
pict transfer-neg.model > results/transfer-neg.txt
for name in browser-2way browser-3way transfer-nc transfer transfer-neg; do
  count=$(tail -n +2 "results/$name.txt" | wc -l)
  echo "$name: $count tests"
done
