# Our layer over the upstream image, kept out of the repo's own Dockerfile so the fork's diff
# against kgoedecke/doop stays in ops/ (rebase without conflicts). run.sh builds the upstream
# image as doop:upstream first, then compose builds this.
#
# Run as an unprivileged user: frame HTML (agent-written, untrusted) is executed by the bundled
# Chromium for screenshots, thumbnails and PDF export, and the process holds DATABASE_URL and
# SECRETS_ENCRYPTION_KEYS. Chromium keeps --no-sandbox (CHROME_NO_SANDBOX=1, upstream's) because
# the default Docker seccomp profile blocks the user namespaces its sandbox needs; a renderer
# escape then lands in this user, not root. uid 10001 owns /home/jim_ai/doop/data on domo.
ARG BASE=doop:upstream
FROM ${BASE}
USER root
RUN groupadd -r -g 10001 doop && useradd -r -u 10001 -g doop -d /app -s /usr/sbin/nologin doop \
  && mkdir -p /app/data && chown -R doop:doop /app
USER doop
