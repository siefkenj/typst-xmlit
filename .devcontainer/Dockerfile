FROM mcr.microsoft.com/devcontainers/base:bookworm

ARG TYPST_VERSION=0.15.0
# Typst test runner (https://github.com/typst-community/tytanic); 0.4.x
# targets Typst 0.15.x.
ARG TYTANIC_VERSION=0.4.0

RUN apt-get update && apt-get install -y --no-install-recommends \
        binaryen \
        fonts-dejavu-core \
        fonts-dejavu-extra \
        fontconfig \
        unzip \
        vim \
    && rm -rf /var/lib/apt/lists/*

# Make vim the default editor for git commits (e.g. `git commit` with no -m).
RUN git config --system core.editor vim

# Install the typst CLI, pinned to the compiler version in typst.toml.
# Detected via `uname -m` rather than Docker's $TARGETARCH build-arg, since
# that's only populated by BuildKit/buildx, not the legacy builder.
RUN case "$(uname -m)" in \
        x86_64) ARCH=x86_64 ;; \
        aarch64) ARCH=aarch64 ;; \
        *) echo "Unsupported architecture: $(uname -m)" >&2 && exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/typst/typst/releases/download/v${TYPST_VERSION}/typst-${ARCH}-unknown-linux-musl.tar.xz" -o /tmp/typst.tar.xz \
    && tar -xf /tmp/typst.tar.xz -C /tmp \
    && install -m 755 "/tmp/typst-${ARCH}-unknown-linux-musl/typst" /usr/local/bin/typst \
    && rm -rf /tmp/typst*

# Install tytanic (`tt`), the Typst test runner.
RUN case "$(uname -m)" in \
        x86_64) ARCH=x86_64 ;; \
        aarch64) ARCH=aarch64 ;; \
        *) echo "Unsupported architecture: $(uname -m)" >&2 && exit 1 ;; \
    esac \
    && curl -fsSL "https://github.com/typst-community/tytanic/releases/download/v${TYTANIC_VERSION}/tytanic-${ARCH}-unknown-linux-musl.tar.xz" -o /tmp/tytanic.tar.xz \
    && tar -xf /tmp/tytanic.tar.xz -C /tmp \
    && install -m 755 "/tmp/tytanic-${ARCH}-unknown-linux-musl/tt" /usr/local/bin/tt \
    && rm -rf /tmp/tytanic*
