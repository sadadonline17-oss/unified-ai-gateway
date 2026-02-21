/**
 * Test suite for Unified AI Gateway
 */

import { strict as assert } from 'assert';
import http from 'http';
import https from 'https';
import OllamaProvider from './ollama/index.js';
import { UnifiedGateway } from './gateway/unified-gateway.js';

// Mock Ollama responses for testing without actual Ollama
class MockOllamaProvider extends OllamaProvider {
  constructor() {
    super({ host: 'http://mock:11434' });
    this.mockModels = [
      { name: 'llama3', size: 4700000000, modified_at: '2024-01-01' },
      { name: 'deepseek-coder', size: 1600000000, modified_at: '2024-01-02' },
    ];
  }

  async checkStatus() {
    return { running: true, models: this.mockModels };
  }

  async listModels() {
    return this.mockModels;
  }

  async *generate(_prompt, _options = {}) {
    const responses = ['Hello', ' from', ' mock', ' AI!'];
    for (const chunk of responses) {
      yield chunk;
    }
  }

  async *chat(_messages, _options = {}) {
    const responses = ['This', ' is', ' a', ' mock', ' response.'];
    for (const chunk of responses) {
      yield chunk;
    }
  }

  async *generateCode(_prompt, _options = {}) {
    const responses = ['```javascript\n', 'function test() {\n', '  return true;\n', '}\n', '```'];
    for (const chunk of responses) {
      yield chunk;
    }
  }
}

// Test Ollama Provider
async function testOllamaProvider() {
  console.log('Testing OllamaProvider...');
  
  const provider = new MockOllamaProvider();
  
  // Test status check
  const status = await provider.checkStatus();
  assert.equal(status.running, true, 'Ollama should be running');
  assert.ok(Array.isArray(status.models), 'Models should be an array');
  console.log('✓ Status check passed');
  
  // Test model listing
  const models = await provider.listModels();
  assert.ok(models.length > 0, 'Should have models');
  console.log('✓ Model listing passed');
  
  // Test model routing
  provider.setModelForMode('core_chat', 'llama3');
  assert.equal(provider.getModelForMode('core_chat'), 'llama3', 'Model routing should work');
  console.log('✓ Model routing passed');
  
  // Test generate
  let generateOutput = '';
  for await (const chunk of provider.generate('test')) {
    generateOutput += chunk;
  }
  assert.ok(generateOutput.length > 0, 'Generate should produce output');
  console.log('✓ Generate passed');
  
  // Test chat
  let chatOutput = '';
  for await (const chunk of provider.chat([{ role: 'user', content: 'test' }])) {
    chatOutput += chunk;
  }
  assert.ok(chatOutput.length > 0, 'Chat should produce output');
  console.log('✓ Chat passed');
  
  // Test code generation
  let codeOutput = '';
  for await (const chunk of provider.generateCode('write a function')) {
    codeOutput += chunk;
  }
  assert.ok(codeOutput.includes('function'), 'Code generation should produce code');
  console.log('✓ Code generation passed');
  
  console.log('All OllamaProvider tests passed!\n');
}

// Test Unified Gateway
async function testUnifiedGateway() {
  console.log('Testing UnifiedGateway...');
  
  const gateway = new UnifiedGateway({
    port: 18799,
    wsPort: 18800,
    ollama: { host: 'http://mock:11434' }
  });
  
  // Replace with mock provider
  gateway.ollama = new MockOllamaProvider();
  
  // Test route setup
  assert.ok(gateway.requestHandlers.has('/status'), 'Should have /status route');
  assert.ok(gateway.requestHandlers.has('/ai/chat'), 'Should have /ai/chat route');
  assert.ok(gateway.requestHandlers.has('/ai/code'), 'Should have /ai/code route');
  assert.ok(gateway.requestHandlers.has('/models'), 'Should have /models route');
  console.log('✓ Route setup passed');
  
  // Test gateway start
  const addresses = await gateway.start();
  assert.ok(addresses.http, 'Should return HTTP address');
  assert.ok(addresses.ws, 'Should return WebSocket address');
  console.log('✓ Gateway start passed');
  
  // Test HTTP request handling
  const statusResponse = await makeRequest('http://localhost:18799/status');
  const statusData = JSON.parse(statusResponse);
  assert.equal(statusData.status, 'running', 'Gateway should be running');
  console.log('✓ HTTP status endpoint passed');
  
  // Test models endpoint
  const modelsResponse = await makeRequest('http://localhost:18799/models');
  const modelsData = JSON.parse(modelsResponse);
  assert.ok(Array.isArray(modelsData.models), 'Models endpoint should return array');
  console.log('✓ Models endpoint passed');
  
  // Test routing endpoint
  const routingResponse = await makeRequest('http://localhost:18799/routing');
  const routingData = JSON.parse(routingResponse);
  assert.ok(routingData.routes, 'Routing endpoint should return routes');
  console.log('✓ Routing endpoint passed');
  
  // Test gateway stop
  await gateway.stop();
  console.log('✓ Gateway stop passed');
  
  console.log('All UnifiedGateway tests passed!\n');
}

// Helper function for HTTP requests
function makeRequest(url) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https') ? https : http;
    client.get(url, (res) => {
      let data = '';
      res.on('data', chunk => data += chunk);
      res.on('end', () => resolve(data));
    }).on('error', reject);
  });
}

// Run all tests
async function runTests() {
  console.log('='.repeat(50));
  console.log('Unified AI Gateway Test Suite');
  console.log('='.repeat(50) + '\n');
  
  try {
    await testOllamaProvider();
    await testUnifiedGateway();
    
    console.log('='.repeat(50));
    console.log('All tests passed! ✓');
    console.log('='.repeat(50));
    
    process.exit(0);
  } catch (error) {
    console.error('Test failed:', error);
    process.exit(1);
  }
}

// Run tests if executed directly
runTests();

export { testOllamaProvider, testUnifiedGateway };