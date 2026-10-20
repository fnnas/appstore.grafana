#!/bin/bash
set -euo pipefail

REPO_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
GRAFANA_VERSION="${target_version:?Set target_version to the Grafana release version.}"
PACKAGE_VERSION="${this_pack_manifest_version:?Set this_pack_manifest_version to the package version.}"

ARCH="${1:?Usage: bash scripts/build.sh <amd64|arm64>}"
case "$ARCH" in
    amd64) PLATFORM=x86 ;;
    arm64) PLATFORM=arm ;;
    *) printf 'Unsupported architecture: %s (use amd64 or arm64)\n' "$ARCH" >&2; exit 1 ;;
esac

for command in curl python3 dpkg-deb tar md5sum sha256sum; do
    command -v "$command" >/dev/null || { printf 'Missing command: %s\n' "$command" >&2; exit 1; }
done

CACHE_DIR="${CACHE_DIR:-${REPO_DIR}/tmp/downloads}"
DIST_DIR="${DIST_DIR:-${REPO_DIR}/dist}"
mkdir -p "$CACHE_DIR" "$DIST_DIR"
CACHE_DIR=$(cd -- "$CACHE_DIR" && pwd)
DIST_DIR=$(cd -- "$DIST_DIR" && pwd)

download() {
    local url="$1" destination="$2"
    if [[ ! -f "$destination" ]]; then
        curl --fail --location --retry 3 --connect-timeout 30 \
            --output "${destination}.part" "$url"
        mv "${destination}.part" "$destination"
    fi
}

ASSET_DETAILS=$(curl --fail --silent --show-error --location --retry 3 --connect-timeout 30 \
    "https://github.com/grafana/grafana/releases/expanded_assets/v${GRAFANA_VERSION}" | python3 -c '
import re, sys
from html.parser import HTMLParser
from urllib.parse import unquote, urljoin, urlparse

arch = sys.argv[1]

class ReleaseAssets(HTMLParser):
    def __init__(self):
        super().__init__()
        self.assets = {}
        self.current = None

    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if tag == "a":
            self.current = None
            url = urljoin("https://github.com", attrs.get("href", ""))
            path = urlparse(url).path
            name = unquote(path.rsplit("/", 1)[-1])
            if (path.startswith("/grafana/grafana/releases/download/")
                    and name.startswith("grafana_") and name.endswith(f"_{arch}.deb")):
                self.current = name
                self.assets[name] = {"url": url}
        elif tag == "clipboard-copy" and self.current:
            self.assets[self.current]["digest"] = attrs.get("value", "")

parser = ReleaseAssets()
parser.feed(sys.stdin.read())
if len(parser.assets) != 1:
    sys.exit(f"Expected one Grafana OSS Debian asset for {arch}, found {len(parser.assets)}")
name, asset = next(iter(parser.assets.items()))
digest = asset.get("digest", "")
if not re.fullmatch(r"sha256:[0-9a-fA-F]{64}", digest):
    sys.exit("The selected release asset does not provide a SHA256 digest")
print(name)
print(asset["url"])
print(digest.removeprefix("sha256:"))
' "$ARCH")
mapfile -t ASSET_FIELDS <<< "$ASSET_DETAILS"
DEB_NAME="${ASSET_FIELDS[0]}"
DEB_URL="${ASSET_FIELDS[1]}"
EXPECTED_SHA256="${ASSET_FIELDS[2]}"
DEB_FILE="${CACHE_DIR}/${DEB_NAME}"
download "$DEB_URL" "$DEB_FILE"
printf '%s  %s\n' "$EXPECTED_SHA256" "$DEB_FILE" | sha256sum --check
[[ "$(dpkg-deb --field "$DEB_FILE" Architecture)" == "$ARCH" ]]
[[ "$(dpkg-deb --field "$DEB_FILE" Version)" == "$GRAFANA_VERSION" ]]

BUILD_DIR=$(mktemp -d "${TMPDIR:-/tmp}/grafana-build.XXXXXXXX")
trap 'rm -rf -- "$BUILD_DIR"' EXIT
STAGE_DIR="${BUILD_DIR}/package"
mkdir -p "$STAGE_DIR/app"
dpkg-deb --extract "$DEB_FILE" "${BUILD_DIR}/upstream"
cp -a "${REPO_DIR}/package/." "$STAGE_DIR/"
cp -a "${REPO_DIR}/app/." "$STAGE_DIR/app/"
# Windows/WSL mounts may report every source file as executable.
find "$STAGE_DIR" -type d -exec chmod 755 {} +
find "$STAGE_DIR" -type f -exec chmod 644 {} +
cp -a "${BUILD_DIR}/upstream/usr/share/grafana" "$STAGE_DIR/app/grafana"

# Keep the full distribution: executable, frontend, built-in plugins and licenses.
for required in bin/grafana conf/defaults.ini public/views/index.html LICENSE; do
    [[ -f "${STAGE_DIR}/app/grafana/${required}" ]] || {
        printf 'Missing upstream runtime file: %s\n' "$required" >&2
        exit 1
    }
done
[[ -d "${STAGE_DIR}/app/grafana/public/build" ]]
sed -i \
    -e "s/@PACKAGE_VERSION@/${PACKAGE_VERSION}/g" \
    -e "s/@PLATFORM@/${PLATFORM}/g" \
    "$STAGE_DIR/manifest"
sed -i "s/@GRAFANA_VERSION@/${GRAFANA_VERSION}/g" "$STAGE_DIR"/i18n/*
chmod 755 "$STAGE_DIR"/cmd/* "$STAGE_DIR/app/grafana/bin/"*

# app.tgz is extracted directly into TRIM_APPDEST by fnOS.
tar --sort=name --owner=0 --group=0 --numeric-owner \
    -czf "$STAGE_DIR/app.tgz" -C "$STAGE_DIR/app" .
APP_CHECKSUM=$(md5sum "$STAGE_DIR/app.tgz")
printf 'checksum=%s\n' "${APP_CHECKSUM%% *}" >> "$STAGE_DIR/manifest"

# Put metadata at the archive root, alongside the nested runtime archive.
OUTPUT_NAME="appstore.grafana.${PACKAGE_VERSION}.${ARCH}.fpk"
tar --sort=name --owner=0 --group=0 --numeric-owner \
    -czf "${BUILD_DIR}/${OUTPUT_NAME}" -C "$STAGE_DIR" \
    app.tgz cmd config ICON.PNG ICON_256.PNG manifest wizard i18n
mv "${BUILD_DIR}/${OUTPUT_NAME}" "${DIST_DIR}/${OUTPUT_NAME}"
cd "$DIST_DIR"
sha256sum "$OUTPUT_NAME" > "${OUTPUT_NAME}.sha256"
printf 'Built %s/%s\n' "$DIST_DIR" "$OUTPUT_NAME"
