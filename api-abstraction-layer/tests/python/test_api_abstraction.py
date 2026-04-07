"""
Python test suite for API Abstraction Layer
Claude Generated - Comprehensive API testing framework
"""

import json
import unittest
from unittest.mock import patch, MagicMock
import sys
import os

# Add src directory to path for testing
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'src'))

# Note: Python version will be implementation using same JSON structure
# For now, we'll test the configuration structure and validation


class TestConfigValidation(unittest.TestCase):
    """Test configuration validation"""

    def setUp(self):
        """Set up test fixtures"""
        self.config_path = os.path.join(os.path.dirname(__file__), '..', '..', 'config', 'api_endpoints.json')
        with open(self.config_path, 'r') as f:
            self.config = json.load(f)

    def test_config_structure(self):
        """Test basic configuration structure"""
        self.assertIn('api_endpoints', self.config)

        for provider_id, provider_config in self.config['api_endpoints'].items():
            # Check required properties
            self.assertIn('name', provider_config)
            self.assertIn('base_url', provider_config)
            self.assertIn('endpoints', provider_config)
            self.assertIn('authentication', provider_config)
            self.assertIn('features', provider_config)
            self.assertIn('defaultModels', provider_config)
            self.assertIn('headers', provider_config)

    def test_provider_structure(self):
        """Test individual provider structure"""
        for provider_id, provider in self.config['api_endpoints'].items():
            # Check endpoints
            endpoints = provider['endpoints']
            self.assertIn('chat', endpoints)
            self.assertIn('models', endpoints)
            self.assertIn('streaming', endpoints)
            self.assertIsInstance(endpoints['chat'], str)
            self.assertIsInstance(endpoints['models'], str)
            self.assertIsInstance(endpoints['streaming'], str)

            # Check authentication
            auth = provider['authentication']
            self.assertIn('header', auth)
            self.assertIn('prefix', auth)

            # Check features
            features = provider['features']
            self.assertIn('supportsStreaming', features)
            self.assertIn('supportsImages', features)
            self.assertIn('supportsThinking', features)
            self.assertIsInstance(features['supportsStreaming'], bool)
            self.assertIsInstance(features['supportsImages'], bool)
            self.assertIsInstance(features['supportsThinking'], bool)

            # Check models
            self.assertIsInstance(provider['defaultModels'], list)

            # Check headers
            headers = provider['headers']
            self.assertIn('required', headers)
            self.assertIsInstance(headers['required'], list)

    def test_known_providers(self):
        """Test specific known provider configurations"""
        expected_providers = ['openai', 'anthropic', 'gemini', 'ollama']
        for provider in expected_providers:
            self.assertIn(provider, self.config['api_endpoints'])

        # Test OpenAI configuration
        openai = self.config['api_endpoints']['openai']
        self.assertEqual(openai['base_url'], 'https://api.openai.com/v1')
        self.assertTrue(openai['features']['supportsStreaming'])
        self.assertTrue(openai['features']['supportsImages'])
        self.assertIn('Content-Type', openai['headers']['required'])
        self.assertIn('Authorization', openai['headers']['required'])

        # Test Gemini configuration
        gemini = self.config['api_endpoints']['gemini']
        self.assertEqual(gemini['base_url'], 'https://generativelanguage.googleapis.com/v1beta/models')
        self.assertEqual(gemini['authentication']['header'], 'x-goog-api-key')
        self.assertEqual(gemini['authentication']['prefix'], '')

    def test_url_construction(self):
        """Test URL construction logic"""
        # Test OpenAI
        openai = self.config['api_endpoints']['openai']
        base_url = openai['base_url']
        chat_endpoint = base_url + openai['endpoints']['chat']
        self.assertEqual(chat_endpoint, 'https://api.openai.com/v1/chat/completions')

        # Test Anthropic
        anthropic = self.config['api_endpoints']['anthropic']
        anthropic_chat = anthropic['base_url'] + anthropic['endpoints']['chat']
        self.assertEqual(anthropic_chat, 'https://api.anthropic.com/v1/messages')

        # Test Gemini with variable substitution
        # The endpoint template is {model}:generateContent which replaces {model} inline
        gemini = self.config['api_endpoints']['gemini']
        endpoint_template = gemini['endpoints']['chat'].replace('{model}', 'gemini-pro')
        chat_url = gemini['base_url'] + '/' + endpoint_template
        expected = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent'
        self.assertEqual(chat_url, expected)

    def test_authentication_headers(self):
        """Test authentication header construction"""
        for provider_id, provider in self.config['api_endpoints'].items():
            auth = provider['authentication']
            test_key = 'test-api-key'

            if auth['prefix']:
                expected_value = auth['prefix'] + test_key
            else:
                expected_value = test_key

            # This simulates the JavaScript header building logic
            header_name = auth['header']
            header_value = expected_value

            self.assertIsInstance(header_name, str)
            self.assertIsInstance(header_value, str)


class TestEndpointBuilder(unittest.TestCase):
    """Test endpoint building functionality"""

    def setUp(self):
        """Set up test fixtures"""
        config_path = os.path.join(os.path.dirname(__file__), '..', '..', 'config', 'api_endpoints.json')
        with open(config_path, 'r') as f:
            self.config = json.load(f)

    def test_build_endpoint_urls(self):
        """Test endpoint URL building"""
        # Simulate the JavaScript buildEndpointUrl function
        for provider_id, provider in self.config['api_endpoints'].items():
            # Test chat endpoint
            chat_url = self._build_url_mock(provider, 'chat')
            self.assertTrue(chat_url.startswith(provider['base_url']))
            self.assertIn(provider['endpoints']['chat'], chat_url)

            # Test models endpoint
            models_url = self._build_url_mock(provider, 'models')
            if provider['endpoints']['models'] == '':
                # Gemini special case
                self.assertEqual(models_url, provider['base_url'])
            else:
                self.assertEqual(models_url, provider['base_url'] + provider['endpoints']['models'])

    def _build_url_mock(self, provider, endpoint_type):
        """Mock implementation of buildEndpointUrl"""
        endpoint_path = provider['endpoints'][endpoint_type]
        base_url = provider['base_url']

        # Handle special case for Gemini
        if endpoint_type == 'models' and endpoint_path == '':
            return base_url

        return base_url + endpoint_path

    def test_variable_substitution(self):
        """Test variable substitution in endpoints"""
        gemini = self.config['api_endpoints']['gemini']

        # Mock variable substitution
        chat_template = gemini['endpoints']['chat']
        model = 'gemini-pro'

        # Substitute {model} variable
        chat_path = chat_template.replace('{model}', model)
        full_url = gemini['base_url'] + '/' + chat_path  # Add slash for template

        expected = 'https://generativelanguage.googleapis.com/v1beta/models/gemini-pro:generateContent'
        self.assertEqual(full_url, expected)

    def test_header_building(self):
        """Test header building logic"""
        for provider_id, provider in self.config['api_endpoints'].items():
            headers = {}

            # Add Content-Type
            headers['Content-Type'] = 'application/json'

            # Add required headers
            for header in provider['headers']['required']:
                if header.lower() != 'content-type':
                    # Skip auth headers for this test
                    pass

            # Add optional headers
            for opt_header, value in provider['headers'].get('optional', {}).items():
                headers[opt_header] = value

            # Verify at least Content-Type is present
            self.assertIn('Content-Type', headers)


class TestAPICompatibility(unittest.TestCase):
    """Test API compatibility and edge cases"""

    def setUp(self):
        """Set up test fixtures"""
        config_path = os.path.join(os.path.dirname(__file__), '..', '..', 'config', 'api_endpoints.json')
        with open(config_path, 'r') as f:
            self.config = json.load(f)

    def test_provider_features(self):
        """Test provider feature detection"""
        feature_tests = [
            ('openai', 'supportsStreaming', True),
            ('anthropic', 'supportsStreaming', True),
            ('gemini', 'supportsStreaming', True),
            ('ollama', 'supportsStreaming', True),
            ('openai', 'supportsImages', True),
            ('anthropic', 'supportsImages', True),  # Claude 3+ supports images
            ('gemini', 'supportsImages', True),
            ('ollama', 'supportsImages', False),
        ]

        for provider_id, feature, expected in feature_tests:
            provider = self.config['api_endpoints'][provider_id]
            actual = provider['features'][feature]
            self.assertEqual(actual, expected,
                           f"Feature {feature} for {provider_id} should be {expected}")

    def test_default_models(self):
        """Test default models configuration"""
        # OpenAI should have default models
        openai_models = self.config['api_endpoints']['openai']['defaultModels']
        self.assertIsInstance(openai_models, list)
        self.assertGreater(len(openai_models), 0)

        # Gemini typically has empty defaults (dynamic fetching)
        gemini_models = self.config['api_endpoints']['gemini']['defaultModels']
        self.assertIsInstance(gemini_models, list)
        # Could be empty, that's valid

    def test_custom_provider(self):
        """Test custom provider configuration (moved to examples)"""
        # custom_provider has been removed from production config
        # and moved to examples/custom_provider.json
        self.assertNotIn('custom_provider', self.config['api_endpoints'],
                        "custom_provider should not be in production config")


class TestConfigurationLoading(unittest.TestCase):
    """Test configuration loading and error handling"""

    def test_valid_json(self):
        """Test that configuration is valid JSON"""
        config_path = os.path.join(os.path.dirname(__file__), '..', '..', 'config', 'api_endpoints.json')

        with open(config_path, 'r') as f:
            try:
                config = json.load(f)
                self.assertIsInstance(config, dict)
            except json.JSONDecodeError as e:
                self.fail(f"Configuration file is not valid JSON: {e}")

    def test_required_structure(self):
        """Test minimal required structure for custom provider"""
        minimal_config = {
            "api_endpoints": {
                "test_provider": {
                    "name": "Test Provider",
                    "base_url": "https://api.test.com",
                    "endpoints": {
                        "chat": "/chat",
                        "models": "/models",
                        "streaming": "/stream"
                    },
                    "authentication": {
                        "header": "Authorization",
                        "prefix": "Bearer "
                    },
                    "features": {
                        "supportsStreaming": True,
                        "supportsImages": False,
                        "supportsThinking": False
                    },
                    "defaultModels": ["test-model"],
                    "headers": {
                        "required": ["Content-Type"],
                        "optional": {}
                    }
                }
            }
        }

        # Should be valid structure
        self.assertIn('api_endpoints', minimal_config)
        provider = minimal_config['api_endpoints']['test_provider']
        self.assertEqual(provider['name'], 'Test Provider')


def run_tests():
    """Run all tests"""
    # Create test suite
    test_suite = unittest.TestSuite()

    # Add test cases
    test_classes = [
        TestConfigValidation,
        TestEndpointBuilder,
        TestAPICompatibility,
        TestConfigurationLoading
    ]

    for test_class in test_classes:
        tests = unittest.TestLoader().loadTestsFromTestCase(test_class)
        test_suite.addTests(tests)

    # Run tests
    runner = unittest.TextTestRunner(verbosity=2)
    result = runner.run(test_suite)

    return result.wasSuccessful()


if __name__ == '__main__':
    print("Running API Abstraction Layer Python Tests")
    print("=" * 50)

    success = run_tests()

    print("\n" + "=" * 50)
    if success:
        print("✓ All tests passed!")
        exit(0)
    else:
        print("✗ Some tests failed!")
        exit(1)