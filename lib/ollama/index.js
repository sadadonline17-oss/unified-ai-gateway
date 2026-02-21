/**
 * Ollama Integration for OpenClaw Unified
 * Provides local LLM inference with multiple coding models
 */

import { spawn, exec } from 'child_process';
import { EventEmitter } from 'events';
import http from 'http';
import https from 'https';

const OLLAMA_DEFAULT_HOST = 'http://127.0.0.1:11434';

export class OllamaProvider extends EventEmitter {
  constructor(options = {}) {
    super();
    this.host = options.host || OLLAMA_DEFAULT_HOST;
    this.models = new Map();
    this.currentModel = null;
    this.isRunning = false;
    
    // Model routing configuration
    this.modelRoutes = {
      core_chat: options.chatModel || 'llama3',
      code_generate: options.codeModel || 'deepseek-coder',
      advanced_code: options.advancedCodeModel || 'qwen2.5-coder'
    };
  }

  /**
   * Check if Ollama daemon is running
   */
  async checkStatus() {
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
   */
  async startDaemon() {
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
   * Generate completion with streaming
   */
  async *generate(prompt, options = {}) {
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

  /**
   * Chat completion with message history
   */
  async *chat(messages, options = {}) {
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
  async _request(method, path, body = null) {
    return new Promise((resolve, reject) => {
      const url = new URL(path, this.host);
      const isHttps = url.protocol === 'https:';
      const lib = isHttps ? https : http;
      
      const options = {
        hostname: url.hostname,
        port: url.port || (isHttps ? 443 : 80),
        path: url.pathname + url.search,
        method,
        headers: { 'Content-Type': 'application/json' }
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