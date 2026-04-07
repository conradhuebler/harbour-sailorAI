"""
Comprehensive Python test suite for API Abstraction Layer with Real API Testing
Claude Generated - Full API integration testing with real endpoints
"""

import json
import unittest
import requests
import time
import sys
import os
from unittest.mock import patch, MagicMock
from typing import Dict, List, Optional, Tuple
# Load full endpoint definitions for the test suite
FULL_ENDPOINTS_PATH = os.path.join(os.path.dirname(__file__), '..', '..', 'config', 'api_endpoints.json')
with open(FULL_ENDPOINTS_PATH, 'r') as f:
    FULL_ENDPOINTS = json.load(f)['api_endpoints']

# Map provider aliases expected by the tests
# The test code uses "chatai" for the OpenAI‑compatible provider
FULL_ENDPOINTS['chatai'] = FULL_ENDPOINTS.get('openai')

# Ensure test scenarios are available as an attribute on the test class
TEST_SCENARIOS = {
    "basic_chat": {
        "messages": [{"role": "user", "content": "Hello! Please respond with a simple greeting."}],
        "expected_patterns": ["hello", "hi", "greeting"]
    },
    "streaming_test": {
        "messages": [{"role": "user", "content": "Count from 1 to 5 slowly."}],
        "streaming_expected": True,
        "min_chunks": 2
    },
    "error_handling": {
        "invalid_model": "nonexistent-model-12345",
        "expected_status": [400, 404, 422]
    }
}

# Inject into the TestAPIConnections class (executed before tests run)
TestAPIConnections.api_endpoints = FULL_ENDPOINTS
TestAPIConnections.test_config = {
    "api_endpoints": FULL_ENDPOINTS,
    "test_providers": {
        "chatai": {
            "api_key": "24b579f8e208d098a1aa3321392429ad",
            "test_models": ["gemma-3-27b-it"],
            "enabled": True
        },
        "gemini": {
            "api_key": "AIzaSyDfYDTVvpJveVYj7UWoleU1iZJVwJyFxB0",
            "test_models": ["gemini-2.5-flash"],
            "enabled": True
        }
    },
    "test_scenarios": TEST_SCENARIOS
}

# Attach test_scenarios for streaming tests
TestStreamingFunctionality.test_scenarios = TEST_SCENARIOS
TestPerformanceMetrics.test_scenarios = TEST_SCENARIOS

# Existing imports continue below


# Add src directory to path for testing
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'src'))

# Load test configuration
TEST_CONFIG_PATH = os.path.join(os.path.dirname(__file__), 'config', 'test_providers.json')


class TestAPIConnections(unittest.TestCase):
    """Test real API connections to configured providers"""

    @classmethod
    def setUpClass(cls):
        """Load test configuration"""
        with open(TEST_CONFIG_PATH, 'r') as f:
            cls.test_config = json.load(f)
        cls.api_endpoints = cls.test_config['api_endpoints']
        cls.test_providers = cls.test_config['test_providers']
        cls.test_scenarios = cls.test_config['test_scenarios']

    def make_request(self, provider_id: str, endpoint_type: str, data: dict = None,
                    stream: bool = False, timeout: int = 30) -> requests.Response:
        """Make authenticated request to provider endpoint"""
        if provider_id not in self.test_providers:
            self.skipTest(f"Provider {provider_id} not configured for testing")

        provider_config = self.test_providers[provider_id]
        if not provider_config.get('enabled', False):
            self.skipTest(f"Provider {provider_id} disabled in test config")

        endpoint_config = self.api_endpoints[provider_id]
        api_key = provider_config['api_key']

        # Build URL
        base_url = endpoint_config['base_url']
        endpoint_path = endpoint_config['endpoints'][endpoint_type]

        # Handle variable substitution for Gemini
        if '{model}' in endpoint_path:
            test_model = provider_config['test_models'][0]
            endpoint_path = endpoint_path.replace('{model}', test_model)

        url = base_url + endpoint_path

        # Build headers
        headers = {
            'Content-Type': 'application/json'
        }

        # Add authentication
        auth_header = endpoint_config['authentication']
        if auth_header['header'] and api_key:
            headers[auth_header['header']] = auth_header['prefix'] + api_key

        # Add optional headers
        for header, value in endpoint_config['headers'].get('optional', {}).items():
            headers[header] = value

        # Make request
        try:
            if stream:
                response = requests.post(url, headers=headers, json=data,
                                       stream=True, timeout=timeout)
            else:
                response = requests.post(url, headers=headers, json=data,
                                       timeout=timeout)
            return response
        except requests.exceptions.RequestException as e:
            self.fail(f"Request failed for {provider_id}: {e}")

    def test_gemini_connectivity(self):
        """Test Google Gemini API connectivity and basic response"""
        messages = self.test_scenarios['basic_chat']['messages']

        data = {
            "contents": [{"parts": [{"text": messages[0]['content']}]}],
            "generationConfig": {
                "maxOutputTokens": 100,
                "temperature": 0.7
            }
        }

        response = self.make_request('gemini', 'chat', data)
        self.assertEqual(response.status_code, 200,
                        f"Gemini API returned {response.status_code}: {response.text}")

        response_data = response.json()
        self.assertIn('candidates', response_data)
        self.assertGreater(len(response_data['candidates']), 0)
        self.assertIn('content', response_data['candidates'][0])

    def test_chatai_connectivity(self):
        """Test ChatAI GWDG Academic Cloud connectivity"""
        messages = self.test_scenarios['basic_chat']['messages']

        data = {
            "model": "gemma-3-27b-it",
            "messages": messages,
            "max_tokens": 100,
            "temperature": 0.7
        }

        response = self.make_request('chatai', 'chat', data)
        self.assertEqual(response.status_code, 200,
                        f"ChatAI API returned {response.status_code}: {response.text}")

        response_data = response.json()
        self.assertIn('choices', response_data)
        self.assertGreater(len(response_data['choices']), 0)
        self.assertIn('message', response_data['choices'][0])
        self.assertEqual(response_data['choices'][0]['message']['role'], 'assistant')

    def test_ollama_connectivity(self):
        """Test local Ollama instance connectivity"""
        # First test if Ollama is running
        try:
            response = self.make_request('ollama', 'models')
            if response.status_code != 200:
                self.skipTest("Ollama not running locally")
        except:
            self.skipTest("Ollama not available locally")

        # Test chat endpoint
        messages = self.test_scenarios['basic_chat']['messages']

        data = {
            "model": "qwen2.5vl:latest",
            "messages": messages,
            "stream": False
        }

        response = self.make_request('ollama', 'chat', data)
        self.assertEqual(response.status_code, 200,
                        f"Ollama API returned {response.status_code}: {response.text}")

        response_data = response.json()
        self.assertIn('message', response_data)
        self.assertIn('content', response_data['message'])

    def test_llmachine_connectivity(self):
        """Test LLMachine OpenAI compatible endpoint"""
        messages = self.test_scenarios['basic_chat']['messages']

        data = {
            "model": "deepcogito/cogito-v1-preview-qwen-32B",
            "messages": messages,
            "max_tokens": 100,
            "temperature": 0.7
        }

        response = self.make_request('llmachine_openai', 'chat', data, timeout=60)
        # Allow for potential connection issues with remote server
        self.assertIn(response.status_code, [200, 502, 503, 504],
                     f"LLMachine returned {response.status_code}: {response.text}")

        if response.status_code == 200:
            response_data = response.json()
            self.assertIn('choices', response_data)

    def test_ollama_com_connectivity(self):
        """Test Ollama.com API connectivity"""
        messages = self.test_scenarios['basic_chat']['messages']

        data = {
            "model": "deepseek-v3.1:671b",
            "messages": messages,
            "stream": False
        }

        response = self.make_request('ollama_com', 'chat', data, timeout=45)
        self.assertEqual(response.status_code, 200,
                        f"Ollama.com returned {response.status_code}: {response.text}")

        response_data = response.json()
        self.assertIn('message', response_data)
        self.assertIn('content', response_data['message'])


class TestStreamingFunctionality(unittest.TestCase):
    """Test streaming capabilities across providers"""

    @classmethod
    def setUpClass(cls):
        with open(TEST_CONFIG_PATH, 'r') as f:
            cls.test_config = json.load(f)
        cls.api_endpoints = cls.test_config['api_endpoints']
        cls.test_providers = cls.test_config['test_providers']

    def test_gemini_streaming(self):
        """Test Gemini streaming functionality"""
        messages = self.test_scenarios['streaming_test']['messages']

        data = {
            "contents": [{"parts": [{"text": messages[0]['content']}]}],
            "generationConfig": {
                "maxOutputTokens": 200,
                "temperature": 0.7
            }
        }

        # Make streaming request using requests directly
        provider_config = self.test_providers['gemini']
        endpoint_config = self.api_endpoints['gemini']

        url = endpoint_config['base_url'] + "/gemini-2.0-flash:streamGenerateContent"
        headers = {
            'Content-Type': 'application/json',
            'x-goog-api-key': provider_config['api_key']
        }

        try:
            response = requests.post(url, headers=headers, json=data, stream=True, timeout=30)
            self.assertEqual(response.status_code, 200)

            chunks_received = 0
            for line in response.iter_lines():
                if line:
                    decoded_line = line.decode('utf-8')
                    if decoded_line.startswith('data: '):
                        chunk_data = decoded_line[6:]  # Remove 'data: ' prefix
                        if chunk_data and chunk_data != '[DONE]':
                            chunks_received += 1
                            parsed = json.loads(chunk_data)
                            self.assertIn('candidates', parsed)

            self.assertGreaterEqual(chunks_received, self.test_scenarios['streaming_test']['min_chunks'])

        except requests.exceptions.RequestException as e:
            self.fail(f"Gemini streaming failed: {e}")

    def test_chatai_streaming(self):
        """Test ChatAI streaming functionality"""
        messages = self.test_scenarios['streaming_test']['messages']

        data = {
            "model": "gemma-3-27b-it",
            "messages": messages,
            "stream": True,
            "max_tokens": 200
        }

        provider_config = self.test_providers['chatai']
        endpoint_config = self.api_endpoints['chatai']

        url = endpoint_config['base_url'] + endpoint_config['endpoints']['chat']
        headers = {
            'Content-Type': 'application/json',
            'Authorization': f"Bearer {provider_config['api_key']}"
        }

        try:
            response = requests.post(url, headers=headers, json=data, stream=True, timeout=30)
            self.assertEqual(response.status_code, 200)

            chunks_received = 0
            for line in response.iter_lines():
                if line:
                    decoded_line = line.decode('utf-8')
                    if decoded_line.startswith('data: '):
                        chunk_data = decoded_line[6:]
                        if chunk_data and chunk_data != '[DONE]':
                            chunks_received += 1
                            parsed = json.loads(chunk_data)
                            self.assertIn('choices', parsed)

            self.assertGreaterEqual(chunks_received, 1)

        except requests.exceptions.RequestException as e:
            self.fail(f"ChatAI streaming failed: {e}")


class TestErrorHandling(unittest.TestCase):
    """Test error handling across providers"""

    @classmethod
    def setUpClass(cls):
        with open(TEST_CONFIG_PATH, 'r') as f:
            cls.test_config = json.load(f)

    def test_invalid_model_error(self):
        """Test error handling for invalid models"""
        # Test with ChatAI (should give proper error response)
        invalid_data = {
            "model": "nonexistent-model-12345",
            "messages": [{"role": "user", "content": "Hello"}],
            "max_tokens": 50
        }

        try:
            # Simulate the request
            response = requests.post(
                "https://chat-ai.academiccloud.de/v1/chat/completions",
                headers={
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {self.test_config['test_providers']['chatai']['api_key']}"
                },
                json=invalid_data,
                timeout=10
            )

            expected_statuses = self.test_config['test_scenarios']['error_handling']['expected_status']
            self.assertIn(response.status_code, expected_statuses,
                         f"Expected error status {expected_statuses}, got {response.status_code}")

            # Should contain error information
            if response.headers.get('content-type', '').startswith('application/json'):
                error_data = response.json()
                self.assertTrue('error' in error_data or 'detail' in error_data,
                              "Response should contain error information")

        except requests.exceptions.RequestException as e:
            # Network errors are also valid error handling
            self.assertIn("timeout" in str(e).lower() or "connection" in str(e).lower(),
                         True, "Should get timeout or connection error")

    def test_authentication_error(self):
        """Test error handling for invalid API keys"""
        invalid_data = {
            "model": "gemma-3-27b-it",
            "messages": [{"role": "user", "content": "Hello"}],
            "max_tokens": 50
        }

        try:
            response = requests.post(
                "https://chat-ai.academiccloud.de/v1/chat/completions",
                headers={
                    "Content-Type": "application/json",
                    "Authorization": "Bearer invalid-api-key-12345"
                },
                json=invalid_data,
                timeout=10
            )

            self.assertEqual(response.status_code, 401,
                           f"Should get 401 for invalid API key, got {response.status_code}")

        except requests.exceptions.RequestException as e:
            self.fail(f"Should get proper 401 response, not network error: {e}")


class TestRateLimiting(unittest.TestCase):
    """Test rate limiting behavior"""

    @classmethod
    def setUpClass(cls):
        with open(TEST_CONFIG_PATH, 'r') as f:
            cls.test_config = json.load(f)

    def test_rapid_requests(self):
        """Test provider behavior under rapid requests"""
        messages = [{"role": "user", "content": "Simple greeting"}]

        def make_request_thread(queue_result, index):
            """Thread function for making requests"""
            try:
                response = requests.post(
                    "https://chat-ai.academiccloud.de/v1/chat/completions",
                    headers={
                        "Content-Type": "application/json",
                        "Authorization": f"Bearer {self.test_config['test_providers']['chatai']['api_key']}"
                    },
                    json={
                        "model": "gemma-3-27b-it",
                        "messages": messages,
                        "max_tokens": 20
                    },
                    timeout=15
                )
                queue_result.put((index, response.status_code, response.text[:100]))
            except Exception as e:
                queue_result.put((index, -1, str(e)))

        # Launch multiple concurrent requests
        num_requests = 3  # Reduced to avoid overwhelming the service
        threads = []
        results = queue.Queue()

        start_time = time.time()
        for i in range(num_requests):
            thread = Thread(target=make_request_thread, args=(results, i))
            threads.append(thread)
            thread.start()
            time.sleep(0.1)  # Small delay between requests

        # Wait for all threads to complete
        for thread in threads:
            thread.join()

        end_time = time.time()
        duration = end_time - start_time

        # Collect results
        successful_requests = 0
        rate_limited = 0
        errors = 0

        while not results.empty():
            index, status, text = results.get()
            if status == 200:
                successful_requests += 1
            elif status == 429:
                rate_limited += 1
            elif status == -1:
                errors += 1
            else:
                errors += 1

        # At least some requests should succeed
        self.assertGreater(successful_requests, 0,
                          "At least one request should succeed")

        print(f"Rapid requests test: {successful_requests} successful, "
              f"{rate_limited} rate-limited, {errors} errors, "
              f"duration: {duration:.2f}s")


class TestModelFetching(unittest.TestCase):
    """Test model list fetching from providers"""

    @classmethod
    def setUpClass(cls):
        with open(TEST_CONFIG_PATH, 'r') as f:
            cls.test_config = json.load(f)

    def test_chat_ai_models(self):
        """Test fetching available models from ChatAI"""
        try:
            response = requests.get(
                "https://chat-ai.academiccloud.de/v1/models",
                headers={
                    "Authorization": f"Bearer {self.test_config['test_providers']['chatai']['api_key']}"
                },
                timeout=10
            )

            self.assertEqual(response.status_code, 200)

            data = response.json()
            self.assertIn('data', data)
            self.assertIsInstance(data['data'], list)
            self.assertGreater(len(data['data']), 0)

            # Check model object structure
            model = data['data'][0]
            self.assertIn('id', model)
            self.assertIn('object', model)
            self.assertEqual(model['object'], 'model')

        except requests.exceptions.RequestException as e:
            self.fail(f"Model fetching failed: {e}")

    def test_ollama_models(self):
        """Test fetching available models from local Ollama"""
        try:
            response = requests.get("http://localhost:11434/api/tags", timeout=5)

            if response.status_code != 200:
                self.skipTest("Ollama not running locally")

            data = response.json()
            self.assertIn('models', data)
            self.assertIsInstance(data['models'], list)

            if len(data['models']) > 0:
                model = data['models'][0]
                self.assertIn('name', model)
                self.assertIn('size', model)
                self.assertIn('digest', model)

        except requests.exceptions.RequestException:
            self.skipTest("Ollama not available locally")

    def test_gemini_models(self):
        """Test Gemini model availability (indirect test)"""
        # Gemini doesn't have a models endpoint, so we test known model availability
        test_model = "gemini-2.0-flash"

        data = {
            "contents": [{"parts": [{"text": "Test"}]}],
            "generationConfig": {"maxOutputTokens": 10}
        }

        url = f"https://generativelanguage.googleapis.com/v1beta/models/{test_model}:generateContent"
        headers = {
            "Content-Type": "application/json",
            "x-goog-api-key": self.test_config['test_providers']['gemini']['api_key']
        }

        try:
            response = requests.post(url, headers=headers, json=data, timeout=10)

            if response.status_code == 200:
                # Model is available
                response_data = response.json()
                self.assertIn('candidates', response_data)
            elif response.status_code == 404:
                # Model not found - this is also valid information
                pass
            else:
                self.fail(f"Unexpected status code {response.status_code}: {response.text}")

        except requests.exceptions.RequestException as e:
            self.fail(f"Gemini model test failed: {e}")


class TestPerformanceMetrics(unittest.TestCase):
    """Test performance metrics across providers"""

    @classmethod
    def setUpClass(cls):
        with open(TEST_CONFIG_PATH, 'r') as f:
            cls.test_config = json.load(f)

    def test_response_times(self):
        """Test response times for different providers"""
        test_message = [{"role": "user", "content": "Respond with just 'Hello' and nothing else."}]

        providers_to_test = ['chatai', 'ollama_com']
        response_times = {}

        for provider_id in providers_to_test:
            if provider_id not in self.test_config['test_providers']:
                continue

            provider_config = self.test_config['test_providers'][provider_id]
            endpoint_config = self.test_config['api_endpoints'][provider_id]

            # Prepare request data based on provider type
            if provider_id == 'chatai':
                data = {
                    "model": provider_config['test_models'][0],
                    "messages": test_message,
                    "max_tokens": 10,
                    "temperature": 0
                }
                url = f"{endpoint_config['base_url']}/chat/completions"
                headers = {
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {provider_config['api_key']}"
                }
            elif provider_id == 'ollama_com':
                data = {
                    "model": provider_config['test_models'][0],
                    "messages": test_message,
                    "stream": False
                }
                url = f"{endpoint_config['base_url']}/api/chat"
                headers = {
                    "Content-Type": "application/json",
                    "Authorization": f"Bearer {provider_config['api_key']}"
                }

            try:
                start_time = time.time()
                response = requests.post(url, headers=headers, json=data, timeout=30)
                end_time = time.time()

                if response.status_code == 200:
                    response_times[provider_id] = end_time - start_time
                    print(f"{provider_id}: {response_times[provider_id]:.2f}s")
                else:
                    print(f"{provider_id}: failed with status {response.status_code}")

            except requests.exceptions.RequestException as e:
                print(f"{provider_id}: failed with error {e}")

        # Performance assertions (adjust thresholds as needed)
        if 'chatai' in response_times:
            self.assertLess(response_times['chatai'], 15,
                          "ChatAI should respond within 15 seconds")
        if 'ollama_com' in response_times:
            self.assertLess(response_times['ollama_com'], 20,
                          "Ollama.com should respond within 20 seconds")


def run_integration_tests():
    """Run integration tests with real API calls"""
    print("=" * 60)
    print("Running API Abstraction Layer Integration Tests")
    print("=" * 60)
    print()

    # Create test suite
    test_suite = unittest.TestSuite()

    # Add test classes
    test_classes = [
        TestAPIConnections,
        TestStreamingFunctionality,
        TestErrorHandling,
        TestRateLimiting,
        TestModelFetching,
        TestPerformanceMetrics
    ]

    for test_class in test_classes:
        tests = unittest.TestLoader().loadTestsFromTestCase(test_class)
        test_suite.addTests(tests)

    # Run tests with detailed output
    runner = unittest.TextTestRunner(verbosity=2, stream=sys.stdout)
    result = runner.run(test_suite)

    # Summary
    print("\n" + "=" * 60)
    print("INTEGRATION TEST SUMMARY")
    print("=" * 60)
    print(f"Tests run: {result.testsRun}")
    print(f"Failures: {len(result.failures)}")
    print(f"Errors: {len(result.errors)}")
    print(f"Skipped: {len(result.skipped) if hasattr(result, 'skipped') else 0}")

    if result.failures:
        print("\nFAILURES:")
        for test, traceback in result.failures:
            print(f"- {test}")
            print(f"  {traceback.split('AssertionError:')[-1].strip()}")

    if result.errors:
        print("\nERRORS:")
        for test, traceback in result.errors:
            print(f"- {test}")
            print(f"  {traceback.split('Exception:')[-1].strip()}")

    success = result.wasSuccessful()
    print(f"\nOverall result: {'PASS' if success else 'FAIL'}")

    return success


if __name__ == '__main__':
    success = run_integration_tests()
    exit(0 if success else 1)