
#
SYSTEM_NAME_DEFAULT="$(hostname -s 2>/dev/null || echo "default")"
SYSTEM_NAME_DEFAULT="${SYSTEM_NAME_DEFAULT,,}"
SYSTEM_NAME_DEFAULT="$(printf '%s' "$SYSTEM_NAME_DEFAULT" | sed -E 's/pavel//g; s/dolpa//g; s/[-_.]+/-/g; s/^-+|-+$//g')"
if [[ -z "$SYSTEM_NAME_DEFAULT" ]]; then
    SYSTEM_NAME_DEFAULT="default"
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

SYSTEM_CONFIG_DIR="${PROJECT_ROOT_DIR}/system"
SYSTEM_CONFIG_LOCAL_FILE="${SYSTEM_CONFIG_DIR}/system.${SYSTEM_NAME}.conf.sh"

# Load system config file
if [[ -f "$SYSTEM_CONFIG_LOCAL_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$SYSTEM_CONFIG_LOCAL_FILE"
fi

# load share Bash library
BASH_UTILS_LOADER="${SCRIPT_DIR}/../dolpa-bash-utils/bash-utils.sh"
if [[ ! -f "$BASH_UTILS_LOADER" ]]; then
    log_error "Error: dolpa-bash-utils loader not found: $BASH_UTILS_LOADER" >&2
    exit 1
fi

bar_char=$(printf "\x23")

# shellcheck source=/dev/null
source "$BASH_UTILS_LOADER"

STEAM_PATH="${HOME}/.local/share/Steam"

PROTON_DIR="$STEAM_PATH/compatibilitytools.d/"

LATEST_GEPROTON_DATA=$(curl -s "https://api.github.com/repos/GloriousEggroll/proton-ge-custom/releases/latest")

#  get latest version available in GE-Proton releases
LATEST_GEPROTON_VERSION=$(echo "$LATEST_GEPROTON_DATA" | jq -r ".tag_name")

log_info "Latest GE-Proton version: $LATEST_GEPROTON_VERSION"
log_info "Current GE-Proton for this system: ${SYSTEM_NAME} is: ${PROTON_VERSION}"

if [[ -f "${PROTON_DIR}/${LATEST_GEPROTON_VERSION}" ]]; then
    log_success "Latest GE-Proton version is already installed: ${LATEST_GEPROTON_VERSION}"
else
    log_info "Latest GE-Proton version ${LATEST_GEPROTON_VERSION} is not installed in ${PROTON_DIR}"
fi

if [[ "$PROTON_VERSION" != "$LATEST_GEPROTON_VERSION" ]]; then
    log_info "A newer GE-Proton version is available: $LATEST_GEPROTON_VERSION"
    log_info "Consider updating PROTON_VERSION in ${SYSTEM_CONFIG_LOCAL_FILE} to the latest version."
    prompt_confirm "Do you want to update PROTON: "
    if [[ $? -eq 1 ]] ; then
        exit 0
    else
        echo ""
        log_info "Downloading latest GE-Proton release information..."
        DOWNLOAD_URL=$(echo "$LATEST_GEPROTON_DATA" | jq -r '.assets[] | select(.content_type == "application/gzip" and (.name | endswith(".tar.gz"))) | .browser_download_url')
        SHA_512_SUM_URL=$(echo "$LATEST_GEPROTON_DATA" | jq -r '.assets[] | select(.name | endswith(".sha512sum")) | .browser_download_url')
        # Print the URLs for debugging purposes
        log_info "URL: ${DOWNLOAD_URL}"
        log_info "SHA-512 URL: ${SHA_512_SUM_URL}"

        log_info "Downloading latest GE-Proton SHA-512 sumcheck..."
        curl -s -L -o "/tmp/${LATEST_GEPROTON_VERSION}.sha512sum" "$SHA_512_SUM_URL"
        SHA_512_SUM=$(cat /tmp/${LATEST_GEPROTON_VERSION}.sha512sum | awk '{print $1}')

        log_info "Downloading latest GE-Proton release archive..."
        # curl -"$bar_char" -L -o "/tmp/${LATEST_GEPROTON_VERSION}.tar.gz" "$DOWNLOAD_URL"

        log_info "Verifying download integrity..."
        DOWNLOADED_SHA_512_SUM=$(sha512sum "/tmp/${LATEST_GEPROTON_VERSION}.tar.gz" | awk '{print $1}')
        log_info "Downloaded file SHA-512: ${DOWNLOADED_SHA_512_SUM}"
        log_success "Expected SHA-512: ${SHA_512_SUM}"

        if [[ "$DOWNLOADED_SHA_512_SUM" != "$SHA_512_SUM" ]]; then
            log_error "Error: Downloaded file integrity check failed! Expected SHA-512: ${SHA_512_SUM}, but got: ${DOWNLOADED_SHA_512_SUM}" >&2
            exit 1
        else
            log_success "Download integrity verified successfully."
        fi

        log_info "Installing GE-Proton archive..."
        FILE_SIZE=$(du -b /tmp/${LATEST_GEPROTON_VERSION}.tar.gz | cut -f1)

        # Calculate checkpoint frequency for 50 dots
        # (Size / 10240 bytes per record / 50 dots)
        CHECKPOINT=$(( FILE_SIZE / 10240 / 50 ))

        echo -n "Extracting: ["
        tar -xzf "/tmp/${LATEST_GEPROTON_VERSION}.tar.gz" --checkpoint=$CHECKPOINT --checkpoint-action='ttyout=*' -C "${PROTON_DIR}/"
        echo "]"

    fi
else
    log_success "You are using the latest GE-Proton version: $PROTON_VERSION"
fi