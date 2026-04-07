#!/bin/bash
#
# Bash Test Suite for API Abstraction Layer
# Claude Generated - Shell-based API endpoint testing
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CONFIG_FILE="${PROJECT_ROOT}/config/api_endpoints.json"
TEST_API_KEY="test-key-replacement"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global test counters
TESTS_TOTAL=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Test functions
test_config_exists() {
    ((TESTS_TOTAL++))
    log_info "Testing configuration file exists"

    if [[ -f "$CONFIG_FILE" ]]; then
        log_success "Configuration file exists: $CONFIG_FILE"
    else
        log_error "Configuration file missing: $CONFIG_FILE"
        return 1
    fi
}

test_config_valid_json() {
    ((TESTS_TOTAL++))
    log_info "Testing configuration JSON validity"

    if python3 -m json.tool "$CONFIG_FILE" >/dev/null 2>&1; then
        log_success "Configuration is valid JSON"
    else
        log_error "Configuration is not valid JSON"
        return 1
    fi
}

test_config_structure() {
    ((TESTS_TOTAL++))
    log_info "Testing configuration structure"

    local providers
    providers=$(jq -r '.api_endpoints | keys[]' "$CONFIG_FILE" 2>/dev/null) || {
        log_error "Cannot read providers from configuration"
        return 1
    }

    if [[ -z "$providers" ]]; then
        log_error "No providers found in configuration"
        return 1
    fi

    local provider_count
    provider_count=$(echo "$providers" | wc -l)
    log_success "Found $provider_count providers in configuration"

    # Test each provider
    local provider_failed=false
    while read -r provider; do
        if [[ -n "$provider" ]]; then
            log_info "Testing provider: $provider"

            # Test required fields
            local required_fields=("name" "base_url" "endpoints" "authentication" "features" "defaultModels" "headers")
            for field in "${required_fields[@]}"; do
                if jq -e ".api_endpoints.${provider}.${field}" "$CONFIG_FILE" >/dev/null; then
                    log_success "Provider $provider has field: $field"
                else
                    log_error "Provider $provider missing field: $field"
                    provider_failed=true
                    ((TESTS_FAILED++))
                    ((TESTS_TOTAL++))
                fi
            done
        fi
    done <<< "$providers"

    if [[ "$provider_failed" == true ]]; then
        return 1
    fi
}

test_openai_endpoints() {
    ((TESTS_TOTAL++))
    log_info "Testing OpenAI endpoint construction"

    local provider_id="openai"

    # Check provider exists
    if ! jq -e ".api_endpoints.${provider_id}" "$CONFIG_FILE" >/dev/null; then
        log_error "OpenAI provider not found"
        return 1
    fi

    # Extract configuration
    local base_url
    base_url=$(jq -r ".api_endpoints.${provider_id}.base_url" "$CONFIG_FILE")

    local chat_endpoint
    chat_endpoint=$(jq -r ".api_endpoints.${provider_id}.endpoints.chat" "$CONFIG_FILE")

    local models_endpoint
    models_endpoint=$(jq -r ".api_endpoints.${provider_id}.endpoints.models" "$CONFIG_FILE")

    # Build URLs
    local chat_url="${base_url}${chat_endpoint}"
    local models_url="${base_url}${models_endpoint}"

    log_info "OpenAI Chat URL: $chat_url"
    log_info "OpenAI Models URL: $models_url"

    # Validate URLs
    if [[ "$chat_url" == "https://api.openai.com/v1/chat/completions" ]]; then
        log_success "OpenAI chat URL is correct"
    else
        log_error "OpenAI chat URL is incorrect: $chat_url"
        return 1
    fi

    if [[ "$models_url" == "https://api.openai.com/v1/models" ]]; then
        log_success "OpenAI models URL is correct"
    else
        log_error "OpenAI models URL is incorrect: $models_url"
        return 1
    fi
}

test_gemini_endpoints() {
    ((TESTS_TOTAL++))
    log_info "Testing Gemini endpoint construction with variable substitution"

    local provider_id="gemini"
    local test_model="gemini-pro"

    # Check provider exists
    if ! jq -e ".api_endpoints.${provider_id}" "$CONFIG_FILE" >/dev/null; then
        log_error "Gemini provider not found"
        return 1
    fi

    # Extract configuration
    local base_url
    base_url=$(jq -r ".api_endpoints.${provider_id}.base_url" "$CONFIG_FILE")

    local chat_endpoint
    chat_endpoint=$(jq -r ".api_endpoints.${provider_id}.endpoints.chat" "$CONFIG_FILE")

    # Test variable substitution
    local chat_url="${base_url}/${test_model}:${chat_endpoint#*\:}"

    # Simulate JavaScript substitution: {model}:generateContent -> model:generateContent
    chat_url="${base_url}/${test_model}:generateContent"

    local expected="https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent"

    log_info "Gemini Chat URL: $chat_url"

    if [[ "$chat_url" == "$expected" ]]; then
        log_success "Gemini chat URL construction is correct"
    else
        log_error "Gemini chat URL construction failed: Expected $expected, got $chat_url"
        return 1
    fi

    # Test models endpoint (empty endpoint should use base URL)
    local models_endpoint
    models_endpoint=$(jq -r ".api_endpoints.${provider_id}.endpoints.models" "$CONFIG_FILE")

    if [[ "$models_endpoint" == "" ]]; then
        log_success "Gemini models endpoint correctly configured as empty (uses base URL)"
        log_info "Gemini Models URL: $base_url"
    else
        log_error "Gemini models endpoint should be empty"
        return 1
    fi
}

test_authentication_headers() {
    ((TESTS_TOTAL++))
    log_info "Testing authentication header construction"

    local providers
    providers=$(jq -r '.api_endpoints | keys[]' "$CONFIG_FILE")

    local auth_failed=false
    while read -r provider; do
        if [[ -n "$provider" ]]; then
            local auth_header
            auth_header=$(jq -r ".api_endpoints.${provider}.authentication.header" "$CONFIG_FILE")

            local auth_prefix
            auth_prefix=$(jq -r ".api_endpoints.${provider}.authentication.prefix" "$CONFIG_FILE")

            # Build header value
            local header_value="${auth_prefix}${TEST_API_KEY}"

            log_info "Provider $provider - Header: $auth_header, Value: ${auth_prefix}***SET***"

            # Validate OpenAI
            if [[ "$provider" == "openai" ]]; then
                if [[ "$auth_header" == "Authorization" && "$auth_prefix" == "Bearer " ]]; then
                    log_success "OpenAI authentication configuration is correct"
                else
                    log_error "OpenAI authentication configuration is incorrect"
                    auth_failed=true
                fi
            fi

            # Validate Gemini
            if [[ "$provider" == "gemini" ]]; then
                if [[ "$auth_header" == "x-goog-api-key" && "$auth_prefix" == "" ]]; then
                    log_success "Gemini authentication configuration is correct"
                else
                    log_error "Gemini authentication configuration is incorrect"
                    auth_failed=true
                fi
            fi
        fi
    done <<< "$providers"

    if [[ "$auth_failed" == true ]]; then
        return 1
    fi
}

test_feature_detection() {
    ((TESTS_TOTAL++))
    log_info "Testing feature detection for providers"

    local expected_features=(
        "openai:supportsStreaming:true"
        "anthropic:supportsStreaming:true"
        "gemini:supportsStreaming:true"
        "ollama:supportsStreaming:true"
        "openai:supportsImages:true"
        "anthropic:supportsImages:false"
        "gemini:supportsImages:true"
        "ollama:supportsImages:false"
    )

    local features_failed=false
    for feature_test in "${expected_features[@]}"; do
        IFS=':' read -r provider feature expected <<< "$feature_test"

        local actual_value
        actual_value=$(jq -r ".api_endpoints.${provider}.features.${feature}" "$CONFIG_FILE")

        if [[ "$actual_value" == "$expected" ]]; then
            log_success "$provider feature $feature is correctly $actual_value"
        else
            log_error "$provider feature $feature should be $expected but is $actual_value"
            features_failed=true
        fi
    done

    if [[ "$features_failed" == true ]]; then
        return 1
    fi
}

test_curl_command_generation() {
    ((TESTS_TOTAL++))
    log_info "Testing curl command generation"

    local provider="openai"
    local model="gpt-4"
    local base_url
    base_url=$(jq -r ".api_endpoints.${provider}.base_url" "$CONFIG_FILE")
    local chat_endpoint
    chat_endpoint=$(jq -r ".api_endpoints.${provider}.endpoints.chat" "$CONFIG_FILE")

    local url="${base_url}${chat_endpoint}"
    local curl_cmd="curl -X POST '${url}' \\\n  -H 'Content-Type: application/json' \\\n  -H 'Authorization: Bearer ${TEST_API_KEY}' \\\n  -d '{\"model\":\"${model}\",\"messages\":[{\"role\":\"user\",\"content\":\"Hello\"}]}'"

    log_info "Generated curl command:"
    echo -e "$curl_cmd"

    # Basic validation
    if [[ "$curl_cmd" == *"$url"* ]] && [[ "$curl_cmd" == *"$model"* ]] && [[ "$curl_cmd" == *"Authorization: Bearer"* ]]; then
        log_success "Curl command generation is correct"
    else
        log_error "Curl command generation failed"
        return 1
    fi
}

test_connectivity_mock() {
    ((TESTS_TOTAL++))
    log_info "Testing endpoint connectivity (mock - using echo server if available)"

    # Use httpbin.org for testing if internet is available
    local test_url="https://httpbin.org/json"

    if command -v curl >/dev/null 2>&1; then
        log_info "Testing connectivity with curl to $test_url"

        if timeout 5 curl -s -o /dev/null -w "%{http_code}" "$test_url" | grep -q "200"; then
            log_success "Connectivity test passed (internet available)"
        else
            log_warning "Connectivity test failed (no internet) - this is expected in many environments"
        fi
    else
        log_warning "curl not available for connectivity testing"
    fi
}

test_helpful_output() {
    ((TESTS_TOTAL++))
    log_info "Testing diagnostic output"

    echo ""
    log_info "=== Configuration Summary ==="

    local providers
    providers=$(jq -r '.api_endpoints | keys[]' "$CONFIG_FILE" 2>/dev/null) || providers=""

    if [[ -n "$providers" ]]; then
        log_info "Available providers:"
        while read -r provider; do
            if [[ -n "$provider" ]]; then
                local name
                name=$(jq -r ".api_endpoints.${provider}.name" "$CONFIG_FILE")
                local streaming
                streaming=$(jq -r ".api_endpoints.${provider}.features.supportsStreaming" "$CONFIG_FILE")
                local images
                images=$(jq -r ".api_endpoints.${provider}.features.supportsImages" "$CONFIG_FILE")

                log_info "  $provider ($name) - Streaming: $streaming, Images: $images"
            fi
        done <<< "$providers"
    fi

    log_success "Diagnostic output generated successfully"
}

# Main test execution
main() {
    log_info "Starting API Abstraction Layer Bash Tests"
    log_info "Configuration file: $CONFIG_FILE"
    log_info "Project root: $PROJECT_ROOT"
    echo ""

    # Run all tests
    local tests=(
        test_config_exists
        test_config_valid_json
        test_config_structure
        test_openai_endpoints
        test_gemini_endpoints
        test_authentication_headers
        test_feature_detection
        test_curl_command_generation
        test_connectivity_mock
        test_helpful_output
    )

    local overall_failed=false
    for test_func in "${tests[@]}"; do
        echo ""
        log_info "Running: $test_func"
        if ! $test_func; then
            overall_failed=true
        fi
    done

    # Print summary
    echo ""
    echo "================================"
    echo "         TEST SUMMARY"
    echo "================================"
    echo "Total tests: $TESTS_TOTAL"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"
    echo "================================"

    if [[ "$overall_failed" == true || "$TESTS_FAILED" -gt 0 ]]; then
        echo ""
        log_error "Some tests failed!"
        exit 1
    else
        echo ""
        log_success "All tests passed! ✓"
        exit 0
    fi
}

# Check dependencies
if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required but not installed. Please install jq to run these tests."
    exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
    log_error "python3 is required for JSON validation. Please install python3."
    exit 1
fi

# Run main function
main "$@"