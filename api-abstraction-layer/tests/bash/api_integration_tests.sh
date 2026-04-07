#!/bin/bash
#
# Comprehensive Bash/curl integration tests for API Abstraction Layer
# Claude Generated - Full provider testing with curl commands
#
# Usage: ./api_integration_tests.sh [provider|all] [test_type]
# Examples:
#   ./api_integration_tests.sh gemini basic
#   ./api_integration_tests.sh streaming
#   ./api_integration_tests.sh all all

set -euo pipefail

# Configuration files and paths
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_CONFIG="${SCRIPT_DIR}/../config/test_providers.json"
LOG_DIR="${SCRIPT_DIR}/logs"
mkdir -p "$LOG_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" | tee -a "$LOG_DIR/test.log"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1" | tee -a "$LOG_DIR/test.log"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" | tee -a "$LOG_DIR/test.log"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_DIR/test.log"
}

# Load test configuration
load_config() {
    if [[ ! -f "$TEST_CONFIG" ]]; then
        log_error "Test configuration not found: $TEST_CONFIG"
        exit 1
    fi

    # Extract API keys using jq
    GEMINI_KEY=$(jq -r '.test_providers.gemini.api_key' "$TEST_CONFIG")
    CHATAI_KEY=$(jq -r '.test_providers.chatai.api_key' "$TEST_CONFIG")
    OLLAMACOM_KEY=$(jq -r '.test_providers.ollama_com.api_key' "$TEST_CONFIG")

    log_info "Configuration loaded from $TEST_CONFIG"
}

# Generic curl wrapper with error handling
make_request() {
    local url="$1"
    local headers="$2"
    local data="$3"
    local method="${4:-POST}"
    local timeout="${5:-30}"
    local output_file="$6"
    local description="$7"

    log_info "Testing: $description"
    log_info "URL: $url"

    # Build curl command
    local curl_cmd="curl -s -w '\\nHTTP_STATUS:%{http_code}\\nTIME_TOTAL:%{time_total}s\\n' --connect-timeout 10 --max-time $timeout"

    if [[ "$method" == "GET" ]]; then
        curl_cmd="$curl_cmd -X GET '$url'"
    else
        curl_cmd="$curl_cmd -X POST '$url' -d '$data'"
    fi

    if [[ -n "$headers" ]]; then
        curl_cmd="$curl_cmd $headers"
    fi

    # Execute request
    local response
    response=$(eval "$curl_cmd" 2>> "$LOG_DIR/curl_errors.log")

    # Parse response
    local http_status
    local time_total
    local response_body

    http_status=$(echo "$response" | grep 'HTTP_STATUS:' | cut -d: -f2)
    time_total=$(echo "$response" | grep 'TIME_TOTAL:' | cut -d: -f2 | tr -d 's')
    response_body=$(echo "$response" | sed '/HTTP_STATUS:/d' | sed '/TIME_TOTAL:/d')

    # Save response to file
    if [[ -n "$output_file" ]]; then
        echo "$response_body" > "$output_file"
    fi

    # Log results
    if [[ "$http_status" =~ ^[2-3][0-9][0-9]$ ]]; then
        log_success "HTTP $http_status (${time_total}s)"
        if [[ -n "$description" ]]; then
            log_success "$description - SUCCESS"
        fi
        return 0
    else
        log_error "HTTP $http_status (${time_total}s)"
        if [[ -n "$description" ]]; then
            log_error "$description - FAILED"
        fi
        echo "Response: $(echo "$response_body" | head -c 200)..." | tee -a "$LOG_DIR/test.log"
        return 1
    fi
}

# Test Gemini API
test_gemini() {
    local test_type="${1:-basic}"

    case "$test_type" in
        "basic")
            make_request \
                "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent" \
                "-H 'Content-Type: application/json' -H 'x-goog-api-key: $GEMINI_KEY'" \
                '{"contents": [{"parts": [{"text": "Hello! Please respond with a simple greeting."}]}], "generationConfig": {"maxOutputTokens": 100}}' \
                "POST" 30 "$LOG_DIR/gemini_basic.json" \
                "Gemini basic chat test"
            ;;
        "streaming")
            log_info "Testing Gemini streaming..."
            curl -s "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:streamGenerateContent" \
                -H "Content-Type: application/json" \
                -H "x-goog-api-key: $GEMINI_KEY" \
                -d '{"contents": [{"parts": [{"text": "Count from 1 to 5"}]}], "generationConfig": {"maxOutputTokens": 100}}' \
                --no-buffer > "$LOG_DIR/gemini_streaming.txt" 2>> "$LOG_DIR/curl_errors.log"

            local chunk_count
            chunk_count=$(grep -c "^data: " "$LOG_DIR/gemini_streaming.txt" || true)
            if [[ $chunk_count -gt 1 ]]; then
                log_success "Gemini streaming - SUCCESS ($chunk_count chunks)"
            else
                log_warning "Gemini streaming - Limited response ($chunk_count chunks)"
            fi
            ;;
        "models")
            make_request \
                "https://generativelanguage.googleapis.com/v1beta/models" \
                "-H 'Content-Type: application/json' -H 'x-goog-api-key: $GEMINI_KEY'" \
                "" \
                "GET" 20 "$LOG_DIR/gemini_models.json" \
                "Gemini models list"
            ;;
        "error")
            make_request \
                "https://generativelanguage.googleapis.com/v1beta/models/invalid-model:generateContent" \
                "-H 'Content-Type: application/json' -H 'x-goog-api-key: $GEMINI_KEY'" \
                '{"contents": [{"parts": [{"text": "Hello"}]}]}' \
                "POST" 10 "$LOG_DIR/gemini_error.json" \
                "Gemini error handling (should fail)"
            ;;
    esac
}

# Test ChatAI GWDG Academic Cloud
test_chatai() {
    local test_type="${1:-basic}"

    case "$test_type" in
        "basic")
            make_request \
                "https://chat-ai.academiccloud.de/v1/chat/completions" \
                "-H 'Content-Type: application/json' -H 'Authorization: Bearer $CHATAI_KEY'" \
                '{"model": "gemma-3-27b-it", "messages": [{"role": "user", "content": "Hello! Please respond with a simple greeting."}], "max_tokens": 100, "temperature": 0.7}' \
                "POST" 30 "$LOG_DIR/chatai_basic.json" \
                "ChatAI basic chat test"
            ;;
        "streaming")
            log_info "Testing ChatAI streaming..."
            curl -s "https://chat-ai.academiccloud.de/v1/chat/completions" \
                -H "Content-Type: application/json" \
                -H "Authorization: Bearer $CHATAI_KEY" \
                -d '{"model": "gemma-3-27b-it", "messages": [{"role": "user", "content": "Count from 1 to 5"}], "stream": true, "max_tokens": 100}' \
                --no-buffer > "$LOG_DIR/chatai_streaming.txt" 2>> "$LOG_DIR/curl_errors.log"

            local chunk_count
            chunk_count=$(grep -c "^data: " "$LOG_DIR/chatai_streaming.txt" || true)
            if [[ $chunk_count -gt 1 ]]; then
                log_success "ChatAI streaming - SUCCESS ($chunk_count chunks)"
            else
                log_warning "ChatAI streaming - Limited response ($chunk_count chunks)"
            fi
            ;;
        "models")
            make_request \
                "https://chat-ai.academiccloud.de/v1/models" \
                "-H 'Content-Type: application/json' -H 'Authorization: Bearer $CHATAI_KEY'" \
                "" \
                "GET" 20 "$LOG_DIR/chatai_models.json" \
                "ChatAI models list"
            ;;
        "different_model")
            make_request \
                "https://chat-ai.academiccloud.de/v1/chat/completions" \
                "-H 'Content-Type: application/json' -H 'Authorization: Bearer $CHATAI_KEY'" \
                '{"model": "meta-llama-3.1-8b-instruct", "messages": [{"role": "user", "content": "What is 2+2?"}], "max_tokens": 50}' \
                "POST" 25 "$LOG_DIR/chatai_alternative.json" \
                "ChatAI with Llama 3.1 8B"
            ;;
    esac
}

# Test local Ollama
test_ollama() {
    local test_type="${1:-basic}"

    # Check if Ollama is running
    if ! curl -s --connect-timeout 3 "http://localhost:11434/api/tags" > /dev/null 2>&1; then
        log_warning "Ollama not running locally, skipping tests"
        return 0
    fi

    case "$test_type" in
        "basic")
            make_request \
                "http://localhost:11434/api/chat" \
                "-H 'Content-Type: application/json'" \
                '{"model": "qwen2.5vl:latest", "messages": [{"role": "user", "content": "Hello! Please respond with a simple greeting."}], "stream": false}' \
                "POST" 30 "$LOG_DIR/ollama_basic.json" \
                "Ollama basic chat test"
            ;;
        "models")
            make_request \
                "http://localhost:11434/api/tags" \
                "-H 'Content-Type: application/json'" \
                "" \
                "GET" 10 "$LOG_DIR/ollama_models.json" \
                "Ollama models list"
            ;;
        "embedding")
            make_request \
                "http://localhost:11434/api/embeddings" \
                "-H 'Content-Type: application/json'" \
                '{"model": "embeddinggemma:latest", "prompt": "Hello, world!"}' \
                "POST" 20 "$LOG_DIR/ollama_embedding.json" \
                "Ollama embedding test"
            ;;
        "streaming")
            log_info "Testing Ollama streaming..."
            curl -s "http://localhost:11434/api/chat" \
                -H "Content-Type: application/json" \
                -d '{"model": "qwen2.5vl:latest", "messages": [{"role": "user", "content": "Count from 1 to 5"}], "stream": true}' \
                --no-buffer > "$LOG_DIR/ollama_streaming.txt" 2>> "$LOG_DIR/curl_errors.log"

            local chunk_count
            chunk_count=$(wc -l < "$LOG_DIR/ollama_streaming.txt")
            if [[ $chunk_count -gt 1 ]]; then
                log_success "Ollama streaming - SUCCESS ($chunk_count chunks)"
            else
                log_warning "Ollama streaming - Limited response ($chunk_count chunks)"
            fi
            ;;
    esac
}

# Test Ollama.com
test_ollama_com() {
    local test_type="${1:-basic}"

    case "$test_type" in
        "basic")
            make_request \
                "https://ollama.com/api/chat" \
                "-H 'Content-Type: application/json' -H 'Authorization: Bearer $OLLAMACOM_KEY'" \
                '{"model": "deepseek-v3.1:671b", "messages": [{"role": "user", "content": "Hello! Please respond with a simple greeting."}], "stream": false}' \
                "POST" 45 "$LOG_DIR/ollama_com_basic.json" \
                "Ollama.com basic chat test"
            ;;
        "models")
            make_request \
                "https://ollama.com/api/tags" \
                "-H 'Content-Type: application/json' -H 'Authorization: Bearer $OLLAMACOM_KEY'" \
                "" \
                "GET" 20 "$LOG_DIR/ollama_com_models.json" \
                "Ollama.com models list"
            ;;
        "different_model")
            make_request \
                "https://ollama.com/api/chat" \
                "-H 'Content-Type: application/json' -H 'Authorization: Bearer $OLLAMACOM_KEY'" \
                '{"model": "qwen3-coder:480b", "messages": [{"role": "user", "content": "Write a simple hello world function in Python"}], "stream": false}' \
                "POST" 60 "$LOG_DIR/ollama_com_coder.json" \
                "Ollama.com with Qwen3 Coder"
            ;;
    esac
}

# Test LLMachine OpenAI Compatible
test_llmachine() {
    local test_type="${1:-basic}"

    case "$test_type" in
        "basic")
            make_request \
                "http://139.20.140.163:11434/v1/chat/completions" \
                "-H 'Content-Type: application/json'" \
                '{"model": "deepcogito/cogito-v1-preview-qwen-32B", "messages": [{"role": "user", "content": "Hello! Please respond with a simple greeting."}], "max_tokens": 100, "temperature": 0.7}' \
                "POST" 60 "$LOG_DIR/llmachine_basic.json" \
                "LLMachine OpenAI compatible test"
            ;;
        "models")
            make_request \
                "http://139.20.140.163:11434/v1/models" \
                "-H 'Content-Type: application/json'" \
                "" \
                "GET" 30 "$LOG_DIR/llmachine_models.json" \
                "LLMachine models list"
            ;;
    esac
}

# Performance tests
test_performance() {
    local provider="${1:-chatai}"
    local num_requests="${2:-3}"

    log_info "Running performance test for $provider ($num_requests requests)"

    local total_time=0
    local successful_requests=0

    for i in $(seq 1 $num_requests); do
        log_info "Performance test: Request $i/$num_requests"

        local start_time=$(date +%s.%N)

        case "$provider" in
            "chatai")
                curl -s -o /dev/null -w "%{http_code}" "https://chat-ai.academiccloud.de/v1/chat/completions" \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer $CHATAI_KEY" \
                    -d '{"model": "gemma-3-27b-it", "messages": [{"role": "user", "content": "Quick test"}], "max_tokens": 10}' \
                    --connect-timeout 10 --max-time 20 >> "$LOG_DIR/perf_$provider.log" || true
                ;;
            "gemini")
                curl -s -o /dev/null -w "%{http_code}" "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash:generateContent" \
                    -H "Content-Type: application/json" \
                    -H "x-goog-api-key: $GEMINI_KEY" \
                    -d '{"contents": [{"parts": [{"text": "Quick test"}]}], "generationConfig": {"maxOutputTokens": 10}}' \
                    --connect-timeout 10 --max-time 20 >> "$LOG_DIR/perf_$provider.log" || true
                ;;
        esac

        local end_time=$(date +%s.%N)
        local duration=$(echo "$end_time - $start_time" | bc -l || echo "0")

        if [[ $? -eq 0 ]]; then
            total_time=$(echo "$total_time + $duration" | bc -l || echo "$total_time")
            successful_requests=$((successful_requests + 1))
        fi

        sleep 1  # Small delay between requests
    done

    if [[ $successful_requests -gt 0 ]]; then
        local avg_time=$(echo "scale=3; $total_time / $successful_requests" | bc -l)
        log_info "$provider performance: $successful_requests/$num_requests successful, avg time: ${avg_time}s"
    else
        log_error "$provider performance: 0/$num_requests requests successful"
    fi
}

# Rate limiting test
test_rate_limits() {
    local provider="${1:-chatai}"
    local rapid_count="${2:-5}"

    log_info "Testing rate limiting for $provider ($rapid_count rapid requests)"

    for i in $(seq 1 $rapid_count); do
        log_info "Rapid request $i/$rapid_count"

        case "$provider" in
            "chatai")
                curl -s -o "$LOG_DIR/rate_test_$i.json" -w "%{http_code}" "https://chat-ai.academiccloud.de/v1/chat/completions" \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer $CHATAI_KEY" \
                    -d '{"model": "gemma-3-27b-it", "messages": [{"role": "user", "content": "Rate test"}], "max_tokens": 5}' \
                    --connect-timeout 5 --max-time 15 \
                    >> "$LOG_DIR/rate_results.log" || true
                ;;
        esac
    done

    # Analyze results
    local success_count
    local rate_limited_count

    success_count=$(grep -c "200$" "$LOG_DIR/rate_results.log" || echo "0")
    rate_limited_count=$(grep -c "429$" "$LOG_DIR/rate_results.log" || echo "0")

    log_info "Rate limiting results for $provider: $success_count successful, $rate_limited_count rate-limited"
}

# Error handling tests
test_error_scenarios() {
    log_info "Testing error handling scenarios"

    # Invalid API key
    make_request \
        "https://chat-ai.academiccloud.de/v1/chat/completions" \
        "-H 'Content-Type: application/json' -H 'Authorization: Bearer invalid-key-12345'" \
        '{"model": "gemma-3-27b-it", "messages": [{"role": "user", "content": "Hello"}], "max_tokens": 50}' \
        "POST" 10 "$LOG_DIR/error_invalid_key.json" \
        "Invalid API key (should fail with 401)"

    # Invalid model
    make_request \
        "https://chat-ai.academiccloud.de/v1/chat/completions" \
        "-H 'Content-Type: application/json' -H 'Authorization: Bearer $CHATAI_KEY'" \
        '{"model": "nonexistent-model-12345", "messages": [{"role": "user", "content": "Hello"}], "max_tokens": 50}' \
        "POST" 10 "$LOG_DIR/error_invalid_model.json" \
        "Invalid model (should fail with error)"

    # Malformed JSON
    make_request \
        "https://chat-ai.academiccloud.de/v1/chat/completions" \
        "-H 'Content-Type: application/json' -H 'Authorization: Bearer $CHATAI_KEY'" \
        '{"model": "gemma-3-27b-it", "messages": [{"role": "user", "content": "Hello"}], "max_tokens": 50' \
        "POST" 10 "" \
        "Malformed JSON (should fail with 400)"
}

# Main test runner
run_tests() {
    local provider="${1:-all}"
    local test_type="${2:-all}"

    # Initialize log
    echo "API Integration Test Run - $(date)" > "$LOG_DIR/test.log"

    log_info "Starting API integration tests..."
    log_info "Provider: $provider, Test type: $test_type"

    # Load configuration
    load_config

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Run tests based on provider
    if [[ "$provider" == "all" ]]; then
        # Test all available providers
        log_info "Running tests for all providers..."

        test_gemini $test_type && passed_tests=$((passed_tests + 1)) || failed_tests=$((failed_tests + 1))
        total_tests=$((total_tests + 1))

        test_chatai $test_type && passed_tests=$((passed_tests + 1)) || failed_tests=$((failed_tests + 1))
        total_tests=$((total_tests + 1))

        test_ollama $test_type && passed_tests=$((passed_tests + 1)) || failed_tests=$((failed_tests + 1))
        total_tests=$((total_tests + 1))

        test_ollama_com $test_type && passed_tests=$((passed_tests + 1)) || failed_tests=$((failed_tests + 1))
        total_tests=$((total_tests + 1))

        test_llmachine $test_type && passed_tests=$((passed_tests + 1)) || failed_tests=$((failed_tests + 1))
        total_tests=$((total_tests + 1))

    elif command -v "test_$provider" > /dev/null 2>&1; then
        # Test specific provider
        "test_$provider" "$test_type" && passed_tests=$((passed_tests + 1)) || failed_tests=$((failed_tests + 1))
        total_tests=$((total_tests + 1))

    else
        log_error "Unknown provider: $provider"
        return 1
    fi

    # Run additional tests
    if [[ "$test_type" == "all" ]]; then
        log_info "Running additional tests..."

        test_performance "chatai" 3
        test_rate_limits "chatai" 3
        test_error_scenarios
    fi

    # Print summary
    log_info "Test Summary:"
    log_info "Total tests: $total_tests"
    log_success "Passed: $passed_tests"
    log_error "Failed: $failed_tests"

    if [[ $failed_tests -eq 0 ]]; then
        log_success "All tests completed successfully!"
        return 0
    else
        log_warning "Some tests failed. Check logs in $LOG_DIR/"
        return 1
    fi
}

# Help function
show_help() {
    cat << EOF
API Integration Tests for Abstraction Layer

Usage: $0 [PROVIDER] [TEST_TYPE]

Providers:
  gemini      Test Google Gemini API
  chatai      Test GWDG Academic Cloud ChatAI
  ollama      Test local Ollama instance
  ollama_com  Test Ollama.com
  llmachine   Test LLMachine OpenAI Compatible
  all         Test all providers (default)

Test Types:
  basic       Basic functionality test (default)
  streaming   Test streaming capabilities
  models      Test model list endpoints
  error       Test error handling
  performance  Test performance metrics
  all         Run all test types

Examples:
  $0 gemini basic           # Test Gemini basic functionality
  $0 all streaming          # Test streaming for all providers
  $0 chatai                 # Test all ChatAI functionality
  $0 all all                # Run all tests (comprehensive)

EOF
}

# Main execution
main() {
    # Check dependencies
    if ! command -v curl > /dev/null 2>&1; then
        log_error "curl is required but not installed"
        exit 1
    fi

    if ! command -v jq > /dev/null 2>&1; then
        log_error "jq is required but not installed"
        exit 1
    fi

    # Parse arguments
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            run_tests "$@"
            ;;
    esac
}

# Execute main function with all arguments
main "$@"