#!@node@
// flowgraph — diff-scoped FE→GraphQL→BE→DB flow diagram for a TypeScript monorepo.
//
// By default it diffs merge-base(main, HEAD) → WORKING TREE (committed + staged +
// unstaged + untracked), so an in-progress worktree with no commits past base
// still maps. Pass --head <ref> to compare two commits instead. Then it:
//   1. finds changed files + changed line ranges
//   2. classifies each into a layer (frontend / gql / resolver / service / async / data ...)
//   3. extracts GraphQL operations (name + root field) from gql`...` literals
//   4. bridges each operation's root field to its `Query.<field>` / `Mutation.<field>` resolver
//   5. walks resolver → services / inngest jobs / prisma / drizzle (data)
//   6. (optional) uses `tsq refs` for type-aware blast-radius on changed exported symbols
//   7. emits a Mermaid flowchart (layered subgraphs) with changed nodes highlighted
//
// Usage:
//   flowgraph [--root <dir>] [--base <ref>] [--head <ref>] [--out <file>]
//             [--no-refs] [--json] [--print]
//
// Defaults: root = git toplevel of CWD; base = merge-base(main, HEAD); head = HEAD;
//           out = <root>/.flowgraph/pr-flow.md
//
// Depends on: git, ripgrep (rg), (optional) tsq on PATH, and — for --pdf/--open —
// mermaid-cli (mmdc) + a PDF viewer (zathura, else xdg-open).
//
// ───────────────────────────────────────────────────────────────────────────
// WHY THIS EXISTS (and why it's grep-and-regex instead of a clean LSP walk)
// ───────────────────────────────────────────────────────────────────────────
// The one edge an LSP cannot follow is frontend gql operation → backend resolver.
// They live in different files with NO TypeScript reference between them: the
// client ships a `gql` *string* that is matched to the schema at runtime. That
// decoupling is GraphQL working as designed (the client doesn't import the
// server), not a defect — but it means `go-to-definition` dead-ends at the query.
//
// The link still exists deterministically in the source: an operation's ROOT
// SELECTION FIELD has the same name as the resolver map key. So step 4 rebuilds
// the severed edge by name-matching — extract the root field, grep for the
// resolver key. That string match is inherent to GraphQL; it is not avoidable
// without leaving GraphQL (e.g. tRPC / server functions, where the client
// imports the server and the whole chain is a real TS type — no bridge needed).
//
// Everything that ISN'T the boundary match is grep/regex for a softer reason:
// resolvers here are anonymous functions inside an object literal
// (`Query: { field: combineResolvers(...) }`), so the field is a *string key*,
// not a TS symbol — `tsq` can't locate it and we fall back to rg + brace
// balancing. Were resolvers named, individually-exported, codegen-typed
// functions (`export const field: QueryResolvers['field'] = ...`), steps 4–5
// could use `tsq def/refs` directly and most of this file would evaporate.
//
// Conventions below are tuned to covenant-web (Apollo `gql`, `combineResolvers`,
// `@/services/*`, prisma + drizzle). The diff→bridge→emit skeleton is generic;
// the recognizers are the part you'd retune for another codebase.

import { execFileSync, spawn } from 'node:child_process';
import { readFileSync, existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { resolve, join, dirname, basename, relative } from 'node:path';
import { createRequire } from 'node:module';

const RG = '@rg@';
const TSQ = '@tsq@';
const MMDC = '@mmdc@'; // mermaid-cli, for --pdf / --open

// ---------------- args ----------------

function parseArgs(argv) {
  const a = { refs: true, json: false, print: false };
  for (let i = 0; i < argv.length; i++) {
    const k = argv[i];
    if (k === '--root') a.root = argv[++i];
    else if (k === '--base') a.base = argv[++i];
    else if (k === '--head') a.head = argv[++i];
    else if (k === '--out') a.out = argv[++i];
    else if (k === '--no-refs') a.refs = false;
    else if (k === '--json') a.json = true;
    else if (k === '--print') a.print = true;
    else if (k === '--pdf') a.pdf = true;
    else if (k === '--open') a.open = true;
    else if (k === '-h' || k === '--help') { a.help = true; }
    // Fail loud on unknown flags. A silently-ignored flag (e.g. running --open
    // against a stale binary that predates it) looks like "it did nothing".
    else if (k.startsWith('-')) { console.error(`flowgraph: unknown flag '${k}' (see --help)`); process.exit(2); }
    else if (!a.root) a.root = k;
  }
  return a;
}

const USAGE = `flowgraph — diff-scoped FE→GraphQL→BE→DB flow diagram

usage: flowgraph [--root <dir>] [--base <ref>] [--head <ref>] [--out <file>]
                 [--no-refs] [--json] [--print] [--pdf] [--open]

  --root   repo root (default: git toplevel of CWD)
  --base   base ref (default: merge-base(main, HEAD))
  --head   head ref (default: HEAD; omitted → working tree incl. untracked)
  --out    output markdown file (default: <root>/.flowgraph/pr-flow.md)
  --no-refs  skip tsq blast-radius (faster, no LSP)
  --json   also write <out>.json with the raw graph
  --print  print the Mermaid to stdout as well
  --pdf    also render <out>.pdf via mermaid-cli (Chromium)
  --open   render the PDF and open it (zathura, else xdg-open)
`;

// ---------------- shell helpers ----------------

function git(root, args) {
  return execFileSync('git', ['-C', root, ...args], { encoding: 'utf8', maxBuffer: 1 << 28 });
}
function gitSafe(root, args) {
  try { return git(root, args); } catch { return ''; }
}
function rg(root, args) {
  try {
    // stdin: 'ignore' — otherwise rg reads the (empty) pipe instead of the tree.
    return execFileSync(RG, args, { cwd: root, encoding: 'utf8', maxBuffer: 1 << 28, stdio: ['ignore', 'pipe', 'pipe'] });
  } catch (e) {
    // rg exits 1 when no matches — that's not an error for us.
    return '';
  }
}
function tsq(root, args) {
  try {
    return execFileSync(TSQ, args, { cwd: root, encoding: 'utf8', maxBuffer: 1 << 26, timeout: 20000, stdio: ['ignore', 'pipe', 'pipe'] });
  } catch { return ''; }
}

// Blocking sleep (no async in the main flow).
function sleep(ms) { Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms); }

// Block until vtsls has actually loaded the project, rather than guessing a settle
// time. `warmup` issues a workspace/symbol query and reports "… N symbols sampled";
// N stays 0 until indexing finishes. Polling N>0 is a real readiness barrier — the
// first real `refs` then can't race the index and return a cold empty. That race was
// the source of nondeterministic blast counts (2 links one run, 3 the next), since
// an empty ref list is indistinguishable from "no callers" and gets dropped. Bounded
// (~15s) so a genuinely empty workspace can't hang us.
function waitForIndex(root, { tries = 30, waitMs = 500 } = {}) {
  for (let i = 0; i < tries; i++) {
    const m = tsq(root, ['warmup']).match(/(\d+)\s+symbols sampled/);
    if (m && +m[1] > 0) return true;
    sleep(waitMs);
  }
  return false;
}

// ---------------- diff ----------------

// Untracked, non-ignored files — the brand-new files in an in-progress worktree
// that `git diff` never shows (they aren't tracked yet, so there's nothing to
// diff against). --exclude-standard drops .gitignore'd paths (node_modules etc.).
function untrackedFiles(root) {
  return gitSafe(root, ['ls-files', '--others', '--exclude-standard'])
    .split('\n').map((s) => s.trim()).filter(Boolean);
}

function changedFiles(root, base, head) {
  // --name-status is immune to external diff drivers (it's not a content diff),
  // so the file list survives even on repos configured with difftastic/delta —
  // unlike changedRanges() below, which needs the real unified-diff body.
  // head === null → working-tree mode: diff base→worktree (committed + staged +
  // unstaged) AND fold in untracked files, so an in-progress branch with zero
  // commits past base still maps. With a clean tree this equals base..HEAD.
  const diffArgs = ['diff', '--no-ext-diff', '--no-color', '--name-status', base];
  if (head) diffArgs.push(head);
  const out = gitSafe(root, diffArgs);
  const files = [];
  for (const line of out.split('\n')) {
    if (!line.trim()) continue;
    const m = line.match(/^([A-Z])\d*\t(.+)$/);
    if (!m) continue;
    let [, status, path] = m;
    // renames: "R100\told\tnew"
    if (status === 'R') {
      const parts = line.split('\t');
      path = parts[parts.length - 1];
    }
    files.push({ status, path });
  }
  if (!head) for (const p of untrackedFiles(root)) files.push({ status: 'A', path: p });
  return files;
}

// changed line ranges per file (added/modified lines on the head side)
function changedRanges(root, base, head) {
  // --no-ext-diff is load-bearing: with difftastic (or delta) as the configured
  // diff driver, plain `git diff` emits pretty structural output with NO `@@`
  // hunk headers, so this parses to empty ranges — and blast-radius silently
  // produces nothing (changedSymbols bails on empty ranges). --no-color keeps the
  // hunk headers clean. The `(?:b/)?` below also tolerates diff.noprefix=true.
  const diffArgs = ['diff', '--no-ext-diff', '--no-color', '--unified=0', base];
  if (head) diffArgs.push(head); // omit → base vs working tree (staged + unstaged)
  const out = gitSafe(root, diffArgs);
  const map = new Map();
  let cur = null;
  for (const line of out.split('\n')) {
    const fm = line.match(/^\+\+\+ (?:b\/)?(.+)$/);
    if (fm) { cur = fm[1] === '/dev/null' ? null : fm[1]; if (cur && !map.has(cur)) map.set(cur, []); continue; }
    const hm = line.match(/^@@ -\d+(?:,\d+)? \+(\d+)(?:,(\d+))? @@/);
    if (hm && cur) {
      const start = +hm[1];
      const count = hm[2] === undefined ? 1 : +hm[2];
      if (count > 0) map.get(cur).push([start, start + count - 1]);
    }
  }
  // Untracked new files aren't in the diff — treat the whole file as changed so
  // blast-radius (which keys off ranges) still considers their exported symbols.
  if (!head) for (const p of untrackedFiles(root)) {
    const abs = join(root, p);
    if (!map.has(p) && existsSync(abs)) {
      const n = readFileSync(abs, 'utf8').split('\n').length;
      map.set(p, [[1, Math.max(n, 1)]]);
    }
  }
  return map;
}

// Exported top-level symbols whose declaration line falls in a changed range.
// Regex-based on PURPOSE: box-label annotations must work cold and under
// --no-refs, so they can't depend on a warm vtsls index the way the tsq-based
// changedSymbols() (blast-radius) does. Catches the shapes that carry meaning in
// a PR — `export [default] [async] function f`, `export const/class/interface/
// type/enum X`. Barrel re-exports (`export { x } from './y'`) match no keyword
// and yield nothing, which is correct: a barrel has no symbols of its own, so it
// stays an unannotated box and naturally recedes.
function changedSymbolNames(content, ranges) {
  if (!content || !ranges || !ranges.length) return [];
  const inRange = (ln) => ranges.some(([a, b]) => ln >= a && ln <= b);
  const re = /^export\s+(?:default\s+)?(?:async\s+)?(?:function\s+([A-Za-z0-9_]+)|(?:const|let|var|class|interface|type|enum)\s+([A-Za-z0-9_]+))/;
  const names = [];
  const lines = content.split('\n');
  for (let i = 0; i < lines.length; i++) {
    const m = lines[i].match(re);
    if (!m) continue;
    const name = m[1] || m[2];
    if (name && inRange(i + 1)) names.push(name);
  }
  return [...new Set(names)];
}

// ---------------- layer classification ----------------

// Order matters: more-specific directory roles win before the .tsx catch-all.
// A resolver can legitimately be a .tsx file (e.g. resolvers/admin/organization.tsx),
// so `/resolvers/` must be tested before the trailing `.tsx → frontend` rule.
function classify(path, content) {
  const p = path.replace(/\\/g, '/');
  if (/\/generated\//.test(p)) return 'generated';
  if (/\/__tests__\/|\.test\.|\.spec\./.test(p)) return 'test';
  if (/\/resolvers\//.test(p)) return 'resolver';
  if (/\/schema\//.test(p)) return 'schema';
  if (/\/inngest\//.test(p)) return 'async';
  if (/\/services\//.test(p)) return 'service';
  if (/\/(prisma|drizzle|dataloaders)\//.test(p)) return 'data';
  if (/\/gql\/|\/queries(\.|\/)/.test(p) || /\bgql`/.test(content || '')) return 'gql';
  if (/\/scripts\//.test(p)) return 'script';
  if (/\/(components|features|hooks|app)\//.test(p) || /\.tsx$/.test(p)) return 'frontend';
  return 'lib';
}

// ---------------- gql operation extraction ----------------

// Parse gql documents with the real `graphql` parser, resolved from the TARGET
// repo (these tools only run on GraphQL TS monorepos, which always have it — and
// matching the repo's exact version is a feature, not a liability). The brace-counter
// that used to live here reimplemented `parse()` by hand and got aliases, fragments,
// and directives wrong; the AST gets them right. We keep a regex fallback for the
// rare repo where `graphql` can't be resolved, consistent with the degrade-gracefully
// spine elsewhere (tsq-free, ext-diff-free).
function loadGraphql(root) {
  try { return createRequire(join(root, 'package.json'))('graphql'); }
  catch { return null; }
}

// Returns [{ constName, opKind, opName, rootFields:[...], file }]
function extractOps(content, file, gql) {
  const ops = [];
  // TS-level locator: find each `gql`…`` template and its optional const name.
  // Locating the literal is a source-text job; interpreting its body is the GraphQL
  // parser's job (parseOps). Same `[\s\S]*?` non-greedy capture to the closing backtick.
  const re = /(?:export\s+const\s+([A-Za-z0-9_]+)\s*[:=][^=]*?)?gql`([\s\S]*?)`/g;
  let m;
  while ((m = re.exec(content))) {
    const constName = m[1] || null;
    for (const op of parseOps(gql, m[2])) ops.push({ constName, ...op, file });
  }
  return ops;
}

// One gql body → [{ opKind, opName, rootFields }]. We key the bridge on the ROOT
// FIELD, not opName: the resolver map is keyed by schema field (`Query: { investments:
// ... }`) while opName is free-form (`GetInvestmentsWithDimensions`) and rarely matches
// — the root field is the only reliable join key, and one op can select several.
function parseOps(gql, body) {
  if (gql) {
    // gql`` literals routinely interpolate composed fragments (`...${FRAG}`), which is
    // invalid GraphQL and makes parse() throw. Drop interpolated spreads, then blank any
    // remaining ${…}; on any residual parse error, fall through to the regex scanner.
    const cleaned = body
      .replace(/\.\.\.\s*\$\{[^}]*\}/g, '')
      .replace(/\$\{[^}]*\}/g, '');
    try {
      const out = [];
      for (const def of gql.parse(cleaned, { noLocation: true }).definitions) {
        if (def.kind !== 'OperationDefinition') continue;
        const rootFields = [...new Set(
          def.selectionSet.selections.filter(s => s.kind === 'Field').map(s => s.name.value)
        )];
        out.push({ opKind: def.operation, opName: def.name?.value || '(anon)', rootFields });
      }
      if (out.length) return out;
    } catch { /* fall through to regex */ }
  }
  return parseOpsRegex(body);
}

// Regex fallback for when `graphql` can't be resolved. Less correct on aliases /
// fragments / directives, but keeps the FE→resolver bridge working dependency-free.
function parseOpsRegex(body) {
  const om = body.match(/\b(query|mutation|subscription)\b\s+([A-Za-z0-9_]+)?\s*(\([\s\S]*?\))?\s*\{/);
  if (!om) return [];
  const braceIdx = body.indexOf('{', om.index);
  return [{ opKind: om[1], opName: om[2] || '(anon)', rootFields: topLevelFields(body.slice(braceIdx)) }];
}

// Given a string starting at the operation's `{`, return the field names at depth 1.
function topLevelFields(s) {
  const fields = [];
  let depth = 0;
  let i = 0;
  // skip to first {
  while (i < s.length && s[i] !== '{') i++;
  i++; depth = 1;
  let expectField = true;
  while (i < s.length && depth > 0) {
    const c = s[i];
    if (c === '{') { depth++; i++; expectField = false; continue; }
    if (c === '}') { depth--; i++; expectField = (depth === 1); continue; }
    if (depth === 1 && expectField && /[A-Za-z_]/.test(c)) {
      const idm = s.slice(i).match(/^([A-Za-z0-9_]+)/);
      if (idm) {
        fields.push(idm[1]);
        i += idm[1].length;
        // skip aliases / args / until we hit the next sibling selection-set or field
        expectField = false;
        continue;
      }
    }
    // a newline at depth 1 means the next identifier is a new sibling field
    if (depth === 1 && c === '\n') expectField = true;
    i++;
  }
  // de-dup, drop graphql noise
  return [...new Set(fields)].filter(f => !['fragment', 'on'].includes(f));
}

// ---------------- bridge: root field -> resolver ----------------

function findResolverForField(root, field) {
  // This is THE boundary bridge (see header). It's a grep, not an LSP call,
  // because the resolver field is a string key in an object literal, not a symbol.
  // Resolvers use `field: combineResolvers(` overwhelmingly; fall back to the
  // bare `field:` shapes. Patterns are tried in order; first non-empty wins.
  const hits = [];
  const patterns = [
    `^\\s*${field}\\s*:\\s*combineResolvers`,
    `^\\s*${field}\\s*:\\s*(async\\s*)?\\(`,
    `^\\s*${field}\\s*:\\s*(async\\s+)?function`,
  ];
  for (const pat of patterns) {
    // NB: multiple `-g` globs OR together (inclusion), they do NOT AND. So scope
    // to the resolvers tree with the include glob and only *subtract* tests with
    // `!` excludes — adding `-g '*.ts'` here would WIDEN the search to every .ts
    // in the repo, not narrow it to .ts within resolvers/.
    const out = rg(root, ['-n', '--no-heading', '-g', '**/resolvers/**', '-g', '!**/*.test.ts', '-g', '!**/*.test.tsx', '-e', pat, '.']);
    for (const line of out.split('\n')) {
      const m = line.match(/^(.+?):(\d+):/);
      if (m) hits.push({ file: m[1], line: +m[2] });
    }
    if (hits.length) break;
  }
  // de-dup by file:line
  const seen = new Set();
  return hits.filter(h => { const k = `${h.file}:${h.line}`; if (seen.has(k)) return false; seen.add(k); return true; });
}

// ---------------- resolver / job downstream scan ----------------

// Extract the balanced (…) / {…} block that is a resolver field's value, starting at fromLine.
// Lets us attribute downstream calls to the *specific* field rather than the whole file.
function fieldBlock(content, fromLine) {
  const lines = content.split('\n');
  const s = lines.slice(fromLine - 1).join('\n');
  const isOpen = (c) => c === '(' || c === '[' || c === '{';
  const isClose = (c) => c === ')' || c === ']' || c === '}';
  let i = 0;
  while (i < s.length && !isOpen(s[i])) i++;
  if (i >= s.length) return s.slice(0, 4000);
  const start = i;
  let end = i;
  // Stitch consecutive balanced groups of the same construct, e.g. `() => { … }`
  // or `function f() { … }`, so a param list doesn't end the capture early.
  while (i < s.length && isOpen(s[i])) {
    let depth = 0;
    for (; i < s.length; i++) {
      if (isOpen(s[i])) depth++;
      else if (isClose(s[i])) { if (--depth === 0) { i++; break; } }
    }
    end = i;
    let k = i;
    while (k < s.length && /[\s=>:,]/.test(s[k])) k++; // bridge `=>`, `:`, `,`, whitespace
    if (k < s.length && isOpen(s[k])) { i = k; continue; }
    break;
  }
  return s.slice(start, end);
}

// Scan a file (or a single field's block) for downstream targets:
// services, inngest jobs, prisma/drizzle data.
//
// The split — imports resolved from the WHOLE file, calls detected only within
// `region` (the field block) — is deliberate. File-level call detection
// over-attributes: a read query in the same file as a mutation would inherit the
// mutation's `inngest.send`, drawing a job edge off a query that never triggers
// one. Field-scoping fixes that. The one-level local-helper hop below then
// recovers the opposite failure (a field that delegates its db call to a
// same-file helper), so we under-attribute neither. Imports stay file-level
// because the `import { foo } from '@/services/x'` line is at the top, not in
// the field body — we just gate it on whether the body references the binding.
function scanDownstream(root, file, fromLine) {
  const abs = join(root, file);
  if (!existsSync(abs)) return { services: [], jobs: [], data: [] };
  const content = readFileSync(abs, 'utf8');
  let region = fromLine ? fieldBlock(content, fromLine) : content;

  // Follow one level of local-helper indirection: a resolver field often delegates
  // to a same-file function (e.g. `fetchStats()`), where the real db/service call lives.
  if (fromLine) {
    const localFns = new Map(); // name -> decl line
    const declRe = /(?:^|\n)\s*(?:export\s+)?(?:async\s+)?(?:function\s+([A-Za-z0-9_]+)|const\s+([A-Za-z0-9_]+)\s*=\s*(?:async\s*)?\()/g;
    let dm;
    while ((dm = declRe.exec(content))) {
      const name = dm[1] || dm[2];
      const line = content.slice(0, dm.index).split('\n').length;
      if (name) localFns.set(name, line);
    }
    const called = new Set([...region.matchAll(/\b([A-Za-z0-9_]+)\s*\(/g)].map(m => m[1]));
    for (const name of called) {
      if (localFns.has(name)) region += '\n' + fieldBlock(content, localFns.get(name));
    }
  }

  const services = new Set();
  const jobs = new Set();
  const data = new Set();

  // map imported binding name -> module specifier, for services and inngest fns
  const importBindings = (reTail) => {
    const out = [];
    const re = new RegExp(`import\\s+(?:\\{([^}]+)\\}|([A-Za-z0-9_]+))\\s+from\\s+['"]([^'"]*${reTail}[^'"]+)['"]`, 'g');
    for (const m of content.matchAll(re)) {
      const spec = m[3];
      const names = m[1] ? m[1].split(',').map(s => s.trim().split(/\s+as\s+/).pop()) : [m[2]];
      for (const n of names) if (n) out.push({ name: n, spec });
    }
    return out;
  };

  // services actually referenced in the region
  for (const b of importBindings('services\\/')) {
    if (new RegExp(`\\b${b.name}\\b`).test(region)) services.add(b.spec);
  }

  // inngest job triggers, scoped to region
  if (/inngest\.send\s*\(|\.createFunction\s*\(/.test(region)) {
    const fns = importBindings('inngest\\/functions\\/');
    const matched = fns.filter(b => new RegExp(`\\b${b.name}\\b`).test(region));
    if (matched.length) matched.forEach(b => jobs.add(b.spec));
    else if (fns.length) fns.forEach(b => jobs.add(b.spec));
    else jobs.add('inngest.send(…)');
  }

  // prisma.<model>.<verb>(  — scoped to region
  for (const m of region.matchAll(/\bprisma\.([A-Za-z0-9_]+)\.[A-Za-z0-9_]+\s*\(/g)) {
    data.add(`prisma:${m[1]}`);
  }
  // drizzle: db.<verb> / sql`  — region usage, tables from file-level drizzle imports
  if (/\bdb\.[A-Za-z0-9_]+|\bsql`/.test(region)) {
    const tables = [];
    for (const m of content.matchAll(/import\s*\{([^}]+)\}\s*from\s*['"]@\/lib\/drizzle[^'"]*['"]/g)) {
      for (const name of m[1].split(',').map(s => s.trim()).filter(Boolean)) {
        if (/^[a-z][A-Za-z0-9_]*$/.test(name) && new RegExp(`\\b${name}\\b`).test(region)) tables.push(name);
      }
    }
    if (tables.length) tables.forEach(t => data.add(`drizzle:${t}`));
    else data.add('drizzle:db');
  }
  return { services: [...services], jobs: [...jobs], data: [...data] };
}

// ---------------- tsq blast-radius ----------------

// For a changed file, return exported top-level symbols whose decl line falls in a changed range.
function changedSymbols(root, file, ranges) {
  if (!ranges || !ranges.length) return [];
  const out = tsq(root, ['symbols', file]);
  if (!out) return [];
  const abs = join(root, file);
  const lines = existsSync(abs) ? readFileSync(abs, 'utf8').split('\n') : [];
  const syms = [];
  for (const l of out.split('\n')) {
    // top-level only (no leading indent), format: "[kind] name (line N)"
    const m = l.match(/^\[(class|function|const|interface|method)\]\s+([A-Za-z0-9_]+)\s+\(line (\d+)\)/);
    if (!m) continue;
    const [, kind, name, lnStr] = m;
    const ln = +lnStr;
    if (!ranges.some(([a, b]) => ln >= a && ln <= b)) continue;
    // only if exported (cheap check on the decl line)
    const src = lines[ln - 1] || '';
    if (!/\bexport\b/.test(src)) continue;
    const col = src.indexOf(name) + 1;
    if (col < 1) continue;
    syms.push({ name, kind, line: ln, col });
  }
  return syms;
}

function refsFor(root, file, sym, cap = 8) {
  // waitForIndex (in the blast loop) is the real barrier against vtsls's
  // index-not-ready empties; this single retry is just a backstop for a residual
  // cold miss. A genuinely uncalled symbol also returns empty, so it costs one
  // extra ~1.2s probe on those — acceptable.
  let out = tsq(root, ['refs', file, String(sym.line), String(sym.col)]);
  if (!out.trim()) { sleep(1200); out = tsq(root, ['refs', file, String(sym.line), String(sym.col)]); }
  if (!out) return [];
  const callers = [];
  for (const l of out.split('\n')) {
    const m = l.match(/^(.+?):(\d+):(\d+)$/);
    if (!m) continue;
    if (m[1] === file) continue; // skip self-file
    callers.push(m[1]);
  }
  // Sort before slicing: node IDs are assigned in insertion order, so returning
  // callers in vtsls's arbitrary order would renumber the graph run to run. A
  // stable sort also makes the cap deterministic (same `cap` callers every time).
  return [...new Set(callers)].sort().slice(0, cap);
}

// ---------------- mermaid emit ----------------

const LAYER_ORDER = ['frontend', 'gql', 'schema', 'resolver', 'async', 'service', 'data', 'script', 'lib', 'generated', 'test'];
const LAYER_TITLE = {
  frontend: 'Frontend', gql: 'GraphQL ops', schema: 'Schema (SDL)', resolver: 'Resolvers',
  async: 'Async / Inngest', service: 'Services', data: 'Data (Prisma / Drizzle)',
  script: 'Scripts', lib: 'Lib', generated: 'Generated', test: 'Tests',
};

let _id = 0;
const idCache = new Map();
function nid(key) {
  if (idCache.has(key)) return idCache.get(key);
  const id = `n${_id++}`;
  idCache.set(key, id);
  return id;
}
function esc(s) { return String(s).replace(/"/g, "'").replace(/[\[\]{}|]/g, ' '); }

// A changed-file box label: filename + churn badge + the changed exported
// symbols (capped, with "+N more"). This is what turns a box from "which file"
// into "what changed inside it". `\n` line-breaks render in Mermaid node text
// (same trick the resolver box already uses). Only changed files carry symbols/
// churn; downstream-only nodes fall back to a bare basename via their own
// addNode calls (which never overwrite this richer label, since the changed-file
// loop runs first and addNode is set-once on label).
const SYM_CAP = 4;
function fileLabel(f) {
  const head = f.churn ? `${basename(f.path)}  Δ${f.churn}` : basename(f.path);
  const syms = f.symbols || [];
  const shown = syms.slice(0, SYM_CAP);
  let label = head;
  if (shown.length) label += '\n' + shown.join('\n');
  if (syms.length > shown.length) label += `\n+${syms.length - shown.length} more`;
  return label;
}

function buildGraph(model) {
  const nodes = new Map(); // key -> {id, label, layer, changed}
  const edges = []; // {from, to, dashed, label}

  function addNode(key, label, layer, changed) {
    if (!nodes.has(key)) nodes.set(key, { id: nid(key), label, layer, changed: !!changed });
    else if (changed) nodes.get(key).changed = true;
    return nodes.get(key);
  }
  const edgePairs = new Set(); // ordered from→to ids already connected, for dedup
  function addEdge(fromKey, toKey, opts = {}) {
    const from = nodes.get(fromKey)?.id, to = nodes.get(toKey)?.id;
    edges.push({ from, to, ...opts });
    if (from && to) edgePairs.add(`${from}->${to}`);
  }
  // Node identity is the file path, so a downstream target and a changed-file
  // node for the SAME file collapse into one. Keying nodes by spec instead would
  // draw each touched file twice: once highlighted-but-floating (the changed-file
  // node) and once connected-but-grey (the `svc:@/...` logical node). Resolving
  // the spec back to its path merges them into a single connected, highlighted node.
  // Unresolvable specs (no file on disk) keep a spec key so they still show.
  function svcNode(spec) {
    const file = resolveSpecFile(model.root, spec);
    const key = file ? `file:${file}` : `svc:${spec}`;
    addNode(key, basename(file || spec), 'service', file ? model.changedPaths.has(file) : false);
    return key;
  }
  function jobNode(spec) {
    const file = /inngest\/functions\//.test(spec) ? resolveSpecFile(model.root, spec) : null;
    const key = file ? `file:${file}` : `job:${spec}`;
    addNode(key, basename(file || spec), 'async', file ? model.changedPaths.has(file) : false);
    return key;
  }

  // changed-file nodes
  for (const f of model.files) {
    const key = `file:${f.path}`;
    addNode(key, fileLabel(f), f.layer, true);
  }

  // operations + bridge
  for (const op of model.ops) {
    const opKey = `op:${op.opName}`;
    addNode(opKey, `${op.opKind} ${op.opName}`, 'gql', op.changed);
    // FE -> op
    for (const fe of op.usedBy || []) {
      const feKey = `file:${fe}`;
      if (nodes.has(feKey)) addEdge(feKey, opKey, { label: 'uses' });
    }
    // op file -> op (if the gql file itself is changed and distinct)
    if (op.file) {
      const fk = `file:${op.file}`;
      if (nodes.has(fk) && nodes.get(fk).layer !== 'gql') { /* skip */ }
    }
    // op -> resolver
    for (const r of op.resolvers || []) {
      const rKey = `res:${r.file}#${r.field}`;
      addNode(rKey, `${r.field}\n(${basename(r.file)})`, 'resolver', model.changedPaths.has(r.file));
      addEdge(opKey, rKey, { dashed: true, label: r.field });
      // resolver downstream
      const d = r.downstream || { services: [], jobs: [], data: [] };
      for (const s of d.services) addEdge(rKey, svcNode(s));
      for (const j of d.jobs) {
        const jk = jobNode(j);
        addEdge(rKey, jk, { label: 'inngest' });
        // job downstream (one hop into the async job's services)
        const jd = model.jobDownstream?.[j];
        if (jd) for (const s of jd.services) addEdge(jk, svcNode(s));
      }
      for (const dt of d.data) {
        const dk = `data:${dt}`;
        addNode(dk, dt, 'data', false);
        addEdge(rKey, dk);
      }
    }
  }

  // blast-radius caller edges
  for (const br of model.blast || []) {
    const targetKey = `file:${br.file}`;
    for (const caller of br.callers) {
      // Key by `file:` when the caller exists on disk so it collapses into the
      // changed-file node for the same path (same merge svcNode/jobNode do). Else a
      // caller that is ALSO a changed file draws twice: a floating highlighted node
      // here plus its connected changed-file node. Off-disk callers keep `caller:`.
      const ck = existsSync(join(model.root, caller)) ? `file:${caller}` : `caller:${caller}`;
      addNode(ck, basename(caller), classify(caller, ''), model.changedPaths.has(caller));
      addEdge(ck, targetKey, { label: `→ ${br.sym}`, dashed: true });
    }
  }

  // import edges — a changed file → another changed file it statically imports.
  // Pure parse, no LSP: the structural backbone that connects a PR even when it has
  // no GraphQL and refs are off or the index is cold (the webhook route→service←test
  // case). Skipped when a labeled blast edge already links the pair — that edge
  // carries the symbol, so the bare import line would just be visual duplication.
  for (const ie of model.imports || []) {
    const fromId = nodes.get(`file:${ie.from}`)?.id;
    const toId = nodes.get(`file:${ie.to}`)?.id;
    if (!fromId || !toId || edgePairs.has(`${fromId}->${toId}`)) continue;
    addEdge(`file:${ie.from}`, `file:${ie.to}`);
  }

  return { nodes, edges };
}

// Map a node key back to the repo-relative path it represents, so we can look up
// its git status. `file:` nodes are the path; `res:file#field` resolver nodes
// carry their file before the `#`. Everything else (op:/data:/job:/svc: logical
// nodes) has no path → treated as a plain modified-bucket node.
function pathFromKey(key) {
  if (key.startsWith('file:')) return key.slice(5);
  if (key.startsWith('res:')) return key.slice(4).split('#')[0];
  return null;
}

// Status → bucket. The whole point of #1: since "changed" is constant across the
// graph, spend the color channel on something that discriminates — new vs touched
// vs renamed vs deleted.
const STATUS_BUCKET = { A: 'added', M: 'modified', R: 'renamed', D: 'deleted' };
const STATUS_LABEL = { added: 'new file', modified: 'modified', renamed: 'renamed', deleted: 'deleted' };
const STATUS_DEF = {
  added: 'fill:#66bb6a,stroke:#2e7d32,stroke-width:2px,color:#000',
  modified: 'fill:#f9a825,stroke:#e65100,stroke-width:2px,color:#000',
  renamed: 'fill:#42a5f5,stroke:#1565c0,stroke-width:2px,color:#000',
  deleted: 'fill:#bdbdbd,stroke:#616161,stroke-width:2px,color:#000',
};

function emitMermaid(graph, meta = {}) {
  const { nodes, edges } = graph;
  const statusByPath = meta.statusByPath || new Map();
  const byLayer = new Map();
  for (const [, n] of nodes) {
    if (!byLayer.has(n.layer)) byLayer.set(n.layer, []);
    byLayer.get(n.layer).push(n);
  }

  // Bucket every changed node by git status (default: modified — covers op/res
  // logical nodes with no on-disk path, which keep the familiar orange).
  const buckets = { added: [], modified: [], renamed: [], deleted: [] };
  for (const [key, n] of nodes) {
    if (!n.changed) continue;
    const path = pathFromKey(key);
    const st = path ? statusByPath.get(path) : null;
    buckets[STATUS_BUCKET[st] || 'modified'].push(n.id);
  }
  const presentStatuses = Object.keys(buckets).filter((s) => buckets[s].length);

  const out = ['flowchart LR'];
  for (const layer of LAYER_ORDER) {
    const ns = byLayer.get(layer);
    if (!ns || !ns.length) continue;
    out.push(`  subgraph ${layer}["${LAYER_TITLE[layer] || layer}"]`);
    for (const n of ns) out.push(`    ${n.id}["${esc(n.label)}"]`);
    out.push('  end');
  }

  // Legend — one swatch per status actually present, so the colors are
  // self-documenting in the rendered PDF. Legend nodes join the same status
  // buckets below so they pick up the real fill.
  if (presentStatuses.length) {
    out.push('  subgraph legend["Legend"]');
    for (const s of presentStatuses) out.push(`    lg_${s}["${STATUS_LABEL[s]}"]`);
    out.push('  end');
    for (const s of presentStatuses) buckets[s].push(`lg_${s}`);
  }

  const seenEdge = new Set();
  for (const e of edges) {
    if (!e.from || !e.to) continue;
    const arrow = e.dashed ? '-.->' : '-->';
    const line = e.label
      ? `  ${e.from} ${arrow}|${esc(e.label)}| ${e.to}`
      : `  ${e.from} ${arrow} ${e.to}`;
    if (seenEdge.has(line)) continue;
    seenEdge.add(line);
    out.push(line);
  }

  for (const s of presentStatuses) out.push(`  classDef ${s} ${STATUS_DEF[s]};`);
  for (const s of presentStatuses) out.push(`  class ${buckets[s].join(',')} ${s};`);
  return out.join('\n');
}

// ---------------- pdf render + open ----------------

function which(cmd) {
  try { return execFileSync('sh', ['-c', `command -v ${cmd}`], { encoding: 'utf8' }).trim(); }
  catch { return ''; }
}

// Render the Mermaid to a PDF next to <out>. PDF, not SVG, on purpose: mermaid's
// SVG labels are HTML <foreignObject>, which render blank outside a browser/mermaid
// context (the box draws, the text vanishes). Chromium's PDF print rasterizes the
// labels correctly. --pdfFit sizes the page to the diagram so nothing is clipped.
// Returns the pdf path, or null on failure (degrades to the .md being written).
function renderPdf(outPath, mermaid) {
  const dir = dirname(outPath);
  const stem = join(dir, basename(outPath).replace(/\.md$/, ''));
  const mmd = stem + '.mmd';
  const pdf = stem + '.pdf';
  const pp = join(dir, '.puppeteer.json');
  writeFileSync(mmd, mermaid + '\n'); // also a handy raw artifact to paste elsewhere
  // Chromium won't launch sandboxed in most headless / Nix-store environments.
  writeFileSync(pp, JSON.stringify({ args: ['--no-sandbox', '--disable-setuid-sandbox'] }));
  try {
    execFileSync(MMDC, ['-i', mmd, '-o', pdf, '-p', pp, '-b', 'white', '--pdfFit'],
      { stdio: ['ignore', 'ignore', 'pipe'], timeout: 120000 });
    return pdf;
  } catch (e) {
    console.error(`flowgraph: PDF render failed (${String(e.stderr || e.message).slice(0, 200)})`);
    console.error(`  Mermaid source kept at ${relative(process.cwd(), mmd)}`);
    return null;
  }
}

// Open in the user's PDF viewer — zathura if present (vim-keys, their default),
// else xdg-open. Detached so flowgraph returns immediately.
function openFile(path) {
  const opener = which('zathura') ? 'zathura' : (which('xdg-open') ? 'xdg-open' : null);
  if (!opener) { console.error(`  open it with: zathura ${path}`); return; }
  spawn(opener, [path], { detached: true, stdio: 'ignore' }).unref();
}

// ---------------- main ----------------

function main() {
  const a = parseArgs(process.argv.slice(2));
  if (a.help) { process.stdout.write(USAGE); return; }

  const root = resolve(a.root || gitSafe(process.cwd(), ['rev-parse', '--show-toplevel']).trim() || process.cwd());
  if (!existsSync(join(root, '.git')) && !gitSafe(root, ['rev-parse', '--git-dir']).trim()) {
    console.error(`not a git repo: ${root}`); process.exit(1);
  }
  // head === null is the default: diff base → working tree, including untracked
  // files, so in-progress worktrees (no commits past base) still map. Pass an
  // explicit --head <ref> to compare two commits instead. `tip` is the ref used
  // to compute the merge-base — always the branch HEAD, even in working-tree mode.
  const head = a.head || null;
  const tip = a.head || 'HEAD';
  let base = a.base;
  if (!base) {
    base = gitSafe(root, ['merge-base', 'main', tip]).trim()
        || gitSafe(root, ['merge-base', 'master', tip]).trim();
    if (!base) { console.error('could not determine base (no main/master); pass --base'); process.exit(1); }
  }

  const files = changedFiles(root, base, head).filter(f => /\.(ts|tsx|graphql|gql)$/.test(f.path));
  const ranges = changedRanges(root, base, head);
  const changedPaths = new Set(files.map(f => f.path));

  // classify + read content for changed files
  for (const f of files) {
    const abs = join(root, f.path);
    f.content = existsSync(abs) ? readFileSync(abs, 'utf8') : '';
    f.layer = classify(f.path, f.content);
    f.churn = (ranges.get(f.path) || []).reduce((n, [a, b]) => n + (b - a + 1), 0);
    f.symbols = changedSymbolNames(f.content, ranges.get(f.path));
  }

  // operations from changed gql/frontend files
  const gql = loadGraphql(root);
  const ops = [];
  const opByConst = new Map();
  for (const f of files) {
    if (!/gql`/.test(f.content)) continue;
    for (const op of extractOps(f.content, f.path, gql)) {
      op.changed = true;
      ops.push(op);
      if (op.constName) opByConst.set(op.constName, op);
    }
  }

  // FE usage: which changed frontend files reference each op const
  const feFiles = files.filter(f => f.layer === 'frontend');
  for (const op of ops) {
    op.usedBy = [];
    if (!op.constName) continue;
    for (const fe of feFiles) {
      if (new RegExp(`\\b${op.constName}\\b`).test(fe.content)) op.usedBy.push(fe.path);
    }
  }

  // bridge each op's root fields to resolvers, and scan resolver downstream
  const jobDownstream = {};
  for (const op of ops) {
    op.resolvers = [];
    for (const field of op.rootFields) {
      const hits = findResolverForField(root, field);
      for (const h of hits) {
        const downstream = scanDownstream(root, h.file, h.line);
        op.resolvers.push({ field, file: h.file, line: h.line, downstream });
        // resolve job downstream
        for (const j of downstream.jobs) {
          if (/inngest\/functions\//.test(j) && !jobDownstream[j]) {
            // map module specifier to a file path heuristically
            jobDownstream[j] = scanDownstream(root, specToPath(root, j));
          }
        }
      }
    }
  }

  // Blast-radius: the only type-aware step. For changed exported symbols, ask the
  // TS LSP "who else calls this." Everything above is grep and survives without
  // tsq; this degrades to empty if tsq is absent (status returns '' → skip).
  const blast = [];
  if (a.refs && tsq(root, ['status'])) {
    // Barrier, not a guess: poll `warmup` until vtsls reports a loaded index so the
    // first real `refs` isn't a cold empty (see waitForIndex / refsFor). --no-refs
    // skips all of this.
    waitForIndex(root);
    const targetLayers = new Set(['resolver', 'service', 'lib', 'data', 'async']);
    for (const f of files) {
      if (!targetLayers.has(f.layer)) continue;
      const syms = changedSymbols(root, f.path, ranges.get(f.path));
      if (process.env.FGDEBUG) console.error(`[dbg] ${f.path} layer=${f.layer} ranges=${JSON.stringify(ranges.get(f.path))} syms=${syms.map(s=>s.name).join(',')}`);
      for (const s of syms.slice(0, 6)) {
        const callers = refsFor(root, f.path, s);
        if (callers.length) blast.push({ file: f.path, sym: s.name, callers });
      }
    }
  }

  // Deterministic emission: buildGraph assigns node IDs in insertion order, so an
  // unsorted blast list (vtsls returns symbols/refs in arbitrary order) would
  // renumber nodes between runs of the same diff. Sort to a stable order.
  blast.sort((x, y) => x.file.localeCompare(y.file) || x.sym.localeCompare(y.sym));

  // Static import edges among changed files — the no-LSP structural backbone.
  // f.content is already in memory from the classify pass, so this is ~free.
  const imports = [];
  for (const f of files) {
    for (const spec of extractImports(f.content)) {
      const target = resolveImport(root, f.path, spec);
      if (target && target !== f.path && changedPaths.has(target)) {
        imports.push({ from: f.path, to: target });
      }
    }
  }

  const model = { root, files, ops, changedPaths, jobDownstream, blast, imports };
  const graph = buildGraph(model);
  const statusByPath = new Map(files.map((f) => [f.path, f.status]));
  const mermaid = emitMermaid(graph, { statusByPath });

  // write markdown with a mermaid fence (renders inline in nvim)
  const outPath = a.out || join(root, '.flowgraph', 'pr-flow.md');
  mkdirSync(dirname(outPath), { recursive: true });
  // Self-ignore: drop a `.gitignore` in the output dir so flowgraph's artifacts
  // never show up as untracked noise in the host repo's `git status`. Scoped to the
  // default `.flowgraph` dir so a custom --out target's directory is left untouched.
  if (basename(dirname(outPath)) === '.flowgraph') {
    writeFileSync(join(dirname(outPath), '.gitignore'), '*\n');
  }
  const md = renderMarkdown({ root, base, head, files, ops, blast, mermaid });
  writeFileSync(outPath, md);
  if (a.json) writeFileSync(outPath + '.json', JSON.stringify({ files, ops, blast }, null, 2));

  console.error(`flowgraph: ${files.length} changed files, ${ops.length} operations, ${blast.length} blast-radius links`);
  console.error(`wrote ${relative(process.cwd(), outPath)}`);

  if (a.pdf || a.open) {
    const pdf = renderPdf(outPath, mermaid);
    if (pdf) {
      console.error(`rendered ${relative(process.cwd(), pdf)}`);
      if (a.open) openFile(pdf);
    }
  }
  if (a.print) process.stdout.write(mermaid + '\n');
}

// map a module specifier like '@/lib/inngest/functions/section-snippet-cleanup'
// to a real file under apps/*/src
function specToPath(root, spec) {
  const tail = spec.replace(/^@\//, 'src/');
  const candidates = [];
  for (const app of ['apps/client', 'apps/admin', '.']) {
    for (const ext of ['.ts', '.tsx', '/index.ts']) {
      candidates.push(join(app, tail + ext));
    }
  }
  for (const c of candidates) if (existsSync(join(root, c))) return c;
  return tail + '.ts';
}

// Like specToPath but returns null when nothing exists on disk (keeps unresolved
// specs as their own node instead of inventing a path).
function resolveSpecFile(root, spec) {
  const tail = spec.replace(/^@\//, 'src/');
  for (const app of ['apps/client', 'apps/admin', '.']) {
    for (const ext of ['.ts', '.tsx', '/index.ts', '/index.tsx']) {
      const c = join(app, tail + ext);
      if (existsSync(join(root, c))) return c;
    }
  }
  return null;
}

// Local import specifiers in a TS/TSX source — static `from '…'`, dynamic
// `import('…')`, and re-export `export … from '…'`. (Over-matches harmlessly;
// resolveImport drops anything that isn't a local file.)
function extractImports(content) {
  const specs = [];
  const re = /(?:\bfrom|\bimport)\s*\(?\s*['"]([^'"]+)['"]/g;
  let m;
  while ((m = re.exec(content))) specs.push(m[1]);
  return specs;
}

// Resolve a `@/…` alias or a relative import to a repo-relative file path, or
// null for bare/external specifiers (next, vitest, node:*) and anything not on
// disk. All candidates carry a file extension, so a directory never matches.
function resolveImport(root, fromFile, spec) {
  if (spec.startsWith('@/')) return resolveSpecFile(root, spec);
  if (!spec.startsWith('.')) return null; // bare / external package
  const base = join(dirname(fromFile), spec);
  const cands = /\.(ts|tsx|js|jsx)$/.test(base)
    ? [base]
    : ['.ts', '.tsx', '.js', '.jsx', '/index.ts', '/index.tsx'].map((e) => base + e);
  for (const c of cands) if (existsSync(join(root, c))) return c;
  return null;
}

function renderMarkdown({ root, base, head, files, ops, blast, mermaid }) {
  const lines = [];
  lines.push(`# PR flow — \`${basename(root)}\``);
  lines.push('');
  const counts = files.reduce((acc, f) => { acc[f.status] = (acc[f.status] || 0) + 1; return acc; }, {});
  const statusBits = [
    counts.A ? `${counts.A} new` : null,
    counts.M ? `${counts.M} modified` : null,
    counts.R ? `${counts.R} renamed` : null,
    counts.D ? `${counts.D} deleted` : null,
  ].filter(Boolean).join(', ');
  lines.push(`Diff: \`${base.slice(0, 10)}..${head || 'working tree'}\` · ${files.length} changed files${statusBits ? ` (${statusBits})` : ''}`);
  lines.push('');
  lines.push('> Box color = git status: 🟢 new · 🟠 modified · 🔵 renamed · ⚪ deleted. Box lists the changed exported symbols; `Δ` is changed-line count.');
  lines.push('');
  lines.push('```mermaid');
  lines.push(mermaid);
  lines.push('```');
  lines.push('');
  if (ops.length) {
    lines.push('## GraphQL operations crossing the boundary');
    lines.push('');
    for (const op of ops) {
      lines.push(`- **${op.opKind} ${op.opName}** — root: \`${op.rootFields.join('`, `') || '?'}\``);
      for (const r of op.resolvers || []) {
        lines.push(`  - → resolver \`${r.field}\` @ \`${r.file}:${r.line}\``);
        const d = r.downstream;
        if (d.jobs.length) lines.push(`    - inngest: ${d.jobs.map(j => '`' + j + '`').join(', ')}`);
        if (d.services.length) lines.push(`    - services: ${d.services.map(s => '`' + basename(s) + '`').join(', ')}`);
        if (d.data.length) lines.push(`    - data: ${d.data.map(s => '`' + s + '`').join(', ')}`);
      }
    }
    lines.push('');
  }
  if (blast.length) {
    lines.push('## Blast radius (tsq refs — who else calls changed symbols)');
    lines.push('');
    for (const b of blast) {
      lines.push(`- \`${b.sym}\` (${basename(b.file)}) ← ${b.callers.map(c => '`' + basename(c) + '`').join(', ')}`);
    }
    lines.push('');
  }
  return lines.join('\n');
}

main();
