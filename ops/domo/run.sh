#!/usr/bin/env bash
# Start or update Doop on domo. Renders ~/doop/.env from Infisical (project Keeney Advisory, env prod,
# folder /doop) with the `doop` machine identity, then runs docker compose. Run as jim_ai:
#   ~/doop/src/ops/domo/run.sh            # up -d --build
#   ~/doop/src/ops/domo/run.sh down       # any other compose verb is passed through
# Secrets never appear on the command line or in the log; ~/doop/.env is mode 600 and regenerated each run.
set -euo pipefail
home=/home/jim_ai/doop
creds="$HOME/.config/doop/infisical-auth.env"   # INFISICAL_CLIENT_ID=... / INFISICAL_CLIENT_SECRET=... (mode 600)
project=f048e8bc-c4f5-4335-960f-c9ff603cafd4     # Keeney Advisory
[ -f "$creds" ] || { echo "run.sh: no $creds (create the doop machine identity first; see README)" >&2; exit 2; }
command -v infisical >/dev/null || export PATH="$HOME/.npm-global/bin:$PATH"
command -v infisical >/dev/null || { echo "run.sh: infisical CLI not on PATH" >&2; exit 2; }
id=''; secret=''
while IFS='=' read -r k v; do case "$k" in INFISICAL_CLIENT_ID) id="$v";; INFISICAL_CLIENT_SECRET) secret="$v";; esac; done < "$creds"
token="$(INFISICAL_UNIVERSAL_AUTH_CLIENT_ID="$id" INFISICAL_UNIVERSAL_AUTH_CLIENT_SECRET="$secret" \
  infisical login --method=universal-auth --plain --silent 2>/dev/null)" || { echo "run.sh: Infisical login failed" >&2; exit 2; }
mkdir -p "$home/data" "$home/pg"
umask 077
INFISICAL_TOKEN="$token" infisical export --projectId="$project" --env=prod --path=/doop --format=dotenv > "$home/.env.new"
n=$(grep -c '^[A-Z_]\+=' "$home/.env.new" || true)
[ "$n" -ge 6 ] || { rm -f "$home/.env.new"; echo "run.sh: only $n keys in /doop; expected BETTER_AUTH_SECRET, SECRETS_ENCRYPTION_KEYS, POSTGRES_PASSWORD, BETTER_AUTH_URL, SMTP_*, …" >&2; exit 2; }
mv "$home/.env.new" "$home/.env"
# compose substitutes ${POSTGRES_PASSWORD} from the environment, not from env_file
set -a; . "$home/.env"; set +a
cd "$home/src"
if [ $# -eq 0 ]; then
  exec docker compose -f ops/domo/docker-compose.yml up -d --build
else
  exec docker compose -f ops/domo/docker-compose.yml "$@"
fi
