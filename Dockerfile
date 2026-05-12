# guardrail container image
#
# A minimal Alpine image that includes bash, git, gh (GitHub CLI), and
# envsubst — enough to run the guardrail CLI inside CI without
# installing anything on the host.
#
# Usage:
#   docker run --rm -v $(pwd):/work -w /work \
#     ghcr.io/nyongesa637/guardrail:latest init
#
#   docker run --rm -v $(pwd):/work -w /work \
#     -e GH_TOKEN=$GH_TOKEN \
#     ghcr.io/nyongesa637/guardrail:latest protect

FROM alpine:3.21

# Runtime deps for the CLI:
#   bash         — CLI shell
#   git          — required by every guardrail command
#   github-cli   — required by `protect`, `signing` registration, etc.
#   gettext      — provides envsubst (cleaner template rendering)
#   openssh-client — needed for SSH-based git remotes and signing setup
#   ca-certificates / curl — for the install script fallback path
RUN apk add --no-cache \
      bash \
      git \
      github-cli \
      gettext \
      openssh-client \
      curl \
      ca-certificates

# Drop the toolkit in /opt/guardrail and link the binary.
COPY bin/        /opt/guardrail/bin/
COPY lib/        /opt/guardrail/lib/
COPY templates/  /opt/guardrail/templates/
COPY .claude/    /opt/guardrail/.claude/
COPY .cursor/    /opt/guardrail/.cursor/
COPY mcp/        /opt/guardrail/mcp/
COPY README.md CLAUDE.md AGENTS.md LICENSE NOTICE TRADEMARK.md \
     CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md CODEOWNERS \
     CHANGELOG.md install.sh \
     /opt/guardrail/
RUN ln -s /opt/guardrail/bin/guardrail /usr/local/bin/guardrail \
 && chmod +x /opt/guardrail/bin/guardrail /opt/guardrail/lib/*.sh

# Sane git defaults so that `git init` etc. in /work don't error out
# when no identity has been set yet. Real commits should come from the
# host's identity — these are intentionally placeholder values.
RUN git config --global init.defaultBranch main \
 && git config --global user.name  "guardrail container" \
 && git config --global user.email "guardrail@invalid"

WORKDIR /work
ENTRYPOINT ["guardrail"]
CMD ["help"]

# OCI labels for ghcr.io
LABEL org.opencontainers.image.title="guardrail"
LABEL org.opencontainers.image.description="Drop a vetted governance / security / CI pattern into any repo."
LABEL org.opencontainers.image.source="https://github.com/nyongesa637/guardrail"
LABEL org.opencontainers.image.licenses="AGPL-3.0"
LABEL org.opencontainers.image.documentation="https://github.com/nyongesa637/guardrail#readme"
