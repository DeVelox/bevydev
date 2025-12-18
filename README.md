# BevyDev [WIP]
### Containerized Development Environment

A very opinionated, bleeding edge set of container images for app development with the [Bevy](https://bevy.org) engine.

The image used for release builds is based on Valve's [Sniper SDK](https://gitlab.steamos.cloud/steamrt/sniper/sdk) for maximum compatibility.  
For development a more modern Fedora image is used due to Sniper causing segfaults when closing the app.  

[Helix](https://helix-editor.com/) is included as the editor of choice with the Fedora image.  
Latest versions of bevy_cli, bevy_lint, and dioxus-cli are included with the image.  
Rust toolchain is `nightly-2025-12-11` with cranelift codegen and mold linker preinstalled.

The script is designed to work with podman and projects created using the [bevy_cli](https://github.com/TheBevyFlock/bevy_cli).  
It can be modified to work with docker or projects using cargo directly, but this is not officially supported.

### Usage:
The most basic and recommended way to use this is to get a release build for the Steam Deck:
```bash
curl -O https://raw.githubusercontent.com/DeVelox/bevydev/main/bevy.sh
chmod +x bevy.sh
./bevy.sh build
```

Alternatively, other commands can be used for development:
```bash
Usage:
  ./bevy.sh [command]

Commands:
  update  updates the script and containers
  build   builds a release for Steam Deck
  run     runs the app with dev profile
  dx      runs the app with hot patching
  hx      runs the helix editor
  ci      linting and checks

Advanced:
  bash [image]
  new <app_name> [template_name]
```

If you wish to build the images locally or make other modifications feel free to fork or clone:
```bash
git clone https://github.com/DeVelox/bevydev.git
cd bevydev
podman build -t bevydev-sniper . # for the sniper image
podman build --target bevydev-fedora -t bevydev-fedora .
```
