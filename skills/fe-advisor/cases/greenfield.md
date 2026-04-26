# Case — Greenfield

A request for a feature that has no precedent in the codebase. fe-advisor's job is to honestly report "no existing pattern" and surface the implications.

## The consultation

Parent issue #420: "Add a real-time collaborative cursor system to the document editor (like Google Docs cursors)."

arch-shape opened consultation #421 to fe-advisor with these questions:

```
- What in current FE code makes real-time cursors easy or hard?
- Does the request conflict with anything in the editor module?
- Roughly how many files / components would change?
- Does arch-ddd describe what's in the codebase for the editor?
```

## Phase 1 — Investigate

```bash
# Find the editor module
find apps -type d -name "editor"
# → apps/docs/editor

# Files in the editor module
find apps/docs/editor -type f \( -name "*.tsx" -o -name "*.ts" \) | wc -l
# → 34

# Real-time / collaborative existing?
git grep -l "websocket\|socket.io\|real-time\|collaborate\|presence" apps/
# → no matches
git grep -l "y-doc\|automerge\|ot-" apps/
# → no matches

# How is editor state managed?
git grep -l "useEditor\|EditorState" apps/docs/editor
# → 8 files; main hook at apps/docs/editor/lib/use-editor.ts:23

# What's the editor framework?
cat apps/docs/editor/package.json | grep -A3 dependencies
# → uses tiptap; client-side only

# Network code in editor
git grep -l "fetch\|api/" apps/docs/editor
# → apps/docs/editor/lib/save.ts (autosave to /api/docs/{id})
```

## Phase 2 — Read arch-ddd

```bash
cat arch-ddd/bounded-contexts/docs.md | head -50
```

Key findings:
- arch-ddd describes "single-user editor with autosave"
- No mention of real-time, collaboration, presence, or multi-user state
- arch-ddd last updated 2024-03 (a year old)

## Phase 3 — Compose response

```markdown
## Advice from fe-advisor

### Existing constraints

- Editor module at apps/docs/editor (34 files); single-user editing model
  throughout. State managed via tiptap's editor instance + a useEditor hook
  (apps/docs/editor/lib/use-editor.ts:23) consumed by 8 components.
- Persistence: autosave to /api/docs/{id} via apps/docs/editor/lib/save.ts;
  request-response only. No streaming, no websocket, no SSE.
- No real-time infrastructure anywhere in the codebase: no socket.io, no
  websocket usage, no Y.js / automerge / OT libraries (verified: 0 matches
  for `websocket\|socket.io\|y-doc\|automerge` across apps/).
- tiptap supports collaboration via @tiptap/extension-collaboration + a Yjs
  backend, but neither is currently installed.

### Suggested approach

- This is a greenfield real-time feature; there's no existing pattern to
  extend. Two architectural directions:
  - **A) Adopt Yjs + tiptap collaboration extension**: well-trodden path
    for tiptap; introduces Yjs as a peer dependency; needs a server
    (Hocuspocus, Liveblocks, or self-hosted) for sync
  - **B) Build presence-only (cursors) with WebSockets, no document
    sync**: simpler — only cursor positions stream; document edits stay
    on autosave; no operational transform / CRDT machinery
- Direction B is dramatically smaller; A is the right answer if document
  conflict resolution is also wanted (it usually is, given the request
  references Google Docs).
- Recommend arch-shape clarify request scope: cursors only, or full
  collaborative editing with conflict resolution?

### Conflicts with request

- "Like Google Docs cursors" implies eventual conflict resolution. Direction
  B (presence-only) doesn't provide this; users editing the same paragraph
  will overwrite each other on autosave — worse UX than no collaboration.
- Current autosave model assumes single-author; switching to multi-author
  needs server-side merge logic (or CRDT), which is a backend question
  outside FE-advisor scope.

### Estimated scope

- For Direction A (Yjs + collaboration): L+ — would touch all 8 editor
  consumers, add ~10 new files (provider, presence layer, awareness,
  conflict-resolution UI, reconnect handling, collaboration tests),
  introduce Yjs as a major dependency, and require a backend collaboration
  server. **Strongly suggest decomposing**:
  1. Add Yjs + collaboration extension behind feature flag (M)
  2. Build presence (cursors + name labels) (M)
  3. Build conflict resolution UI (selection survival, etc.) (M)
  4. Production rollout (rollback path, multi-tenant isolation) (M)
- For Direction B (cursors only): M — ~10 files: WebSocket client,
  awareness state hook, cursor overlay component, name labels, presence
  cleanup; existing editor stays intact.

### Risks

- WebSocket connections add a deployment concern (sticky sessions or
  pub/sub fan-out); affects ops too — recommend ops-advisor consultation
- Yjs client bundle is non-trivial (~80KB minified); affects perceived
  load time on the editor route
- Real-time UX requires careful disconnect / reconnect handling; intermittent
  network creates cursor "ghosts" and stale state — needs explicit cleanup
  on visibility change, focus loss, etc.
- Once shipped, real-time features are hard to remove (users notice their
  absence); commit only when the feature is well-scoped

### Drift noticed

- arch-ddd/bounded-contexts/docs.md (last updated 2024-03) describes the
  editor as "single-user with autosave"; this is still accurate but doesn't
  cover the collaboration request. arch-shape should update arch-ddd to
  document the collaboration decision (especially if Yjs is adopted, that's
  a top-level architectural choice worth recording).
```

## Phase 4 — Validate + post

```bash
bash validate/advice-format.sh /tmp/advice-issue-421.md
# → result: PASS

bash actions/respond.sh \
  --issue 421 \
  --advice-file /tmp/advice-issue-421.md
```

`respond.sh`:
1. Runs format validation (refuses if fails)
2. Posts the comment to issue #421
3. Closes issue #421

## What this case demonstrates

- **Investigated before opining**: greps confirmed no existing real-time infrastructure; not assumed
- **Surfaced ambiguity**: the request is vague between "cursors only" and "full collaboration"; advisor names both interpretations and their scope difference
- **Pushed back on scope**: directly recommends decomposition for the L+ case
- **Drift noted**: arch-ddd is a year stale and doesn't cover the new direction; flagged for arch-shape to address before / during decomposition
- **Cross-role acknowledgment**: notes that backend and ops advisors are also relevant; doesn't try to answer their questions

## Key lessons for greenfield consultations

1. The first sentence should establish "this is greenfield". Don't bury it.
2. Investigate adjacent / similar features even if the exact thing isn't there. ("We don't have collaboration but we do have these patterns…")
3. Greenfield often means "L+ with multiple sub-decisions". Decomposition is the most valuable advice.
4. arch-ddd is often stale for greenfield areas (the area is greenfield because nobody documented it). Drift is expected.
5. Don't pretend the codebase has the structure to support what's being asked just because you wish it did.
