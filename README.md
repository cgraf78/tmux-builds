# tmux builds

This repository provides sixel-enabled binaries of the [tmux](https://github.com/tmux/tmux/) terminal multiplexer.

## Available Releases

All releases are available in the [releases](https://github.com/cgraf78/tmux-builds/releases) section.

Supported platforms:

- Linux x86_64
- Linux arm64
- macOS x86_64
- macOS arm64 (Apple Silicon)

> **Note:** The macOS binaries are not fully static due to system library dependencies.  
> No external dependencies beyond a standard macOS installation are required.

Two types of builds are provided:

- **Release builds:** A tag such as `v3.8-2` identifies build revision `2` of upstream tmux `3.8`. Starting with that release, `tmux -V` and the server's `#{version}` include the build revision and repository owner, as in `3.8-2+cgraf78`. Archive names use the upstream version.
- **Preview builds:** GitHub Actions artifacts built from a single upstream HEAD commit. The build log records the full commit SHA.

Each release includes `LICENSES.tar.gz` and a `SHA256SUMS` manifest for the archives.

The daily workflow checks the [latest stable release from `tmux/tmux-builds`](https://github.com/tmux/tmux-builds/releases/latest). When that version is newer than the published downstream versions, the workflow publishes revision `-1` after all four builds pass. On other days, it verifies a preview build. Pushing a `v*` tag publishes the requested stable build revision. Running the workflow manually verifies a preview build and uploads its artifacts to GitHub Actions.

## Installation

1. Go to the [releases](https://github.com/cgraf78/tmux-builds/releases) page.

2. Download the archive for your platform.  

3. Extract the archive with:

   ```bash
   tar -xzf tmux-<version>-<platform>.tar.gz
   ```

4. Move the binary to a directory in your `PATH`, e.g.:

   ```bash
   sudo mv tmux /usr/local/bin
   ```

## Local Build Instructions

### Via Docker (Linux only)

When changing dependency versions in `versions.env`, add the SHA-256 of each
new upstream archive to `scripts/source-pins.tsv`.

Set the tmux version (without the `v` prefix) via build argument or environment variable.  
To build from the latest `master` commit, set `TMUX_VERSION=preview`.

```bash
docker compose --env-file versions.env build --build-arg TMUX_VERSION=3.5a
# or
TMUX_VERSION=3.5a docker compose --env-file versions.env build
```

For a stable tmux version outside the checked-in pins, supply its verified
archive digest in `scripts/source-pins.tsv` before building locally.

Extract the binary:

```bash
docker compose create tmux-builder
docker cp tmux-builder:/artifacts ./artifacts
docker compose rm tmux-builder
```

### Via Build Scripts

You can alternatively build tmux directly on your machine using the provided [build scripts](./scripts/).  
See the build stage in the [GitHub Actions workflow](.github/workflows/create-release.yml) reference on how to use these scripts.

## Acknowledgments

The build scripts are inspired by the [build-static-tmux](https://github.com/mjakob-gh/build-static-tmux) repository by mjakob-gh.
