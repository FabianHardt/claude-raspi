FROM debian:trixie-slim

ARG USER_UID=1000
ARG USER_GID=1000

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        bash ca-certificates curl git gh jq less nodejs npm openssh-client \
        procps python3 python3-venv ripgrep tini tmux \
    && rm -rf /var/lib/apt/lists/*

# ttyd is not packaged in Debian; arm64 only, matching the Pi.
ARG TTYD_VERSION=1.7.7
ARG TTYD_SHA256=b38acadd89d1d396a0f5649aa52c539edbad07f4bc7348b27b4f4b7219dd4165
RUN curl -fsSL -o /usr/local/bin/ttyd \
        "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.aarch64" \
    && echo "${TTYD_SHA256}  /usr/local/bin/ttyd" | sha256sum -c - \
    && chmod 755 /usr/local/bin/ttyd

RUN groupadd -g "${USER_GID}" claude \
    && useradd -m -u "${USER_UID}" -g claude -s /bin/bash claude \
    && mkdir -p /workspace /opt/claude-config \
    && chown claude:claude /workspace

ENV LANG=C.UTF-8 \
    DISABLE_AUTOUPDATER=1

# /home/claude is a volume at runtime, so the binary must live outside of it.
USER claude
RUN curl -fsSL https://claude.ai/install.sh | bash
USER root
RUN cp "$(readlink -f /home/claude/.local/bin/claude)" /usr/local/bin/claude \
    && rm -rf /home/claude/.local/share/claude /home/claude/.local/bin/claude

COPY tmux.conf /etc/tmux.conf
COPY config/ /opt/claude-config/
COPY --chmod=755 entrypoint.sh session.sh /usr/local/bin/

USER claude
WORKDIR /workspace
EXPOSE 7681

HEALTHCHECK --interval=60s --timeout=5s --start-period=20s \
    CMD curl -s -o /dev/null http://localhost:7681/ || exit 1

ENTRYPOINT ["/usr/bin/tini", "--", "/usr/local/bin/entrypoint.sh"]
