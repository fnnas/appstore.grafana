# Repository Guidelines

## Project Structure & Module Organization

This repository packages upstream Grafana OSS for fnOS; it does not compile Grafana.

- `scripts/build.sh`: asset discovery, download verification, extraction, and packaging.
- `app/`: configuration template, desktop entry, and UI icons.
- `package/`: manifest, lifecycle scripts, resource declarations, translations, icons, and wizard directory.
- `.github/workflows/`: release orchestration and reusable amd64/arm64 builds.
- `tmp/` and `dist/`: ignored caches and generated packages.

## Build & Development Commands

Use Linux or WSL with Bash, curl, Python 3, dpkg-deb, GNU tar, md5sum, and sha256sum. Keep version settings in `.github/workflows/main.yml`; pass the same values locally:

```bash
export target_version="<Grafana version without v>"
export this_pack_manifest_version="<application package version>"
bash scripts/build.sh amd64
bash scripts/build.sh arm64
```

Each command produces `dist/appstore.grafana.<package-version>.<arch>.fpk` and its `.sha256` file. Use the existing tar builder; do not introduce `fnpack`, `versions.env`, or pinned asset filenames and hashes.

## Coding Style & Naming Conventions

Use UTF-8 and LF as defined in `.gitattributes`. Indent Bash and embedded Python with four spaces; JSON and YAML use two. Quote shell path variables. Preserve extensionless lifecycle filenames under `package/cmd/` and existing build placeholders.

Keep translations consistent across `zh-CN`, `en`, and `ja-JP`.

## Testing Guidelines

There is no tracked automated test suite or coverage requirement. For shell changes, run:

```bash
shellcheck scripts/build.sh package/cmd/*
for script in scripts/build.sh package/cmd/*; do
    bash -n "$script" || exit 1
done
```

Rebuild affected architectures after packaging changes. WSL supports archive checks and isolated executable checks. Installation, desktop integration, shared-directory permissions, and upgrade behavior require actual fnOS devices. Report only checks performed.

## Persistent Data & Configuration

Declare shared directories in `package/config/resource`. Keep configuration, databases, plugins, provisioning, and logs under `/var/apps/grafana/shares/grafana/`, backed by `/volX/@appshare/grafana/`. Copy templates only when absent; preserve existing data during upgrades and uninstall hooks. Keep PID files in `TRIM_PKGVAR` and retain the dedicated `grafana` user.

Synchronize port changes across the INI template, manifest, and desktop entry.

## Commit & Pull Request Guidelines

Follow the existing Chinese `feat: ...` title style, followed by overview paragraphs and per-file change bullets. Keep commit messages focused on changes; omit a separate validation section.

PRs should explain the problem, resulting behavior, and affected architectures; link relevant issues. Include screenshots when desktop presentation changes and describe available build or device results accurately.
