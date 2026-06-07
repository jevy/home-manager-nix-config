# flowgraph — PR-review playbook

`flowgraph` turns a branch's diff into a **FE → GraphQL → resolver → service → DB**
flow diagram, with the changed files highlighted. It's built for reviewing
covenant-web PRs where the cross-boundary flow is too big to hold in your head.

The tool is `pkgs/flowgraph/flowgraph.mjs`, packaged in `modules/dev/flowgraph.nix`
(on PATH via `home.packages`). The in-editor navigation keys live in
`modules/dev/nixvim.nix`.

## The loop

1. `cd` into the worktree / check out the branch.
2. Run it and read the picture:
   ```bash
   flowgraph --open          # writes .flowgraph/pr-flow.{md,mmd,pdf}, opens the PDF in zathura
   ```
   Diffs the **working tree by default** (committed + staged + unstaged + untracked),
   so an in-progress branch with no commits past `main` still maps.
3. Read the spine. Orange = touched by this PR. Boxes are grouped by layer
   (Frontend / GraphQL ops / Resolvers / Services / Async / Data / …).
4. Drill into anything from Neovim — cursor on a symbol, press a key:

   | want | key | in a `gql\`\`` block | elsewhere |
   |---|---|---|---|
   | definition | `gd` | schema SDL | LSP definition |
   | the resolver (cross the wire) | `gri` | resolver impl. | LSP implementation |
   | who selects this field | `grr` | frontend gql usages | LSP references |
   | descend resolver → service → DB | `<leader>go` | — | outgoing-call tree |
   | who calls this | `<leader>gi` | — | incoming calls |

   `<leader>g{r,s,u}` are explicit always-grep aliases (resolver / schema / usages).

## What the edges mean

- **Solid, unlabeled** — file imports file. Pure static parse: no LSP, instant,
  works on a cold index and on non-GraphQL PRs. This is the structural backbone.
- **Dashed `-.->|→ symbol|`** — blast-radius: who calls a *changed exported symbol*.
  Needs a warm vtsls index. Supersedes the bare import edge for the same pair
  (it carries the symbol name).
- **Dashed across the GraphQL boundary `-.->|field|`** — a gql operation's root
  field → its `Query.<field>`/`Mutation.<field>` resolver, matched by name (the one
  link the compiler can't follow).

## Flags

```
flowgraph                 # .flowgraph/pr-flow.md only
flowgraph --open          # + render PDF and open it (zathura, else xdg-open)
flowgraph --pdf           # + render PDF, don't open
flowgraph --no-refs       # skip the LSP blast-radius (faster; import edges still connect)
flowgraph --base <ref>    # base to diff from (default: merge-base(main, HEAD))
flowgraph --head <ref>    # compare two commits instead of the working tree
flowgraph --print         # also print the Mermaid to stdout
flowgraph --json          # also write <out>.json
```

## Gotchas

- **Fresh worktree → cold LSP.** The first run's blast-radius (dashed, symbol-labeled)
  edges can be sparse while vtsls indexes. The **import edges still connect** the graph;
  re-run once it's warm to get the symbol labels.
- **`--open` needs a rebuild after changes.** It runs the installed binary; `rebuildhm`
  to pick up edits to `flowgraph.mjs`. Unknown flags now hard-error (a stale binary that
  predates a flag won't silently ignore it).
- **Artifacts self-ignore.** `flowgraph` drops a `.gitignore` in `.flowgraph/` so the
  generated `md`/`mmd`/`pdf` never show up as untracked noise.

## When NOT to use it

Small or non-GraphQL PRs (a handful of files) — just read them. flowgraph earns its
keep on the big, cross-boundary changes where the flow isn't obvious by eye. A 3-file
webhook handler renders as three boxes and a couple arrows; the source is faster.
