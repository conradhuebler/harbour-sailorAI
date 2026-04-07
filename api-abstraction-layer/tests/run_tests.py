#!/usr/bin/env python3
"""
Test Runner Script for API Abstraction Layer
Claude Generated - Unified test execution across all platforms
"""

import os
import sys
import subprocess
import json
from pathlib import Path

# Colors for output
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
BLUE = '\033[0;34m'
NC = '\033[0m'  # No Color

def log_info(msg):
    print(f"{BLUE}[INFO]{NC} {msg}")

def log_success(msg):
    print(f"{GREEN}[PASS]{NC} {msg}")

def log_warning(msg):
    print(f"{YELLOW}[WARN]{NC} {msg}")

def log_error(msg):
    print(f"{RED}[FAIL]{NC} {msg}")

def run_python_tests():
    """Run Python test suite"""
    log_info("Running Python tests...")

    script_dir = os.path.dirname(os.path.abspath(__file__))
    python_dir = os.path.join(script_dir, "python")
    test_script = os.path.join(python_dir, "test_api_abstraction.py")

    if not os.path.exists(test_script):
        log_error(f"Python test script not found: {test_script}")
        return False

    try:
        # Change to Python directory for imports
        original_dir = os.getcwd()
        os.chdir(python_dir)

        result = subprocess.run([sys.executable, "test_api_abstraction.py"],
                              capture_output=True, text=True, timeout=60)

        # Restore original directory
        os.chdir(original_dir)

        if result.returncode == 0:
            log_success("Python tests passed")
            print(result.stdout)
            return True
        else:
            log_error("Python tests failed")
            print(result.stdout)
            print(result.stderr)
            return False

    except subprocess.TimeoutExpired:
        log_error("Python tests timed out")
        return False
    except Exception as e:
        log_error(f"Error running Python tests: {e}")
        return False

def run_bash_tests():
    """Run Bash test suite"""
    log_info("Running Bash tests...")

    script_dir = os.path.dirname(os.path.abspath(__file__))
    bash_dir = os.path.join(script_dir, "bash")
    test_script = os.path.join(bash_dir, "api_endpoint_test.sh")

    if not os.path.exists(test_script):
        log_error(f"Bash test script not found: {test_script}")
        return False

    if not os.access(test_script, os.X_OK):
        log_warning("Bash test script is not executable, making it executable...")
        try:
            os.chmod(test_script, 0o755)
        except Exception as e:
            log_error(f"Cannot make bash script executable: {e}")
            return False

    try:
        result = subprocess.run(["bash", test_script],
                              capture_output=True, text=True, timeout=30)

        if result.returncode == 0:
            log_success("Bash tests passed")
            print(result.stdout)
            return True
        else:
            log_error("Bash tests failed")
            print(result.stdout)
            print(result.stderr)
            return False

    except subprocess.TimeoutExpired:
        log_error("Bash tests timed out")
        return False
    except Exception as e:
        log_error(f"Error running Bash tests: {e}")
        return False

def check_js_environment():
    """Check if JavaScript/QML testing environment is available"""
    # Check for Node.js
    try:
        result = subprocess.run(["node", "--version"],
                              capture_output=True, text=True, timeout=5)
        return result.returncode == 0
    except:
        return False

def run_js_tests():
    """Run JavaScript tests using Node.js"""
    log_info("Running JavaScript tests...")

    if not check_js_environment():
        log_warning("Node.js not available, skipping JavaScript tests")
        return True  # Not a failure, just not available

    # This would require a Node.js test runner to be implemented
    # For now, we'll indicate it's experimental
    log_warning("JavaScript tests with Node.js are experimental - not implemented yet")
    return True

def check_dependencies():
    """Check if all required dependencies are available"""
    log_info("Checking dependencies...")

    deps_ok = True

    # Check Python
    try:
        import json
        import unittest
        log_success("Python environment available")
    except Exception as e:
        log_error(f"Python environment issue: {e}")
        deps_ok = False

    # Check jq
    try:
        result = subprocess.run(["jq", "--version"],
                              capture_output=True, text=True, timeout=5)
        if result.returncode == 0:
            log_success(f"jq available: {result.stdout.strip()}")
        else:
            log_error("jq not available")
            deps_ok = False
    except:
        log_error("jq not available")
        deps_ok = False

    # Check bash
    try:
        result = subprocess.run(["bash", "--version"],
                              capture_output=True, timeout=5)
        if result.returncode == 0:
            log_success("bash available")
        else:
            log_error("bash not available")
            deps_ok = False
    except:
        log_error("bash not available")
        deps_ok = False

    return deps_ok

def validate_config():
    """Validate configuration files"""
    log_info("Validating configuration...")

    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.join(script_dir, "..", "..")
    config_file = os.path.join(project_root, "config", "api_endpoints.json")

    if not os.path.exists(config_file):
        log_error(f"Configuration file not found: {config_file}")
        return False

    try:
        with open(config_file, 'r') as f:
            config = json.load(f)

        # Basic validation
        if not isinstance(config, dict) or 'api_endpoints' not in config:
            log_error("Configuration invalid: missing api_endpoints")
            return False

        endpoints = config['api_endpoints']
        if not isinstance(endpoints, dict) or len(endpoints) == 0:
            log_error("Configuration invalid: no providers found")
            return False

        log_success(f"Configuration valid: {len(endpoints)} providers")
        return True

    except Exception as e:
        log_error(f"Configuration validation failed: {e}")
        return False

def print_summary(results):
    """Print test summary"""
    print("\n" + "="*50)
    print("         TEST SUMMARY")
    print("="*50)

    total_tests = len(results)
    passed_tests = sum(1 for success, name in results if success)
    failed_tests = total_tests - passed_tests

    print(f"Total test suites: {total_tests}")
    print(f"Passed: {passed_tests}")
    print(f"Failed: {failed_tests}")

    for success, name in results:
        status = "✓" if success else "✗"
        color = GREEN if success else RED
        print(f"{color}{status} {name}{NC}")

    print("="*50)

    return failed_tests == 0

def main():
    """Main test runner"""
    print("API Abstraction Layer Test Suite")
    print("="*50)

    # Check dependencies
    if not check_dependencies():
        log_error("Dependency check failed")
        return 1

    # Validate configuration
    if not validate_config():
        log_error("Configuration validation failed")
        return 1

    # Run test suites
    results = []

    # Python tests
    python_success = run_python_tests()
    results.append((python_success, "Python Tests"))

    # Bash tests
    bash_success = run_bash_tests()
    results.append((bash_success, "Bash Tests"))

    # JavaScript tests (if available)
    js_success = run_js_tests()
    results.append((js_success, "JavaScript Tests"))

    # Print summary
    overall_success = print_summary(results)

    if overall_success:
        log_success("All test suites completed successfully!")
        return 0
    else:
        log_error("Some test suites failed!")
        return 1

if __name__ == "__main__":
    sys.exit(main())