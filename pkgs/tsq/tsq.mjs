#!@node@
// tsq — TypeScript LSP CLI backed by vtsls, with a per-project daemon.
//
// Client (default):
//   tsq hover    <file> <line> <col>     1-based line/col, paths relative to CWD
//   tsq def      <file> <line> <col>
//   tsq refs     <file> <line> <col>
//   tsq symbols  <file>                  document symbols (hierarchical)
//   tsq wsymbols <query>                 workspace symbol search
//   tsq warmup                           force project-load (run once after starting)
//   tsq status                           daemon state
//   tsq stop                             kill daemon for current project
//
// Daemon (internal, spawned by client):
//   tsq --daemon <project-root>

import { spawn } from 'node:child_process';
import { createServer, createConnection } from 'node:net';
import { readFileSync, writeFileSync, readdirSync, existsSync, mkdirSync, statSync, unlinkSync, chmodSync } from 'node:fs';
import { resolve, isAbsolute, join, dirname } from 'node:path';
import { pathToFileURL } from 'node:url';
import { createHash } from 'node:crypto';

const VTSLS = '@vtsls@';
const NODE = '@node@';
const SCRIPT = '@script@';
// Each daemon holds a full vtsls/tsserver (~GBs of RSS for a large project),
// and there is one daemon per project root — so every git worktree spawns its
// own. Two knobs bound the blast radius:
//   IDLE_TIMEOUT_MS — how long a daemon lingers with no requests before exiting.
//   MAX_DAEMONS     — global LRU cap; spawning past it evicts the stalest daemon.
// Both are env-overridable (TSQ_IDLE_TIMEOUT_MS, TSQ_MAX_DAEMONS).
const IDLE_TIMEOUT_MS = Number(process.env.TSQ_IDLE_TIMEOUT_MS) || 5 * 60 * 1000;
const MAX_DAEMONS = Number(process.env.TSQ_MAX_DAEMONS) || 3;
const DAEMON_START_TIMEOUT_MS = 20_000;

function findProjectRoot(start) {
  let dir = resolve(start);
  while (true) {
    if (existsSync(join(dir, 'tsconfig.json'))) return dir;
    if (existsSync(join(dir, 'package.json'))) return dir;
    if (existsSync(join(dir, '.git'))) return dir;
    const parent = dirname(dir);
    if (parent === dir) return resolve(start);
    dir = parent;
  }
}

function socketDir() {
  const base = process.env.XDG_RUNTIME_DIR || `/tmp/tsq-${process.env.USER || 'user'}`;
  const dir = join(base, 'tsq');
  mkdirSync(dir, { recursive: true, mode: 0o700 });
  return dir;
}

function socketPath(root) {
  const hash = createHash('sha256').update(root).digest('hex').slice(0, 12);
  return join(socketDir(), `${hash}.sock`);
}

// Each daemon writes a sidecar `<hash>.json` alongside its socket recording
// { root, pid, lastActivity }. The client reads these to enforce the LRU cap.
function statePath(sock) {
  return sock.replace(/\.sock$/, '.json');
}

function readDaemonStates() {
  const dir = socketDir();
  let names;
  try { names = readdirSync(dir); } catch { return []; }
  const out = [];
  for (const name of names) {
    if (!name.endsWith('.json')) continue;
    const sp = join(dir, name);
    try {
      const s = JSON.parse(readFileSync(sp, 'utf8'));
      out.push({ ...s, sock: sp.replace(/\.json$/, '.sock'), statePath: sp });
    } catch {}
  }
  return out;
}

// Before spawning a daemon for `newRoot`, keep the live-daemon count within
// MAX_DAEMONS by stopping the least-recently-used ones. Dead state files
// (daemon gone but sidecar left behind) are pruned as we go.
async function enforceDaemonCap(newRoot) {
  if (MAX_DAEMONS <= 0) return;
  const alive = [];
  for (const s of readDaemonStates()) {
    if (s.root === newRoot) continue; // about to (re)spawn this one; don't count it
    if (await ping(s.sock)) alive.push(s);
    else { try { unlinkSync(s.statePath); } catch {} }
  }
  // After we spawn newRoot the total becomes alive.length + 1; keep it <= cap.
  const evict = alive.length + 1 - MAX_DAEMONS;
  if (evict <= 0) return;
  alive.sort((a, b) => (a.lastActivity || 0) - (b.lastActivity || 0)); // stalest first
  for (const victim of alive.slice(0, evict)) {
    try { await sendRequest(victim.sock, { op: 'stop' }); } catch {}
  }
}

// ---------------- client ----------------

async function clientMain(argv) {
  const [op, ...rest] = argv;
  if (!op) {
    console.error('usage: tsq <hover|def|refs|symbols|wsymbols|warmup|status|stop> ...');
    process.exit(2);
  }
  const root = findProjectRoot(process.cwd());
  const sock = socketPath(root);

  if (op === 'status') {
    const alive = await ping(sock);
    console.log(JSON.stringify({ root, socket: sock, alive }, null, 2));
    return;
  }
  if (op === 'stop') {
    if (!(await ping(sock))) { console.log('not running'); return; }
    const r = await sendRequest(sock, { op: 'stop' });
    console.log(r?.ok ? 'stopped' : JSON.stringify(r));
    return;
  }

  if (!(await ping(sock))) {
    await enforceDaemonCap(root);
    spawnDaemon(root);
    await waitForSocket(sock);
  }

  const req = { op, args: rest, cwd: process.cwd() };
  const res = await sendRequest(sock, req);
  if (res?.error) {
    console.error('error:', res.error);
    process.exit(1);
  }
  if (res?.text != null) process.stdout.write(res.text);
  else if (res?.lines) for (const l of res.lines) console.log(l);
  else console.log(JSON.stringify(res, null, 2));
}

function ping(sock) {
  return new Promise((resolve) => {
    if (!existsSync(sock)) { resolve(false); return; }
    const c = createConnection(sock);
    let done = false;
    const finish = (v) => { if (done) return; done = true; try { c.destroy(); } catch {} resolve(v); };
    c.on('connect', () => finish(true));
    c.on('error', () => finish(false));
    setTimeout(() => finish(false), 500);
  });
}

function spawnDaemon(root) {
  // Detached child survives the client exiting.
  const proc = spawn(NODE, [SCRIPT, '--daemon', root], {
    detached: true,
    stdio: ['ignore', 'ignore', 'ignore'],
    env: process.env,
  });
  proc.unref();
}

async function waitForSocket(sock) {
  const deadline = Date.now() + DAEMON_START_TIMEOUT_MS;
  while (Date.now() < deadline) {
    if (await ping(sock)) return;
    await new Promise(r => setTimeout(r, 100));
  }
  throw new Error(`daemon did not come up at ${sock}`);
}

function sendRequest(sock, req) {
  return new Promise((resolve, reject) => {
    const c = createConnection(sock);
    let buf = '';
    c.on('data', d => { buf += d.toString('utf8'); });
    c.on('end', () => {
      try { resolve(JSON.parse(buf)); }
      catch (e) { reject(new Error(`bad daemon response: ${buf.slice(0, 200)}`)); }
    });
    c.on('error', reject);
    // Don't half-close — server may not flush its reply if we send FIN early.
    c.write(JSON.stringify(req) + '\n');
  });
}

// ---------------- daemon ----------------

async function daemonMain(root) {
  const rootAbs = resolve(root);
  process.chdir(rootAbs);
  const rootUri = pathToFileURL(rootAbs).href;
  const sock = socketPath(rootAbs);

  // Stale socket cleanup: if file exists but no listener, remove it.
  if (existsSync(sock)) {
    if (await ping(sock)) {
      // Another daemon already running for this root. Bail.
      process.exit(0);
    }
    try { unlinkSync(sock); } catch {}
  }

  // Start vtsls.
  const lsp = spawn(VTSLS, ['--stdio'], { stdio: ['pipe', 'pipe', 'pipe'] });
  lsp.stderr.on('data', () => {}); // swallow

  const pending = new Map();
  let nextId = 1;
  let buf = Buffer.alloc(0);
  lsp.stdout.on('data', (chunk) => {
    buf = Buffer.concat([buf, chunk]);
    while (true) {
      const headerEnd = buf.indexOf('\r\n\r\n');
      if (headerEnd === -1) return;
      const header = buf.subarray(0, headerEnd).toString('utf8');
      const m = header.match(/Content-Length:\s*(\d+)/i);
      if (!m) { buf = buf.subarray(headerEnd + 4); continue; }
      const len = +m[1];
      if (buf.length < headerEnd + 4 + len) return;
      const body = buf.subarray(headerEnd + 4, headerEnd + 4 + len).toString('utf8');
      buf = buf.subarray(headerEnd + 4 + len);
      let msg;
      try { msg = JSON.parse(body); } catch { continue; }
      if (msg.id != null && pending.has(msg.id)) {
        const { resolve } = pending.get(msg.id);
        pending.delete(msg.id);
        resolve(msg);
      }
    }
  });
  lsp.on('exit', () => { process.exit(0); });

  const sendLsp = (payload) => {
    const json = JSON.stringify(payload);
    const b = Buffer.from(json, 'utf8');
    lsp.stdin.write(`Content-Length: ${b.length}\r\n\r\n`);
    lsp.stdin.write(b);
  };
  const lspRequest = (method, params) => {
    const id = nextId++;
    return new Promise((resolve, reject) => {
      pending.set(id, { resolve, reject });
      sendLsp({ jsonrpc: '2.0', id, method, params });
    });
  };
  const lspNotify = (method, params) => {
    sendLsp({ jsonrpc: '2.0', method, params });
  };

  await lspRequest('initialize', {
    processId: process.pid,
    rootUri,
    workspaceFolders: [{ uri: rootUri, name: 'workspace' }],
    capabilities: {
      textDocument: {
        hover: { contentFormat: ['markdown', 'plaintext'] },
        definition: { linkSupport: false },
        references: {},
        documentSymbol: { hierarchicalDocumentSymbolSupport: true },
        synchronization: { didSave: true }
      },
      workspace: { symbol: {}, workspaceFolders: true }
    },
    initializationOptions: {
      preferences: { includePackageJsonAutoImports: 'off' }
    }
  });
  lspNotify('initialized', {});

  // Track open documents so we can refresh on disk-change.
  // Map<uri, { version, languageId, mtimeMs }>
  const openDocs = new Map();

  function langId(path) {
    const ext = path.split('.').pop();
    return ext === 'tsx' ? 'typescriptreact'
      : ext === 'jsx' ? 'javascriptreact'
      : ext === 'ts' ? 'typescript'
      : ext === 'mts' || ext === 'cts' ? 'typescript'
      : ext === 'mjs' || ext === 'cjs' ? 'javascript'
      : 'javascript';
  }

  function ensureOpen(file, cwd) {
    const path = isAbsolute(file) ? file : resolve(cwd || rootAbs, file);
    if (!existsSync(path)) throw new Error(`file not found: ${path}`);
    const uri = pathToFileURL(path).href;
    const text = readFileSync(path, 'utf8');
    const mtimeMs = statSync(path).mtimeMs;
    const cur = openDocs.get(uri);
    if (!cur) {
      const languageId = langId(path);
      lspNotify('textDocument/didOpen', {
        textDocument: { uri, languageId, version: 1, text }
      });
      openDocs.set(uri, { version: 1, languageId, mtimeMs });
    } else if (cur.mtimeMs !== mtimeMs) {
      cur.version += 1;
      cur.mtimeMs = mtimeMs;
      lspNotify('textDocument/didChange', {
        textDocument: { uri, version: cur.version },
        contentChanges: [{ text }]
      });
    }
    return { uri, path };
  }

  function fmtLoc(loc) {
    const f = loc.uri.replace(rootUri + '/', '');
    const r = loc.range;
    return `${f}:${r.start.line + 1}:${r.start.character + 1}`;
  }

  async function handle(req) {
    const { op, args = [], cwd } = req;
    if (op === 'stop') { setTimeout(() => process.exit(0), 50); return { ok: true }; }
    if (op === 'warmup') {
      // Force project load by issuing a workspace symbol query.
      const r = await lspRequest('workspace/symbol', { query: '_' });
      return { lines: [`warmup done; ${(r.result || []).length} symbols sampled`] };
    }
    if (op === 'hover' || op === 'def' || op === 'refs') {
      const [file, line, col] = args;
      if (!file || !line || !col) throw new Error('need <file> <line> <col>');
      const { uri } = ensureOpen(file, cwd);
      const position = { line: +line - 1, character: +col - 1 };
      if (op === 'hover') {
        const r = await lspRequest('textDocument/hover', { textDocument: { uri }, position });
        const c = r.result?.contents;
        let text;
        if (!c) text = '(no hover)\n';
        else if (typeof c === 'string') text = c + '\n';
        else if (Array.isArray(c)) text = c.map(x => typeof x === 'string' ? x : x.value).join('\n') + '\n';
        else text = (c.value || '') + '\n';
        return { text };
      }
      if (op === 'def') {
        const r = await lspRequest('textDocument/definition', { textDocument: { uri }, position });
        const defs = r.result || [];
        return { lines: (Array.isArray(defs) ? defs : [defs]).map(fmtLoc) };
      }
      // refs
      const r = await lspRequest('textDocument/references', {
        textDocument: { uri }, position, context: { includeDeclaration: false }
      });
      return { lines: (r.result || []).map(fmtLoc) };
    }
    if (op === 'symbols') {
      const [file] = args;
      if (!file) throw new Error('need <file>');
      const { uri } = ensureOpen(file, cwd);
      const r = await lspRequest('textDocument/documentSymbol', { textDocument: { uri } });
      const lines = [];
      const KIND = { 5: 'class', 6: 'method', 9: 'constructor', 11: 'interface', 12: 'function', 13: 'var', 14: 'const', 22: 'enum-member' };
      const walk = (s, depth = 0) => {
        const rng = s.range || s.location?.range;
        const ln = rng ? rng.start.line + 1 : '?';
        const k = KIND[s.kind] ? `[${KIND[s.kind]}] ` : (s.kind ? `[${s.kind}] ` : '');
        lines.push(`${'  '.repeat(depth)}${k}${s.name} (line ${ln})`);
        (s.children || []).forEach(c => walk(c, depth + 1));
      };
      (r.result || []).forEach(s => walk(s));
      return { lines };
    }
    if (op === 'wsymbols') {
      const [query] = args;
      if (!query) throw new Error('need <query>');
      const r = await lspRequest('workspace/symbol', { query });
      return { lines: (r.result || []).slice(0, 60).map(s => `${s.name}  ${fmtLoc(s.location)}`) };
    }
    throw new Error(`unknown op: ${op}`);
  }

  // Activity tracking. `touch()` bumps the idle clock and refreshes the sidecar
  // state file the client's LRU cap reads (lastActivity is the eviction key).
  const sidecar = statePath(sock);
  let lastActivity = Date.now();
  const writeState = () => {
    try { writeFileSync(sidecar, JSON.stringify({ root: rootAbs, pid: process.pid, lastActivity })); } catch {}
  };
  const touch = () => { lastActivity = Date.now(); writeState(); };

  // Idle timeout.
  setInterval(() => {
    if (Date.now() - lastActivity > IDLE_TIMEOUT_MS) {
      try { lsp.kill(); } catch {}
      process.exit(0);
    }
  }, 60_000).unref();

  // Socket server.
  const server = createServer((conn) => {
    touch();
    let lineBuf = '';
    conn.on('data', (d) => {
      lineBuf += d.toString('utf8');
      const nl = lineBuf.indexOf('\n');
      if (nl === -1) return;
      const line = lineBuf.slice(0, nl);
      lineBuf = '';
      let req;
      try { req = JSON.parse(line); }
      catch { conn.end(JSON.stringify({ error: 'bad json' })); return; }
      handle(req).then((res) => {
        touch();
        conn.end(JSON.stringify(res));
      }).catch((err) => {
        conn.end(JSON.stringify({ error: err.message || String(err) }));
      });
    });
    conn.on('error', () => {});
  });
  server.listen(sock, () => {
    try { chmodSync(sock, 0o600); } catch {}
    writeState();
  });

  const cleanup = () => {
    try { unlinkSync(sock); } catch {}
    try { unlinkSync(sidecar); } catch {}
    try { lsp.kill(); } catch {}
  };
  process.on('SIGINT', () => { cleanup(); process.exit(0); });
  process.on('SIGTERM', () => { cleanup(); process.exit(0); });
  process.on('exit', cleanup);

  // Background warmup so first user query is fast.
  setTimeout(() => {
    lspRequest('workspace/symbol', { query: '_' }).catch(() => {});
  }, 250);
}

// ---------------- entry ----------------

const argv = process.argv.slice(2);
if (argv[0] === '--daemon') {
  const root = argv[1];
  if (!root) { console.error('--daemon needs <root>'); process.exit(2); }
  daemonMain(root).catch((e) => { console.error(e); process.exit(1); });
} else {
  clientMain(argv).catch((e) => { console.error(e); process.exit(1); });
}
