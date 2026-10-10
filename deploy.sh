#!/usr/bin/env bash
# One-shot deploy for the 3D flat site on GitHub Pages.
#  1. removes the saychess.me custom domain (CNAME) from manankarani.github.io
#  2. pushes this repo's main branch
#  3. enables Pages on house3d.github.io (main, /) and waits for the build
# Needs a GitHub token with "repo" scope in GITHUB_TOKEN:
#   export GITHUB_TOKEN=ghp_xxx   (never committed; only sent to api.github.com)
set -euo pipefail
OWNER=manankarani REPO=house3d.github.io USERSITE=manankarani.github.io
: "${GITHUB_TOKEN:?export GITHUB_TOKEN first (classic token, repo scope)}"
api() { curl -sS -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "$@"; }

echo "1/3 removing custom domain from $USERSITE"
sha=$(api "https://api.github.com/repos/$OWNER/$USERSITE/contents/CNAME" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("sha",""))')
if [ -n "$sha" ]; then
  api -X DELETE "https://api.github.com/repos/$OWNER/$USERSITE/contents/CNAME" \
    -d "{\"message\":\"Remove saychess.me custom domain\",\"sha\":\"$sha\"}" >/dev/null && echo "   CNAME deleted"
else echo "   no CNAME file, skipping"; fi
api -X PUT "https://api.github.com/repos/$OWNER/$USERSITE/pages" -d '{"cname":null}' >/dev/null || true

echo "2/3 pushing main"
cd "$(dirname "$0")"
git -c credential.helper= -c "http.extraHeader=Authorization: Basic $(printf 'x-access-token:%s' "$GITHUB_TOKEN" | base64 -w0)" \
  push -u origin main

echo "3/3 enabling Pages on $REPO"
code=$(api -o /dev/null -w '%{http_code}' -X POST "https://api.github.com/repos/$OWNER/$REPO/pages" \
  -d '{"source":{"branch":"main","path":"/"}}')
[ "$code" = 409 ] && echo "   already enabled" || echo "   enable -> HTTP $code"

echo "   waiting for the build..."
for i in $(seq 1 30); do
  st=$(api "https://api.github.com/repos/$OWNER/$REPO/pages/builds/latest" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("status",""))')
  [ "$st" = built ] && break; [ "$st" = errored ] && { echo "   build errored"; exit 1; }; sleep 10
done
echo "Done: https://$OWNER.github.io/$REPO/  (status: ${st:-unknown})"
