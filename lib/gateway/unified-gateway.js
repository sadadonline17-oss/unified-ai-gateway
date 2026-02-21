/**
 * Unified Gateway - OpenClaw + Ollama + NullClaw Integration
 * Provides HTTP + WebSocket API for AI operations
 */

import http from 'http';
import { WebSocketServer } from 'ws';
import { EventEmitter } from 'events';
import OllamaProvider from '../ollama/index.js';

const DEFAULT_PORT = 18789;
const WS_PORT = 18790;

export class UnifiedGateway extends EventEmitter {
  constructor(options = {}) {
    super();
    this.port = options.port || DEFAULT_PORT;
    this.wsPort = options.wsPort || WS_PORT;
    this.ollama = new OllamaProvider(options.ollama);
    this.server = null;
    this.wsServer = null;
    this.clients = new Set();
    this.requestHandlers = new Map();
    
    this._setupRoutes();
  }

  _setupRoutes() {
    // Health check
    this.requestHandlers.set('/status', async (req, res) => {
      const ollamaStatus = await this.ollama.checkStatus();
      res.json({
        status: 'running',
        gateway: 'unified-openclaw',
        version: '2.0.0',
        ollama: ollamaStatus,
        timestamp: new Date().toISOString()
      });
    });

    // AI Chat endpoint
    this.requestHandlers.set('/ai/chat', async (req, res) => {
      const { message, history = [], options = {} } = req.body;
      
      if (!message) {
        return res.status(400).json({ error: 'Message is required' });
      }

      const messages = [
        ...history,
        { role: 'user', content: message }
      ];

      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');

      try {
        for await (const chunk of this.ollama.chat(messages, options)) {
          res.write(`data: ${JSON.stringify({ chunk })}\n\n`);
        }
        res.write('data: [DONE]\n\n');
        res.end();
      } catch (error) {
        res.write(`data: ${JSON.stringify({ error: error.message })}\n\n`);
        res.end();
      }
    });

    // AI Code generation endpoint
    this.requestHandlers.set('/ai/code', async (req, res) => {
      const { prompt, language, options = {} } = req.body;
      
      if (!prompt) {
        return res.status(400).json({ error: 'Prompt is required' });
      }

      const fullPrompt = language 
        ? `Generate ${language} code: ${prompt}`
        : prompt;

      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');

      try {
        for await (const chunk of this.ollama.generateCode(fullPrompt, options)) {
          res.write(`data: ${JSON.stringify({ chunk })}\n\n`);
        }
        res.write('data: [DONE]\n\n');
        res.end();
      } catch (error) {
        res.write(`data: ${JSON.stringify({ error: error.message })}\n\n`);
        res.end();
      }
    });

    // Advanced code endpoint (uses qwen2.5-coder or similar)
    this.requestHandlers.set('/ai/advanced_code', async (req, res) => {
      const { prompt, context, options = {} } = req.body;
      
      if (!prompt) {
        return res.status(400).json({ error: 'Prompt is required' });
      }

      const fullPrompt = context 
        ? `Context:\n${context}\n\nTask: ${prompt}`
        : prompt;

      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');

      try {
        for await (const chunk of this.ollama.generateCode(fullPrompt, { 
          advanced: true, 
          ...options 
        })) {
          res.write(`data: ${JSON.stringify({ chunk })}\n\n`);
        }
        res.write('data: [DONE]\n\n');
        res.end();
      } catch (error) {
        res.write(`data: ${JSON.stringify({ error: error.message })}\n\n`);
        res.end();
      }
    });

    // Model management
    this.requestHandlers.set('/models', async (req, res) => {
      try {
        const models = await this.ollama.listModels();
        res.json({ models });
      } catch (error) {
        res.status(500).json({ error: error.message });
      }
    });

    this.requestHandlers.set('/models/pull', async (req, res) => {
      const { name } = req.body;
      
      if (!name) {
        return res.status(400).json({ error: 'Model name is required' });
      }

      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');

      try {
        await this.ollama.pullModel(name, (progress) => {
          res.write(`data: ${JSON.stringify(progress)}\n\n`);
        });
        res.write('data: [DONE]\n\n');
        res.end();
      } catch (error) {
        res.write(`data: ${JSON.stringify({ error: error.message })}\n\n`);
        res.end();
      }
    });

    // Model routing configuration
    this.requestHandlers.set('/routing', async (req, res) => {
      if (req.method === 'GET') {
        res.json({ routes: this.ollama.modelRoutes });
      } else if (req.method === 'POST') {
        const { mode, model } = req.body;
        this.ollama.setModelForMode(mode, model);
        res.json({ success: true, routes: this.ollama.modelRoutes });
      }
    });

    // OpenCode/Claude-style/Codex mode endpoints
    this.requestHandlers.set('/ai/opencode', async (req, res) => {
      const { prompt, mode = 'code', options = {} } = req.body;
      
      const modePrompts = {
        code: 'You are an expert programmer. Write clean, efficient code.',
        claude: 'You are Claude, a helpful AI assistant focused on thoughtful, detailed responses.',
        codex: 'You are Codex, an AI specialized in code completion and generation.'
      };

      const messages = [
        { role: 'system', content: modePrompts[mode] || modePrompts.code },
        { role: 'user', content: prompt }
      ];

      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');

      try {
        for await (const chunk of this.ollama.chat(messages, options)) {
          res.write(`data: ${JSON.stringify({ chunk })}\n\n`);
        }
        res.write('data: [DONE]\n\n');
        res.end();
      } catch (error) {
        res.write(`data: ${JSON.stringify({ error: error.message })}\n\n`);
        res.end();
      }
    });
  }

  async start() {
    // Start HTTP server
    this.server = http.createServer((req, res) => {
      this._handleRequest(req, res);
    });

    // Start WebSocket server
    this.wsServer = new WebSocketServer({ port: this.wsPort });
    
    this.wsServer.on('connection', (ws) => {
      this.clients.add(ws);
      ws.on('message', (data) => this._handleWsMessage(ws, data));
      ws.on('close', () => this.clients.delete(ws));
      
      ws.send(JSON.stringify({ type: 'connected', message: 'Welcome to Unified Gateway' }));
    });

    return new Promise((resolve) => {
      this.server.listen(this.port, () => {
        this.emit('started', { port: this.port, wsPort: this.wsPort });
        resolve({
          http: `http://localhost:${this.port}`,
          ws: `ws://localhost:${this.wsPort}`
        });
      });
    });
  }

  async stop() {
    return new Promise((resolve) => {
      // Close all WebSocket connections
      for (const client of this.clients) {
        client.close();
      }
      
      this.wsServer?.close();
      this.server?.close(() => {
        this.emit('stopped');
        resolve();
      });
    });
  }

  async _handleRequest(req, res) {
    const url = new URL(req.url, `http://localhost:${this.port}`);
    const path = url.pathname;

    // CORS headers
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

    if (req.method === 'OPTIONS') {
      return res.end();
    }

    // Parse body for POST requests
    if (req.method === 'POST') {
      let body = '';
      for await (const chunk of req) {
        body += chunk;
      }
      try {
        req.body = JSON.parse(body);
      } catch {
        req.body = {};
      }
    }

    // Add json helper to response
    res.json = (data) => {
      res.setHeader('Content-Type', 'application/json');
      res.end(JSON.stringify(data));
    };

    res.status = (code) => {
      res.statusCode = code;
      return res;
    };

    // Find and execute handler
    const handler = this.requestHandlers.get(path);
    if (handler) {
      try {
        await handler(req, res);
      } catch (error) {
        this.emit('error', error);
        res.status(500).json({ error: error.message });
      }
    } else {
      res.status(404).json({ error: 'Not found' });
    }
  }

  async _handleWsMessage(ws, data) {
    try {
      const message = JSON.parse(data);
      
      switch (message.type) {
        case 'chat':
          await this._handleWsChat(ws, message);
          break;
        case 'code':
          await this._handleWsCode(ws, message);
          break;
        case 'ping':
          ws.send(JSON.stringify({ type: 'pong' }));
          break;
        default:
          ws.send(JSON.stringify({ type: 'error', message: 'Unknown message type' }));
      }
    } catch (error) {
      ws.send(JSON.stringify({ type: 'error', message: error.message }));
    }
  }

  async _handleWsChat(ws, message) {
    const { content, history = [], options = {} } = message;
    const messages = [...history, { role: 'user', content }];

    try {
      for await (const chunk of this.ollama.chat(messages, options)) {
        ws.send(JSON.stringify({ type: 'chat:chunk', chunk }));
      }
      ws.send(JSON.stringify({ type: 'chat:complete' }));
    } catch (error) {
      ws.send(JSON.stringify({ type: 'error', message: error.message }));
    }
  }

  async _handleWsCode(ws, message) {
    const { prompt, options = {} } = message;

    try {
      for await (const chunk of this.ollama.generateCode(prompt, options)) {
        ws.send(JSON.stringify({ type: 'code:chunk', chunk }));
      }
      ws.send(JSON.stringify({ type: 'code:complete' }));
    } catch (error) {
      ws.send(JSON.stringify({ type: 'error', message: error.message }));
    }
  }
}

export default UnifiedGateway;