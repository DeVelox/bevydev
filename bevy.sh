#!/bin/bash

RUNTIME="${RUNTIME:-}"

if [[ -z "$RUNTIME" ]]; then
    if command -v podman &>/dev/null; then
        RUNTIME="podman"
    elif command -v docker &>/dev/null; then
        RUNTIME="docker"
    else
        echo "Please install Podman or Docker." >&2
        exit 1
    fi
fi

if ! command -v "$RUNTIME" &>/dev/null; then
    echo "Please install Podman or Docker." >&2
    exit 1
fi

if command -v nvidia-container-runtime &> /dev/null; then
    if [[ $RUNTIME == "podman" ]]; then
        gpu=(
            --device /dev/nvidia0
            --device /dev/nvidiactl
            --device /dev/nvidia-uvm
            --device /dev/nvidia-modeset
            --device nvidia.com/gpu=all
        )
    elif [[ $RUNTIME == "docker" ]]; then
        gpu=(
            --gpus=all
        )
    fi
elif command -v nvidia-smi &> /dev/null; then
    echo "Please install NVIDIA Container Toolkit." >&2
    exit 1
fi

gpu+=(
    --device /dev/dri
    --security-opt=label=disable
)

args=(
    --userns=keep-id
    -v /etc/localtime:/etc/localtime:ro
    -v cargo-registry:/cargo/registry
    -v cargo-git:/cargo/git
    -v .:/app:z
)

display=(
    -e DISPLAY="$DISPLAY"
    -v /tmp/.X11-unix:/tmp.X11-unix:ro
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
    "$RUNTIME" run --rm "${args[@]}" bevydev-sniper bevy build --release
}

function run() {
    check_image "bevydev-fedora"
    "$RUNTIME" run --rm "${args[@]}" "${gpu[@]}" "${display[@]}" bevydev-fedora bevy run
}

function dx() {
    check_image "bevydev-fedora"
    "$RUNTIME" run --rm "${args[@]}" "${gpu[@]}" "${display[@]}" "${dioxus[@]}" bevydev-fedora dx serve --hot-patch --features "bevy/hotpatching"
}

function hx() {
    check_image "bevydev-fedora"
    "$RUNTIME" run --rm -it "${args[@]}" "${helix[@]}" bevydev-fedora hx
}

function ci() {
    check_image "bevydev-fedora"
    "$RUNTIME" run --rm -i "${args[@]}" bevydev-fedora bash <<-EOF
				cargo fmt --all -- --check
				cargo clippy --locked --workspace --all-targets --profile ci --all-features
				bevy lint --locked --workspace --all-targets --profile ci --all-features
				cargo check --config 'profile.web.inherits="dev"' --profile ci --no-default-features --features dev --target wasm32-unknown-unknown
		EOF
}

function bash() {
    check_image "$1"
    "$RUNTIME" run --rm -it "${args[@]}" "${gpu[@]}" "${display[@]}" "$1" bash
}

function new() {
    check_image "bevydev-fedora"
    "$RUNTIME" run --rm -it "${args[@]}" "${new[@]}" bevydev-fedora bevy new -t="${2}" "$1"
}

function update() {
    echo "Updating the script..."
    update_script

    echo "Updating the images..."
    update_image "bevydev-sniper"
    update_image "bevydev-fedora"
}

function update_script() {
    SCRIPT_URL="https://raw.githubusercontent.com/DeVelox/bevydev/main/bevy.sh"
    SCRIPT_PATH="$0"
    SCRIPT_TMP=$(mktemp)

    if curl -s -o "$SCRIPT_TMP" "$SCRIPT_URL"; then
        if [ -s "$SCRIPT_TMP" ]; then
            mv "$SCRIPT_TMP" "$SCRIPT_PATH"
            chmod +x "$SCRIPT_PATH"
            echo "Script updated."
        else
            echo "Script update failed." >&2
            rm -f "$SCRIPT_TMP"
            return 1
        fi
    else
        echo "Script download failed." >&2
        rm -f "$SCRIPT_TMP"
        return 1
    fi
}

function update_image() {
    if "$RUNTIME" image exists "$1"; then
        if "$RUNTIME" pull -q ghcr.io/develox/"$1"; then
            echo "$1 updated."
        else
            echo "$1 update failed." >&2
            return 1
        fi
    fi
}

function check_image() {
    if ! "$RUNTIME" image exists "$1"; then
        echo "Image doesn't exist, downloading..."
        if "$RUNTIME" pull -q ghcr.io/develox/"$1"; then
            echo "$1 downloaded."
        else
            echo "$1 download failed." >&2
            return 1
        fi
    fi
}

case "$1" in
    update)
        update
        ;;
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
    bash )
        bash "${2:-bevydev-fedora}"
        ;;
    new )
        new "$2" "${3:-2d}"
        ;;
    *)
        echo "Usage:"
        echo "  $0 [command]"
        echo ""
        echo "Commands:"
        echo "  update  updates the script and containers"
        echo "  build   builds a release for Steam Deck"
        echo "  run     runs the app with dev profile"
        echo "  dx      runs the app with hot patching"
        echo "  hx      runs the helix editor"
        echo "  ci      linting and checks"
        echo ""
        echo "Advanced:"
        echo "  bash [image]"
        echo "  new <app_name> [template_name]"
        exit 1
        ;;
esac
