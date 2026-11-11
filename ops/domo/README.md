# Doop on domo

Self-hosted Doop (fork `ttalks-dev/doop`; branch `ttalks` = upstream + the `hardening` patches + this folder) as
Jim's review surface for web pages and designs. Internal only: reachable over the tailnet at
`https://domo.tail8e3de9.ts.net:<port>`; the app (non-root image) and Postgres 16 run under Docker Compose bound to
localhost; Tailscale serve terminates HTTPS. Every setting and secret lives in Infisical (project **Keeney
Advisory**, environment `prod`, folder `/doop`) and is rendered to `~/doop/.env` (mode 600) by `run.sh` at each
start. Evaluation and security review: `~/dev/platform/harness/docs/evaluations/doop-2026-11-10/`.

Jim runs every on-host command in his own `jim_ai` session on domo (bare commands, no `ssh host '…'`).

## 1. Infisical: the `doop` machine identity and the `/doop` folder (console, Jim)

Follow `~/dev/workspace-meta/docs/runbooks/infisical-machine-identity.md` with name `doop`, project **Keeney
Advisory**, folder `/doop` (No Access role plus an Additional Privilege: Secrets, Read, env `prod`, path `/doop`).
Put the client id and secret on domo:

```
mkdir -p ~/.config/doop && umask 077 && cat > ~/.config/doop/infisical-auth.env
INFISICAL_CLIENT_ID=<paste>
INFISICAL_CLIENT_SECRET=<paste>
^D
```

Then add these keys to `/doop` (generate the three secrets on the Mac and paste; nothing is typed into a chat):

| Key | Value |
| --- | --- |
| `BETTER_AUTH_SECRET` | `openssl rand -hex 32` |
| `SECRETS_ENCRYPTION_KEYS` | `k1:` followed by `openssl rand -base64 32` |
| `POSTGRES_PASSWORD` | `openssl rand -hex 24` |
| `BETTER_AUTH_URL` | `https://domo.tail8e3de9.ts.net:4443` (match the serve port in step 3) |
| `SIGNUP_EMAIL_DOMAINS` | `dapt.tech` |
| `ADMIN_EMAILS` | `jim.keeney@dapt.tech` |
| `REQUIRE_EMAIL_VERIFICATION` | `true` |
| `SMTP_HOST` / `SMTP_PORT` | `smtp.gmail.com` / `587` |
| `SMTP_USER` / `SMTP_PASS` / `EMAIL_FROM` | the sending Google Workspace mailbox, its app password, the same address |
| `AGENT_GUIDELINE_WRITES` | `false` (hardening patch 4) |
| `CHATGPT_CONNECT_DISABLED` | `true` |
| `RESIDENT_TASK_LIMIT` | `0` |
| `WEBHOOK_ALLOW_PRIVATE_URLS` | `false` |
| `ANTHROPIC_API_KEY` | optional, only if the built-in agent should run on a server key |

Leave `VITE_POSTHOG_KEY` and `POSTHOG_KEY` unset: no analytics leave the network. Verify from domo before
starting: `infisical export` through `run.sh` fails loudly when the folder has fewer than six keys.

## 2. Code on domo

```
mkdir -p ~/doop && cd ~/doop
git clone -b ttalks https://github.com/ttalks-dev/doop.git src
```

## 3. HTTPS on the tailnet

```
sudo tailscale serve status                                  # read first: --https overwrites silently
sudo tailscale serve --bg --https=4443 http://127.0.0.1:4400
```

If 4443 is taken, pick another port and set `BETTER_AUTH_URL` in Infisical to match.

## 4. Build and start

```
~/doop/src/ops/domo/run.sh
~/doop/src/ops/domo/run.sh logs -f doop
```

The first boot runs 52 migrations. The log must NOT say "stored unencrypted" and must show the sign-in policy with
`dapt.tech`. Then open `https://domo.tail8e3de9.ts.net:4443`, sign up as jim.keeney@dapt.tech (admin through
`ADMIN_EMAILS` once the address is verified by email), delete or claim the seeded "Welcome Canvas", leave link
sharing off, invite Dinesh by email.

## 5. Connect Claude Code (on the Mac)

Doop → Settings → Agent keys → one key per agent (for example `claude-code-mac`), invited only to the canvases it
works on. Then, on the Mac, with the key read from Infisical rather than pasted:

```
claude mcp add --transport http doop https://domo.tail8e3de9.ts.net:4443/mcp --header "Authorization: Bearer <key>"
```

## 6. Update

```
cd ~/doop/src && git pull --ff-only && ~/doop/src/ops/domo/run.sh
```

Upstream releases weekly; the `ttalks` branch is rebased onto a chosen tag on the Mac, never on domo.

## 7. Backups

`~/doop/pg` (Postgres) and `~/doop/data` (uploaded assets) are the state; canvas deletes are hard deletes.

```
~/doop/src/ops/domo/run.sh exec -T db pg_dump -U doop doop | gzip > ~/doop/backup-$(date +%F).sql.gz
```

## What the hardening branch changes (all upstreamable)

1. `doop:edited` saves refused for frames with executable content (frame self-rewrite).
2. A Content-Security-Policy meta in every frame document (no beacons, no remote code, no nested frames).
3. The image runs as uid 10001, not root.
4. `AGENT_GUIDELINE_WRITES=false`: agents cannot write style guides into the agent system prompt.

Open upstream, handled here by policy: agent keys are full-account and never expire (one key per agent, invited per
canvas, rotated); `/i/<frameId>.png` renders are public to anyone with the id (the tailnet is the boundary);
WebSocket messages are unbounded (internal only).
