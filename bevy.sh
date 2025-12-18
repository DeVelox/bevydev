#!/bin/bash

args=(
    --userns=keep-id
    -v /etc/localtime:/etc/localtime:ro
    -v cargo-registry:/cargo/registry
    -v cargo-git:/cargo/git
    -v .:/app:z
)

if command -v nvidia-container-runtime &> /dev/null; then
    args+=(
        --device nvidia.com/gpu=all
    )
elif command -v nvidia-smi &> /dev/null; then
    echo "Please install NVIDIA Container Toolkit."
    exit 1
else
    args+=(
        --device /dev/dri:/dev/dri
    )
fi

wayland=(
    -v /dev:/dev:rslave
    --security-opt=label=disable
    --security-opt=apparmor=unconfined
    -e WAYLAND_DISPLAY="$WAYLAND_DISPLAY"
    -e XDG_RUNTIME_DIR="$XDG_RUNTIME_DIR"
    -v "$XDG_RUNTIME_DIR":"$XDG_RUNTIME_DIR":ro
)

helix=(
    -e COLORTERM="$COLORTERM"
)

dioxus=(
    -e BEVY_ASSET_ROOT="."
)

new=(
    -e USER="$USER"
)

function build() {
    check_image "bevydev-sniper"
    podman run --rm "${args[@]}" bevydev-sniper bevy build --release
}

function run() {
    check_image "bevydev-fedora"
    podman run --rm "${args[@]}" "${wayland[@]}" bevydev-fedora bevy run
}

function dx() {
    check_image "bevydev-fedora"
    podman run --rm "${args[@]}" "${wayland[@]}" "${dioxus[@]}" bevydev-fedora dx serve --hot-patch --features "bevy/hotpatching"
}

function hx() {
    check_image "bevydev-fedora"
    podman run --rm -it "${args[@]}" "${helix[@]}" bevydev-fedora hx
}

function ci() {
    check_image "bevydev-fedora"
    podman run --rm -i "${args[@]}" bevydev-fedora bash <<-EOF
				cargo fmt --all -- --check
				cargo clippy --locked --workspace --all-targets --profile ci --all-features
				bevy lint --locked --workspace --all-targets --profile ci --all-features
				cargo check --config 'profile.web.inherits="dev"' --profile ci --no-default-features --features dev --target wasm32-unknown-unknown
		EOF
}

function check_image() {
    if ! podman image exists "$1"; then
        podman pull ghcr.io/develox/"$1"
    fi
}

# for testing only
function new {
    check_image "bevydev-fedora"
    podman run --rm -it "${args[@]}" "${new[@]}" bevydev-fedora bevy new -t=2d bevy_app
}

case "$1" in
    build)
        build
        ;;
    run)
        run
        ;;
    dx)
        dx
        ;;
    hx)
        hx
        ;;
    ci)
        ci
        ;;
    new )
        new
        ;;
    *)
        echo "Usage: $0 {build|run|dx|hx|ci}"
        exit 1
        ;;
esac
