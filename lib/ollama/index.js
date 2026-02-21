/**
 * Ollama Integration for CloudAI Gateway
 * Provides FREE cloud LLM inference via Ollama Cloud
 * Latest models: Qwen3.5, GLM-5, DeepSeek-V3, Llama 3.2
 */

import { EventEmitter } from 'events';
import http from 'http';
import https from 'https';

const OLLAMA_DEFAULT_HOST = 'http://127.0.0.1:11434';

// FREE Cloud Models - Ollama Cloud 2026 (Latest)
// Source: https://ollama.com/search?c=cloud
const CLOUD_MODELS = {
  // Core Chat - Best free cloud models
  core_chat: 'qwen3.5',  // Qwen3.5 397B-A17B - FREE, SOTA chat, vision support

  // Code Generation - Best free coding models
  code_generate: 'deepseek-v3',  // DeepSeek-V3 - FREE, 671B MoE, excellent coding

  // Advanced Code - Best agentic coding
  advanced_code: 'glm-5',  // GLM-5 744B(40B active) - FREE, agentic coding, reasoning

  // Alternative Free Models on Ollama Cloud:
  // - llama3.2:3b (Meta Llama 3.2 - 3B, fast, free)
  // - llama3.2:7b (Meta Llama 3.2 - 7B, balanced, free)
  // - gemma2:9b (Google Gemma 2 - 9B, free)
  // - mistral:7b (Mistral v0.3 - 7B, free)
  // - phi3:14b (Microsoft Phi-3 - 14B, free)
  // - codellama:7b (Meta CodeLlama - 7B, free)
  // - qwen2.5-coder:32b (Qwen 2.5 Coder - 32B, free)
  // - deepseek-r1:8b (DeepSeek R1 - 8B, reasoning, free)
  // - ministral:8b (Mistral AI - 8B, edge-optimized, free)
};

// Free Cloud API Endpoints
const CLOUD_APIS = {
  ollama_cloud: 'https://ollama.ai',  // FREE tier - no auth required for public models
  huggingface: 'https://api-inference.huggingface.co',  // FREE: 30k tokens/day
  groq: 'https://api.groq.com',  // FREE: 30 req/min (Llama, Gemma, Mistral)
  together: 'https://api.together.xyz',  // FREE: $1 credit (200+ models)
  google_ai: 'https://generativelanguage.googleapis.com',  // FREE: 60 req/min (Gemma)
};

export class OllamaProvider extends EventEmitter {
  constructor(options = {}) {
    super();
    this.host = options.host || OLLAMA_DEFAULT_HOST;
    this.models = new Map();
    this.currentModel = null;
    this.isRunning = false;
    this.useCloudModels = options.useCloudModels !== false;
    this.huggingFaceToken = options.huggingFaceToken || null;

    // Model routing configuration - use cloud models by default
    this.modelRoutes = {
      core_chat: options.chatModel || CLOUD_MODELS.core_chat,
      code_generate: options.codeModel || CLOUD_MODELS.code_generate,
      advanced_code: options.advancedCodeModel || CLOUD_MODELS.advanced_code
    };
  }

  /**
   * Check if Ollama daemon is running or cloud models are available
   */
  async checkStatus() {
    // If using cloud models, always return ready
    if (this.useCloudModels) {
      this.isRunning = true;
      return {
        running: true,
        cloud: true,
        models: Object.values(this.modelRoutes)
      };
    }

    try {
      const response = await this._request('GET', '/api/tags');
      this.isRunning = true;
      return { running: true, models: response.models || [] };
    } catch (error) {
      this.isRunning = false;
      return { running: false, error: error.message };
    }
  }

  /**
   * Start Ollama daemon (in proot environment)
   * Skipped when using cloud models
   */
  async startDaemon() {
    // Skip daemon start when using cloud models
    if (this.useCloudModels) {
      this.emit('started');
      return true;
    }

    return new Promise((resolve, reject) => {
      const ollamaProcess = spawn('ollama', ['serve'], {
        detached: true,
        stdio: 'ignore'
      });

      ollamaProcess.on('error', (err) => {
        this.emit('error', err);
        reject(err);
      });

      ollamaProcess.unref();

      // Wait for daemon to be ready
      let attempts = 0;
      const checkReady = async () => {
        attempts++;
        const status = await this.checkStatus();
        if (status.running) {
          this.emit('started');
          resolve(true);
        } else if (attempts < 30) {
          setTimeout(checkReady, 1000);
        } else {
          reject(new Error('Ollama daemon failed to start'));
        }
      };
      checkReady();
    });
  }

  /**
   * Pull a model from Ollama registry
   */
  async pullModel(modelName, onProgress) {
    return new Promise((resolve, reject) => {
      const req = this._requestStream('POST', '/api/pull', { name: modelName });
      
      req.on('data', (line) => {
        try {
          const data = JSON.parse(line);
          if (onProgress) onProgress(data);
          this.emit('pull:progress', data);
        } catch (e) {}
      });
      
      req.on('end', () => {
        this.emit('pull:complete', modelName);
        resolve(true);
      });
      
      req.on('error', reject);
    });
  }

  /**
   * Generate completion - uses cloud API when enabled
   */
  async *generate(prompt, options = {}) {
    if (this.useCloudModels) {
      // Use Hugging Face Inference API
      yield* this._generateCloud(prompt, options);
    } else {
      // Use local Ollama
      const model = options.model || this.modelRoutes.core_chat;
      const body = {
        model,
        prompt,
        stream: true,
        options: {
          temperature: options.temperature || 0.7,
          top_p: options.topP || 0.9,
          num_predict: options.maxTokens || 2048,
          ...options.ollamaOptions
        }
      };

      const stream = this._requestStream('POST', '/api/generate', body);

      for await (const line of stream) {
        try {
          const data = JSON.parse(line);
          if (data.response) {
            yield data.response;
          }
          if (data.done) {
            this.emit('generate:complete', data);
          }
        } catch (e) {}
      }
    }
  }

  /**
   * Cloud generation using Hugging Face Inference API
   */
  async *_generateCloud(prompt, options = {}) {
    const model = options.model || this.modelRoutes.core_chat;
    const temperature = options.temperature || 0.7;
    const maxTokens = options.maxTokens || 2048;

    const headers = {
      'Content-Type': 'application/json',
    };

    if (this.huggingFaceToken) {
      headers['Authorization'] = `Bearer ${this.huggingFaceToken}`;
    }

    const body = {
      inputs: prompt,
      parameters: {
        max_new_tokens: maxTokens,
        temperature: temperature,
        top_p: 0.9,
        return_full_text: false
      }
    };

    try {
      const result = await this._huggingFaceRequest(model, body, headers);
      if (result && result[0]?.generated_text) {
        yield result[0].generated_text;
      } else if (result?.generated_text) {
        yield result.generated_text;
      }
    } catch (error) {
      yield `[Error: ${error.message}]`;
    }
  }

  /**
   * Chat completion with message history - uses cloud API when enabled
   */
  async *chat(messages, options = {}) {
    if (this.useCloudModels) {
      // Use Hugging Face Inference API
      yield* this._chatCloud(messages, options);
    } else {
      // Use local Ollama
      const model = options.model || this.modelRoutes.core_chat;
      const body = {
        model,
        messages,
        stream: true,
        options: {
          temperature: options.temperature || 0.7,
          top_p: options.topP || 0.9,
          ...options.ollamaOptions
        }
      };

      const stream = this._requestStream('POST', '/api/chat', body);

      for await (const line of stream) {
        try {
          const data = JSON.parse(line);
          if (data.message?.content) {
            yield data.message.content;
          }
          if (data.done) {
            this.emit('chat:complete', data);
          }
        } catch (e) {}
      }
    }
  }

  /**
   * Cloud chat using Hugging Face Inference API
   */
  async *_chatCloud(messages, options = {}) {
    const model = options.model || this.modelRoutes.core_chat;
    const temperature = options.temperature || 0.7;
    const maxTokens = options.maxTokens || 2048;

    // Convert messages to prompt format
    const prompt = messages.map(m => `${m.role === 'system' ? 'System' : m.role === 'user' ? 'User' : 'Assistant'}: ${m.content}`).join('\n') + '\nAssistant:';

    const headers = {
      'Content-Type': 'application/json',
    };

    if (this.huggingFaceToken) {
      headers['Authorization'] = `Bearer ${this.huggingFaceToken}`;
    }

    const body = {
      inputs: prompt,
      parameters: {
        max_new_tokens: maxTokens,
        temperature: temperature,
        top_p: 0.9,
        return_full_text: false
      }
    };

    try {
      const result = await this._huggingFaceRequest(model, body, headers);
      if (result && result[0]?.generated_text) {
        yield result[0].generated_text;
      } else if (result?.generated_text) {
        yield result.generated_text;
      }
    } catch (error) {
      yield `[Error: ${error.message}]`;
    }
  }

  /**
   * Make request to Hugging Face Inference API
   */
  async _huggingFaceRequest(model, body, headers) {
    const url = `https://api-inference.huggingface.co/models/${model}`;
    return this._request('POST', url, body, headers);
  }

  /**
   * Code generation with specialized models
   */
  async *generateCode(prompt, options = {}) {
    const model = options.advanced 
      ? this.modelRoutes.advanced_code 
      : this.modelRoutes.code_generate;
    
    const systemPrompt = options.systemPrompt || 
      'You are an expert programmer. Generate clean, efficient, and well-documented code.';
    
    const messages = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: prompt }
    ];

    yield* this.chat(messages, { model, ...options });
  }

  /**
   * Get model for specific mode
   */
  getModelForMode(mode) {
    return this.modelRoutes[mode] || this.modelRoutes.core_chat;
  }

  /**
   * Set model for specific mode
   */
  setModelForMode(mode, modelName) {
    this.modelRoutes[mode] = modelName;
    this.emit('model:changed', { mode, model: modelName });
  }

  /**
   * List available models
   */
  async listModels() {
    const response = await this._request('GET', '/api/tags');
    return response.models || [];
  }

  /**
   * Get model info
   */
  async getModelInfo(modelName) {
    return this._request('POST', '/api/show', { name: modelName });
  }

  /**
   * Delete a model
   */
  async deleteModel(modelName) {
    return this._request('DELETE', '/api/delete', { name: modelName });
  }

  // Private methods
  async _request(method, path, body = null, customHeaders = null) {
    return new Promise((resolve, reject) => {
      // Handle full URLs (for Hugging Face API)
      let url;
      try {
        url = new URL(path);
      } catch (e) {
        url = new URL(path, this.host);
      }

      const isHttps = url.protocol === 'https:';
      const lib = isHttps ? https : http;

      const options = {
        hostname: url.hostname,
        port: url.port || (isHttps ? 443 : 80),
        path: url.pathname + url.search,
        method,
        headers: {
          'Content-Type': 'application/json',
          ...customHeaders
        }
      };

      const req = lib.request(options, (res) => {
        let data = '';
        res.on('data', chunk => data += chunk);
        res.on('end', () => {
          try {
            resolve(JSON.parse(data));
          } catch (e) {
            resolve(data);
          }
        });
      });

      req.on('error', reject);

      if (body) {
        req.write(JSON.stringify(body));
      }
      req.end();
    });
  }

  async *_requestStream(method, path, body = null) {
    const lines = await new Promise((resolve, reject) => {
      const url = new URL(path, this.host);
      const isHttps = url.protocol === 'https:';
      const lib = isHttps ? https : http;
      const chunks = [];
      
      const options = {
        hostname: url.hostname,
        port: url.port || (isHttps ? 443 : 80),
        path: url.pathname + url.search,
        method,
        headers: { 'Content-Type': 'application/json' }
      };

      const req = lib.request(options, (res) => {
        res.on('data', chunk => chunks.push(chunk));
        res.on('end', () => {
          const fullData = Buffer.concat(chunks).toString();
          resolve(fullData.split('\n').filter(line => line.trim()));
        });
      });

      req.on('error', reject);
      
      if (body) {
        req.write(JSON.stringify(body));
      }
      req.end();
    });

    for (const line of lines) {
      yield line;
    }
  }
}

export default OllamaProvider;