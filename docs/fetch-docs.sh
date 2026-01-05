#!/usr/bin/env bash
#
# fetch-docs.sh - Download Claude Code documentation for local access
#
# This script fetches the official Claude Code documentation from
# https://code.claude.com/docs/llms.txt and saves all markdown files
# locally for easier access by Claude Code and other LLMs.
#

set -euo pipefail

# Configuration
LLMS_TXT_URL="https://code.claude.com/docs/llms.txt"
BASE_URL="https://code.claude.com/docs/en"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Files to skip (maintained elsewhere in the repo)
SKIP_FILES=("changelog.md")

# Colors for output (disabled if not a terminal)
if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[0;33m'
    BLUE='\033[0;34m'
    NC='\033[0m' # No Color
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    NC=''
fi

# Print usage information
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Download Claude Code documentation for local access.

This script fetches the official Claude Code documentation from the llms.txt
file and saves all markdown files locally in the docs/ folder.

OPTIONS:
    -h, --help      Show this help message and exit
    -q, --quiet     Suppress progress output
    -n, --dry-run   Show what would be downloaded without downloading

EXAMPLES:
    $(basename "$0")              # Download all documentation
    $(basename "$0") --dry-run    # Preview what will be downloaded
    $(basename "$0") --quiet      # Download silently

SOURCE:
    $LLMS_TXT_URL
EOF
}

# Logging functions (all output to stderr to avoid polluting stdout)
log_info() {
    if [[ "${QUIET:-false}" != "true" ]]; then
        echo -e "${BLUE}[INFO]${NC} $*" >&2
    fi
}

log_success() {
    if [[ "${QUIET:-false}" != "true" ]]; then
        echo -e "${GREEN}[OK]${NC} $*" >&2
    fi
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

# Check for required dependencies
check_dependencies() {
    if ! command -v curl &>/dev/null; then
        log_error "curl is required but not installed."
        exit 1
    fi
}

# Clean existing markdown files (except this script)
clean_existing_docs() {
    log_info "Cleaning existing documentation files..."

    local count=0
    for file in "$SCRIPT_DIR"/*.md; do
        if [[ -f "$file" ]]; then
            if [[ "${DRY_RUN:-false}" == "true" ]]; then
                log_info "Would remove: $(basename "$file")"
            else
                rm "$file"
            fi
            ((count++)) || true
        fi
    done

    if [[ $count -gt 0 ]]; then
        log_info "Cleaned $count existing markdown file(s)"
    fi
}

# Fetch the llms.txt file
fetch_llms_txt() {
    log_info "Fetching llms.txt from $LLMS_TXT_URL..."

    local content
    if ! content=$(curl -fsSL "$LLMS_TXT_URL" 2>&1); then
        log_error "Failed to fetch llms.txt: $content"
        exit 1
    fi

    echo "$content"
}

# Extract markdown URLs from llms.txt content
extract_urls() {
    local content="$1"
    # Extract URLs that end in .md from markdown links
    echo "$content" | grep -oE 'https://code\.claude\.com/docs/en/[^)]+\.md' || true
}

# Check if a file should be skipped
should_skip() {
    local filename="$1"
    for skip in "${SKIP_FILES[@]}"; do
        if [[ "$filename" == "$skip" ]]; then
            return 0
        fi
    done
    return 1
}

# Download a single markdown file
download_file() {
    local url="$1"
    local filename
    filename=$(basename "$url")
    local output_path="$SCRIPT_DIR/$filename"

    # Skip files that are maintained elsewhere in the repo
    if should_skip "$filename"; then
        log_info "Skipping: $filename (maintained in repo root)"
        return 2  # Special return code for skipped
    fi

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "Would download: $filename"
        return 0
    fi

    if curl -fsSL "$url" -o "$output_path" 2>/dev/null; then
        log_success "Downloaded: $filename"
        return 0
    else
        log_warn "Failed to download: $filename"
        return 1
    fi
}

# Create index.md with local relative paths
create_index() {
    local content="$1"
    local index_path="$SCRIPT_DIR/index.md"

    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "Would create: index.md"
        return 0
    fi

    log_info "Creating index.md with local paths..."

    # Transform the content:
    # 1. Add source attribution after the main heading
    # 2. Replace full URLs with relative paths
    # 3. Point changelog.md to repo root's CHANGELOG.md
    local transformed
    transformed=$(echo "$content" | sed \
        -e 's|# Claude Code Docs|# Claude Code Docs\n\n> Source: [llms.txt](https://code.claude.com/docs/llms.txt)|' \
        -e 's|https://code\.claude\.com/docs/en/changelog\.md|../CHANGELOG.md|g' \
        -e 's|https://code\.claude\.com/docs/en/||g')

    echo "$transformed" > "$index_path"
    log_success "Created: index.md"
}

# Main function
main() {
    local QUIET=false
    local DRY_RUN=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -q|--quiet)
                QUIET=true
                shift
                ;;
            -n|--dry-run)
                DRY_RUN=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                exit 1
                ;;
        esac
    done

    export QUIET DRY_RUN

    check_dependencies

    log_info "Starting Claude Code documentation fetch..."
    log_info "Target directory: $SCRIPT_DIR"

    # Clean existing docs first (clean slate approach)
    clean_existing_docs

    # Fetch llms.txt
    local llms_content
    llms_content=$(fetch_llms_txt)

    # Extract URLs
    local urls
    urls=$(extract_urls "$llms_content")

    if [[ -z "$urls" ]]; then
        log_error "No documentation URLs found in llms.txt"
        exit 1
    fi

    # Count total files
    local total
    total=$(echo "$urls" | wc -l | tr -d ' ')
    log_info "Found $total documentation files to download"

    # Download each file
    local downloaded=0
    local failed=0
    local skipped=0

    while IFS= read -r url; do
        if [[ -n "$url" ]]; then
            local result=0
            download_file "$url" || result=$?
            case $result in
                0) ((downloaded++)) || true ;;
                1) ((failed++)) || true ;;
                2) ((skipped++)) || true ;;
            esac
        fi
    done <<< "$urls"

    # Create index.md
    create_index "$llms_content"

    # Summary
    echo ""
    if [[ "${DRY_RUN:-false}" == "true" ]]; then
        log_info "Dry run complete. Would download $total files."
    else
        log_success "Documentation fetch complete!"
        log_info "Downloaded: $downloaded files"
        if [[ $skipped -gt 0 ]]; then
            log_info "Skipped: $skipped files (maintained in repo)"
        fi
        if [[ $failed -gt 0 ]]; then
            log_warn "Failed: $failed files"
        fi
        log_info "Location: $SCRIPT_DIR"
    fi
}

main "$@"
