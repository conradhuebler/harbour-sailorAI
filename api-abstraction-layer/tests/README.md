# API Abstraction Layer Test Suite

Comprehensive test framework for the JSON REST API abstraction layer that enables seamless switching between different LLM providers. This test suite provides cross-platform validation across Python, Bash/curl, and JavaScript/QML environments.

## 🚀 Features

- **Multi-Platform Testing**: Python, Bash/curl, JavaScript/QML, and Node.js compatibility
- **Real API Integration**: Tests against actual APIs with real API keys from configuration
- **Provider Coverage**: OpenAI, Anthropic Claude, Google Gemini, Ollama, GWDG ChatAI, LLMachine
- **Comprehensive Scenarios**: Basic functionality, streaming, error handling, performance metrics
- **Cross-Platform CI/CD**: Optimized for CI environments with detailed reporting
- **Sailfish OS Support**: QML-based testing for mobile environments

## 📁 Test Structure

```
api-abstraction-layer/tests/
├── run_tests.sh                 # Master test runner (cross-platform)
├── config/
│   └── test_providers.json      # Test configuration with API keys
├── python/
│   ├── test_api_abstraction.py  # Unit tests for configuration validation
│   └── test_api_integration.py  # Integration tests with real APIs
├── bash/
│   ├── api_integration_tests.sh # Curl-based API testing
│   └── validate_config.sh       # Configuration validation
├── js/
│   ├── api_tests_qml.js         # JavaScript/QML test framework
│   └── config/
│       └── test_providers.js    # JS configuration loader
├── qml/
│   └── ApiTestRunner.qml        # Sailfish OS test interface
└── logs/                        # Test output and reports
```

## 🛠️ Quick Start

### Prerequisites

```bash
# Required dependencies
bash >= 4.0
curl
jq
python3 or python >= 3.6
node (optional for JavaScript tests)

# Optional for Sailfish OS
qmlscene
```

### Running Tests

#### All Tests (Recommended)
```bash
# Run complete test suite locally
./run_tests.sh all local

# Run with verbose output
./run_tests.sh all local -v

# CI optimized run
./run_tests.sh all ci
```

#### Individual Test Suites
```bash
# Python unit tests only
./run_tests.sh python local

# Bash/curl integration tests
./run_tests.sh bash local

# JavaScript tests (requires Node.js)
./run_tests.sh javascript local

# QML tests (Sailfish OS)
./run_tests.sh qml sailfish
```

#### Specific Scenarios
```bash
# Integration tests with real APIs
./run_tests.sh integration local

# Performance benchmarks
./run_tests.sh performance local

# Configuration validation only
./run_tests.sh validation local
```

#### Provider-Specific Testing
```bash
# Test only Gemini API
./run_tests.sh integration local --provider gemini

# Test all providers except ChatAI
./run_tests.sh integration local --exclude chatai
```

## 🔧 Configuration

### API Keys Setup

The test suite uses API keys from your existing Alima configuration at `~/.config/alima/config.json`. However, you can override by creating a test configuration:

```bash
cp config/test_providers.json config/custom_test_config.json
# Edit the file with your API keys
./run_tests.sh integration local --config config/custom_test_config.json
```

### Test Environment Variables

```bash
export CI=true                    # CI mode (quiet, optimized)
export VERBOSE_TESTS=true         # Enable verbose logging
export TEST_TIMEOUT_FACTOR=2.0    # Multiply timeouts by factor
```

## 📊 Test Coverage

### Python Tests
- ✅ Configuration validation and JSON schema checking
- ✅ URL building with variable substitution
- ✅ Authentication header generation
- ✅ Provider feature detection
- ✅ Endpoint structure validation
- ✅ Real API connectivity testing
- ✅ Streaming functionality validation
- ✅ Error handling and edge cases
- ✅ Performance metrics and response times
- ✅ Rate limiting behavior

### Bash/curl Tests
- ✅ HTTP request/response validation
- ✅ Streaming response processing
- ✅ Authentication token testing
- ✅ Error status code handling
- ✅ Connection timeout testing
- ✅ Rate limiting validation
- ✅ Model list fetching
- ✅ Malformed request handling

### JavaScript/QML Tests
- ✅ Cross-platform compatibility
- ✅ Configuration loading and validation
- ✅ URL construction accuracy
- ✅ Authentication setup
- ✅ Feature detection logic
- ✅ Request/response handling
- ✅ Asynchronous operation testing
- ✅ Sailfish OS integration

## 🔍 Provider Support

### Currently Tested
- **Google Gemini** ✅ Full support with streaming
- **GWDG ChatAI** ✅ Academic Cloud testing
- **Ollama (Local)** ✅ Local instance testing
- **Ollama.com** ✅ Cloud service testing
- **LLMachine** ✅ OpenAI-compatible testing
- **OpenAI/Anthropic** ⚠️ Template ready (requires API keys)

### Adding New Providers

1. Add to `config/test_providers.json`:
```json
{
  "test_providers": {
    "new_provider": {
      "api_key": "your-api-key",
      "test_models": ["model-1", "model-2"],
      "enabled": true
    }
  }
}
```

2. Add provider test case to the appropriate test suite
3. Update test runner for new provider handling

## 📈 Performance Metrics

The test suite collects detailed performance metrics:

- **Response Times**: Average, min, max per provider
- **Streaming Latency**: Time to first chunk and total duration
- **Error Rates**: Success/failure ratios
- **Timeout Analysis**: Which providers timeout most often
- **Rate Limiting**: Behavior under rapid requests

Results are saved in `logs/performance_*.json` with visual reports in Markdown.

## 🐛 Debugging

### Verbose Output
```bash
./run_tests.sh all local -v 2>&1 | tee debug.log
```

### Individual Provider Testing
```bash
# Test just Gemini API
./tests/bash/api_integration_tests.sh gemini basic

# Test with custom timeout
./tests/bash/api_integration_tests.sh all streaming 10
```

### Log Analysis
```bash
# Check recent test results
tail -20 logs/run_tests.log

# API response debugging
cat logs/test.log | grep -E "(SUCCESS|ERROR)"

# Performance data
jq . logs/performance_chatai.json
```

## 🔄 CI/CD Integration

### GitHub Actions
```yaml
- name: Run API Tests
  run: |
    chmod +x tests/run_tests.sh
    ./tests/run_tests.sh integration ci --fail-fast
```

### Docker
```dockerfile
FROM python:3.9-alpine

RUN apk add --no-cache curl jq bash
COPY . /app
WORKDIR /app

RUN chmod +x tests/run_tests.sh
CMD ["./tests/run_tests.sh", "integration", "ci"]
```

### Environment Variables for CI
```bash
export CI=true
export CONTINUOUS_INTEGRATION=true
export TEST_TIMEOUT_FACTOR=3.0  # Slower CI networks
```

## 📊 Test Reports

After each run, comprehensive reports are generated:

- **Markdown Summary**: `logs/test_report_YYYYMMDD_HHMMSS.md`
- **Detailed Logs**: `logs/run_tests.log`
- **Provider-Specific**: `logs/python_*.log`, `logs/bash_*.log`
- **Performance Data**: `logs/performance_*.json`

### Sample Report

```markdown
# API Abstraction Layer Test Report
**Generated:** 2024-01-15 14:30:00
**Platform:** Linux
**Environment:** ci
**Test Type:** integration

## Test Execution Summary

### Python Tests
✓ Gemini API connectivity test
✓ ChatAI streaming functionality
✓ Error handling validation

### Bash Integration Tests
✓ HTTP 200: Gemini basic chat test (3.142s)
✓ HTTP 200: ChatAI streaming (15 chunks)
✓ HTTP 401: Invalid API key (expected error)
```

## 🚨 Troubleshooting

### Common Issues

**Timeout Errors**
```bash
# Increase timeout for slow providers
./run_tests.sh integration local -t 600

# Reduce concurrent requests
./run_tests.sh bash local --provider gemini
```

**API Key Problems**
```bash
# Validate API key format
./tests/bash/validate_config.sh

# Check specific provider
grep -A 10 "gemini" tests/config/test_providers.json
```

**Network Issues**
```bash
# Test connectivity manually
curl -I https://chat-ai.academiccloud.de/v1/models
curl -I https://generativelanguage.googleapis.com/v1beta/models
```

**Dependency Issues**
```bash
# Install missing on Ubuntu/Debian
sudo apt install curl jq python3 python3-pip nodejs npm

# Install missing on macOS
brew install curl jq python3 node
```

### Provider-Specific Known Issues

| Provider | Issue | Solution |
|----------|-------|----------|
| Ollama (Local) | Service not running | Start with `ollama serve` |
| ChatAI | Rate limiting | Add delays between requests |
| LLMachine | Remote server | Check network connectivity |
| Gemini | Model availability | Use stable models like gemini-2.0-flash |

## 🤝 Contributing

### Adding New Tests

1. Create appropriate test file in language-specific directory
2. Follow naming convention: `test_*.py`, `api_*.sh`, `*_tests.js`
3. Add to relevant test suite in `run_tests.sh`
4. Update documentation

### Test Naming Conventions

- **Python**: `test_functionality_scenario()`
- **Bash**: `test_functionality_scenario()`
- **JavaScript**: `testFunctionalityScenario()`

### Code Style

- **Bash**: Follow shellcheck recommendations
- **Python**: PEP 8 style, type hints when helpful
- **JavaScript**: Standard JS style, ES6 features when available

## 📝 License

This test framework is part of the API Abstraction Layer project, following the same licensing terms as the main project.

---

**Claude Generated** - Comprehensive testing framework for multi-provider LLM API abstraction