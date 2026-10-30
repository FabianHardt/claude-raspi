FROM debian:trixie-slim@sha256:62bd423aeee912639ca8ee681c2b762cb3e25137e0a92b20be455898a9f034ad

ARG USER_UID=1000
ARG USER_GID=1000

RUN apt-get update \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends \
        bash ca-certificates curl git gh jq less nodejs npm openssh-client \
        procps python3 python3-venv ripgrep tini tmux \
    && rm -rf /var/lib/apt/lists/*

# ttyd is not packaged in Debian; arm64 only, matching the Pi.
# renovate: datasource=github-releases depName=tsl0922/ttyd
ARG TTYD_VERSION=1.7.7
RUN cd /tmp \
    && base="https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}" \
    && curl -fsSLO "${base}/ttyd.aarch64" \
    && curl -fsSLO "${base}/SHA256SUMS" \
    && sha256sum -c --ignore-missing --strict SHA256SUMS \
    && install -m 755 ttyd.aarch64 /usr/local/bin/ttyd \
    && rm ttyd.aarch64 SHA256SUMS

RUN groupadd -g "${USER_GID}" claude \
    && useradd -m -u "${USER_UID}" -g claude -s /bin/bash claude \
    && mkdir -p /workspace /opt/claude-config \
    && chown claude:claude /workspace

ENV LANG=C.UTF-8 \
    DISABLE_AUTOUPDATER=1

# /home/claude is a volume at runtime, so the binary must live outside of it.
# renovate: datasource=npm depName=@anthropic-ai/claude-code
ARG CLAUDE_CODE_VERSION=2.1.312
USER claude
RUN curl -fsSL https://claude.ai/install.sh | bash -s "${CLAUDE_CODE_VERSION}"
USER root
RUN cp "$(readlink -f /home/claude/.local/bin/claude)" /usr/local/bin/claude \
    && rm -rf /home/claude/.local/share/claude /home/claude/.local/bin/claude

COPY tmux.conf /etc/tmux.conf
COPY config/ /opt/claude-config/
COPY --chmod=755 entrypoint.sh session.sh git-credential-ghtokens /usr/local/bin/

USER claude
WORKDIR /workspace
EXPOSE 7681

HEALTHCHECK --interval=60s --timeout=5s --start-period=20s \
    CMD curl -s -o /dev/null http://localhost:7681/ || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
