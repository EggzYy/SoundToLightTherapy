#!/usr/bin/env node

// Simple wrapper for byterover-mcp that handles the File API issue
global.File = global.File || class File {
  constructor(fileBits, fileName, options = {}) {
    this.name = fileName;
    this.type = options.type || '';
    this.lastModified = options.lastModified || Date.now();
    this.size = 0;
    this.stream = () => new ReadableStream();
    this.text = () => Promise.resolve('');
    this.arrayBuffer = () => Promise.resolve(new ArrayBuffer(0));
  }
};

// Import and run mcp-remote
import('mcp-remote').then(mcpRemote => {
  const url = process.argv[2];
  if (!url) {
    console.error('Usage: node byterover-wrapper.js <url>');
    process.exit(1);
  }
  mcpRemote.default([url]);
}).catch(err => {
  console.error('Error starting mcp-remote:', err);
  process.exit(1);
});