ARG RUST_VERSION=nightly-2025-12-11

# Setup base image with Rust and Cargo
FROM registry.gitlab.steamos.cloud/steamrt/sniper/sdk:latest AS rustup-sniper

ARG RUST_VERSION
ENV RUST_VERSION=$RUST_VERSION \
    RUSTUP_HOME=/rustup \
    CARGO_HOME=/cargo \
    PATH=/cargo/bin:$PATH \
    CC=clang \
    CXX=clang++

RUN set -eux && \
    url="https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init" && \
    curl -sSfL "$url" -o rustup-init && \
    chmod +x rustup-init && \
    ./rustup-init -y --no-modify-path \
        --default-toolchain $RUST_VERSION && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME && \
    rm rustup-init

# Build helix because of older glibc
FROM rustup-sniper AS helix

RUN set -eux && \
    git clone https://github.com/helix-editor/helix --branch 25.07.1 && cd helix && \
    cargo install \
       --profile opt \
       --config 'build.rustflags="-C target-cpu=native"' \
       --path helix-term \
       --locked && \
    rm -rf /helix/runtime/grammars/sources

# Install latest bevy-cli and dioxus
FROM rustup-sniper AS bevy-cli

RUN set -eux && \
    cargo install just --locked && \
    cargo install dioxus-cli --locked && \
    cargo install bevy_cli --locked --git https://github.com/TheBevyFlock/bevy_cli --branch main && \
    bevy lint install main --yes

# Main image for building and running the game
FROM rustup-sniper AS bevydev-sniper

ENV HOME=/tmp

COPY --from=bevy-cli /cargo/bin/dx /cargo/bin
COPY --from=bevy-cli /cargo/bin/bevy* /cargo/bin
COPY --from=bevy-cli /cargo/bin/just /cargo/bin

RUN set -eux && \
    rustup component add rustc-codegen-cranelift && \
    rustup target add wasm32-unknown-unknown && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME

WORKDIR /app

CMD ["bevy", "build", "--release"]

# Add helix to the image for development
FROM bevydev-sniper AS bevydev-helix

COPY --from=helix /helix/runtime $HOME/.config/helix/runtime
COPY ctx/helix-config.toml $HOME/.config/helix/config.toml
COPY --from=helix /helix/target/opt/hx /cargo/bin

RUN set -eux && \
    rustup component add rust-analyzer rust-src && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME $HOME

CMD ["hx"]

# Setup a modern development image based on Fedora
FROM quay.io/fedora/fedora:latest AS rustup-fedora

ARG RUST_VERSION
ENV RUST_VERSION=$RUST_VERSION \
    RUSTUP_HOME=/rustup \
    CARGO_HOME=/cargo \
    PATH=/cargo/bin:$PATH \
    CC=clang \
    CXX=clang++

RUN set -eux && \
    dnf5 install -y --setopt=install_weak_deps=False \
    just helix clang mold \
    mesa-dri-drivers mesa-vulkan-drivers \
    mesa-libGL mesa-libEGL vulkan-loader \
    alsa-lib-devel systemd-devel openssl-devel \
    wayland-devel libX11-devel libxkbcommon-devel && \
    url="https://static.rust-lang.org/rustup/dist/x86_64-unknown-linux-gnu/rustup-init" && \
    curl -sSfL "$url" -o rustup-init && \
    chmod +x rustup-init && \
    ./rustup-init -y --no-modify-path \
        --default-toolchain $RUST_VERSION \
        -c rust-src \
        -c rust-analyzer \
        -c rustc-codegen-cranelift \
        -t wasm32-unknown-unknown && \
    chmod -R a+w $RUSTUP_HOME $CARGO_HOME && \
    dnf5 clean all && \
    rm -rf /tmp/* || true && \
    rm rustup-init

# Install latest bevy-cli and dioxus
FROM rustup-fedora AS bevy-cli-fedora

RUN set -eux && \
    cargo install dioxus-cli --locked && \
    cargo install bevy_cli --locked --git https://github.com/TheBevyFlock/bevy_cli --branch main && \
    bevy lint install main --yes

# Main image for building and running the game
FROM rustup-fedora AS bevydev-fedora

ENV HOME=/tmp

COPY --from=bevy-cli-fedora /cargo/bin/dx /cargo/bin
COPY --from=bevy-cli-fedora /cargo/bin/bevy* /cargo/bin
COPY ctx/helix-config.toml $HOME/.config/helix/config.toml

RUN mkdir -p $HOME/.config/helix && \
    chmod -R a+w $HOME

WORKDIR /app

CMD = ["hx"]

# Default to sniper image without helix
FROM bevydev-sniper
