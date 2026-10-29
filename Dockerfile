# Dockerfile for PA1: Real-Time Process Scheduling in Rust
#
# Provides everything needed to build and run the assignment: the Rust
# toolchain, the assignment's crate dependencies (pre-fetched so `cargo
# build` doesn't need network access later), `strace` (used by
# autograder.py to verify real syscall usage), and Python for the
# autograder itself.
#
# This same image is used both by students (interactive dev shell) and by
# TAs (batch grading) -- see docker-compose.yml.
#
# File ownership on the bind-mounted /workspace is handled at run time by
# entrypoint.sh, so this works unchanged on rootful Docker (any host UID),
# rootless Docker, Podman, and Docker Desktop on Linux/macOS/Windows.

FROM rust:1.82-slim-bookworm

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
        procps \
        build-essential \
        strace \
        python3 \
        python-is-python3 \
        python3-pip \
        git \
        curl \
        ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Default user; entrypoint.sh renumbers it at run time to match whoever
# owns the bind-mounted project on the host.
RUN useradd -m -u 1000 -s /bin/bash student

# Pre-fetch exactly the dependency versions the assignment uses, by
# fetching against the assignment's own manifest (and lockfile, if
# present) rather than whatever `cargo add` considers latest.
WORKDIR /tmp/prefetch
COPY Cargo.toml Cargo.lock* ./
RUN mkdir src && echo 'fn main() {}' > src/main.rs \
    && cargo fetch \
    && cd / && rm -rf /tmp/prefetch \
    # The cache must stay writable by whatever UID the student ends up
    # with, not just by the user who populated it.
    && chmod -R a+rwX "$CARGO_HOME"

# Plain COPY + chmod (rather than COPY --chmod) so this also builds with
# Docker's legacy non-BuildKit builder. The sed strips Windows CRLF line
# endings, which git may add on checkout and which would break the script.
COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN sed -i 's/\r$//' /usr/local/bin/entrypoint.sh \
    && chmod 755 /usr/local/bin/entrypoint.sh

WORKDIR /workspace

# Deliberately no `USER` line: the entrypoint starts as root, then drops
# privileges itself when appropriate.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["/bin/bash"]
