/**
 * Unified AI Gateway - Main Entry Point
 * Ollama + OpenClaw + NullClaw integration for Android
 */

import { UnifiedGateway } from './gateway/unified-gateway.js';
import OllamaProvider from './ollama/index.js';

export { UnifiedGateway, OllamaProvider };

export async function createGateway(options = {}) {
  const gateway = new UnifiedGateway(options);
  return gateway;
}

export default UnifiedGateway;