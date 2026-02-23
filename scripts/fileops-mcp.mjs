#!/usr/bin/env node
// Minimal MCP server providing file write operations.
// Gemini CLI blocks the tool name "write_file" from MCP servers.
// This server exposes "save_file" and "make_directory" instead.

import { createInterface } from "readline";
import { writeFileSync, mkdirSync, existsSync } from "fs";
import { dirname } from "path";

const rl = createInterface({ input: process.stdin });

function respond(id, result) {
  process.stdout.write(JSON.stringify({ jsonrpc: "2.0", id, result }) + "\n");
}

function respondError(id, code, message) {
  process.stdout.write(
    JSON.stringify({ jsonrpc: "2.0", id, error: { code, message } }) + "\n"
  );
}

rl.on("line", (line) => {
  let msg;
  try {
    msg = JSON.parse(line);
  } catch {
    return;
  }

  const { id, method, params } = msg;

  if (method === "initialize") {
    respond(id, {
      protocolVersion: "2024-11-05",
      capabilities: { tools: {} },
      serverInfo: { name: "fileops", version: "1.0.0" },
    });
  } else if (method === "notifications/initialized") {
    // no response needed
  } else if (method === "tools/list") {
    respond(id, {
      tools: [
        {
          name: "save_file",
          description:
            "Create or overwrite a file at the specified path with the given content. Creates parent directories automatically.",
          inputSchema: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "Absolute or relative file path",
              },
              content: {
                type: "string",
                description: "Content to write to the file",
              },
            },
            required: ["path", "content"],
          },
        },
        {
          name: "make_directory",
          description:
            "Create a directory (and parent directories) at the specified path.",
          inputSchema: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "Directory path to create",
              },
            },
            required: ["path"],
          },
        },
      ],
    });
  } else if (method === "tools/call") {
    const toolName = params?.name;
    const args = params?.arguments || {};

    try {
      if (toolName === "save_file") {
        const dir = dirname(args.path);
        if (!existsSync(dir)) mkdirSync(dir, { recursive: true });
        writeFileSync(args.path, args.content, "utf-8");
        respond(id, {
          content: [{ type: "text", text: `Saved: ${args.path}` }],
        });
      } else if (toolName === "make_directory") {
        mkdirSync(args.path, { recursive: true });
        respond(id, {
          content: [{ type: "text", text: `Created: ${args.path}` }],
        });
      } else {
        respondError(id, -32601, `Unknown tool: ${toolName}`);
      }
    } catch (err) {
      respondError(id, -32000, err.message);
    }
  }
});
