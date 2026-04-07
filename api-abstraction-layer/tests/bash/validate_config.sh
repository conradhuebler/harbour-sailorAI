#!/bin/bash
#
# Configuration validation script for API endpoints
# Claude Generated - Validate API endpoint configurations

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/../config"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Validate JSON schema structure
validate_json_structure() {
    local config_file="$1"
    local provider="${2:-all}"

    log_info "Validating JSON structure: $config_file"

    # Check if file exists and is valid JSON
    if [[ ! -f "$config_file" ]]; then
        log_error "Configuration file not found: $config_file"
        return 1
    fi

    if ! jq empty "$config_file" 2>/dev/null; then
        log_error "Invalid JSON in $config_file"
        return 1
    fi

    # Get list of providers or check all
    local providers
    if [[ "$provider" == "all" ]]; then
        providers=$(jq -r '.api_endpoints | keys[]' "$config_file")
    else
        providers="$provider"
    fi

    local errors=0

    for prov in $providers; do
        log_info "Validating provider: $prov"

        # Check required fields
        local required_fields=("name" "base_url" "endpoints" "authentication" "features" "defaultModels" "headers")
        for field in "${required_fields[@]}"; do
            if ! jq -e ".api_endpoints.\"$prov\".\"$field\"" "$config_file" > /dev/null; then
                log_error "Provider $prov missing required field: $field"
                errors=$((errors + 1))
            fi
        done

        # Validate endpoints structure
        local endpoint_types=("chat" "models" "streaming")
        for endpoint in "${endpoint_types[@]}"; do
            if ! jq -e ".api_endpoints.\"$prov\".endpoints.\"$endpoint\"" "$config_file" > /dev/null; then
                log_error "Provider $prov missing endpoint: $endpoint"
                errors=$((errors + 1))
            fi
        done

        # Validate authentication structure
        local auth_fields=("header" "prefix")
        for field in "${auth_fields[@]}"; do
            if ! jq -e ".api_endpoints.\"$prov\".authentication.\"$field\"" "$config_file" > /dev/null; then
                log_error "Provider $prov missing auth field: $field"
                errors=$((errors + 1))
            fi
        done

        # Validate features structure (must be booleans)
        local feature_types=("supportsStreaming" "supportsImages" "supportsThinking")
        for feature in "${feature_types[@]}"; do
            local feature_value
            feature_value=$(jq -r ".api_endpoints.\"$prov\".features.\"$feature\"" "$config_file")
            if [[ "$feature_value" != "true" && "$feature_value" != "false" ]]; then
                log_error "Provider $prov feature $feature must be boolean, got: $feature_value"
                errors=$((errors + 1))
            fi
        done

        # Validate headers structure
        if ! jq -e ".api_endpoints.\"$prov\".headers.required" "$config_file" > /dev/null; then
            log_error "Provider $prov missing headers.required field"
            errors=$((errors + 1))
        fi

        if ! jq -e ".api_endpoints.\"$prov\".headers.optional" "$config_file" > /dev/null; then
            log_error "Provider $prov missing headers.optional field"
            errors=$((errors + 1))
        fi
    done

    if [[ $errors -eq 0 ]]; then
        log_info "All validation checks passed!"
        return 0
    else
        log_error "Validation failed with $errors errors"
        return 1
    fi
}

# Test URL accessibility
test_url_accessibility() {
    local config_file="$1"
    local provider="$2"

    log_info "Testing URL accessibility for provider: $provider"

    local base_url
    base_url=$(jq -r ".api_endpoints.\"$provider\".base_url" "$config_file")

    # Extract hostname for basic connectivity test
    local hostname
    if [[ "$base_url" =~ https?://([^/]+) ]]; then
        hostname="${BASH_REMATCH[1]}"
    else
        log_error "Could not extract hostname from: $base_url"
        return 1
    fi

    log_info "Testing connection to: $hostname"

    # Basic connectivity test (no API call, just connection)
    if curl -s --connect-timeout 5 --max-time 10 "http://$hostname" > /dev/null 2>&1 \
       || curl -s --connect-timeout 5 --max-time 10 "https://$hostname" > /dev/null 2>&1; then
        log_info "✓ Connection to $hostname successful"
        return 0
    else
        log_warning "✗ Connection to $hostname failed or timed out"
        return 1
    fi
}

# Validate API key format
validate_api_keys() {
    local config_file="$1"

    log_info "Validating API key formats"

    # Check test configuration
    if [[ -f "${config_file%/*}/config/test_providers.json" ]]; then
        local test_config="${config_file%/*}/config/test_providers.json"

        local providers
        providers=$(jq -r '.test_providers | keys[]' "$test_config" 2>/dev/null || echo "")

        for prov in $providers; do
            local api_key
            api_key=$(jq -r ".test_providers.\"$prov\".api_key" "$test_config" 2>/dev/null || echo "")

            if [[ -n "$api_key" && "$api_key" != "null" && "$api_key" != "None" ]]; then
                log_info "✓ API key found for $prov: ${api_key:0:8}..."
            else
                log_warning "✗ No API key configured for $prov"
            fi
        done
    else
        log_warning "Test configuration not found"
    fi
}

# Main validation
main() {
    local config_file="${1:-$CONFIG_DIR/api_endpoints.json}"
    local provider="${2:-all}"

    log_info "Starting validation of API configuration"
    log_info "Configuration file: $config_file"
    log_info "Provider: $provider"

    # Run validations
    validate_json_structure "$config_file" "$provider"
    local json_valid=$?

    validate_api_keys "$config_file"
    local api_keys_valid=$?

    # Test URL accessibility (for specified providers)
    local url_valid=0
    if [[ "$provider" != "all" ]]; then
        test_url_accessibility "$config_file" "$provider" && url_valid=0 || url_valid=1
    fi

    # Summary
    log_info "Validation Summary:"
    log_info "JSON Structure: $([ $json_valid -eq 0 ] && echo '✓ PASS' || echo '✗ FAIL')"
    log_info "API Keys: $([ $api_keys_valid -eq 0 ] && echo '✓ PASS' || echo '✗ WARN')"
    if [[ "$provider" != "all" ]]; then
        log_info "URL Accessibility: $([ $url_valid -eq 0 ] && echo '✓ PASS' || echo '✗ WARN')"
    fi

    # Return overall result
    if [[ $json_valid -eq 0 ]]; then
        log_info "Overall validation: ✓ PASSED"
        return 0
    else
        log_error "Overall validation: ✗ FAILED"
        return 1
    fi
}

# Help
if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    cat << EOF
Configuration Validation Script

Usage: $0 [CONFIG_FILE] [PROVIDER]

Arguments:
  CONFIG_FILE  Path to configuration JSON file (default: config/api_endpoints.json)
  PROVIDER     Specific provider to validate (default: all)

Examples:
  $0                          # Validate all configurations
  $0 config/api_endpoints.json gemini  # Validate specific provider
  $0 ../custom_config.json    # Validate custom configuration
EOF
    exit 0
fi

main "$@"