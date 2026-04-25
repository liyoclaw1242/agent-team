# Rule — Provenance

Every child issue created by arch-shape carries:

1. `source:arch` label (so dispatcher will fast-path it to the named role without re-classifying)
2. Correct `agent:{role}` label
3. `status:ready` (or `status:blocked` if it has unmet deps)
4. `<!-- parent: #N -->` HTML comment marker pointing at the parent issue
5. `<!-- intake-kind: ... -->` from the parent if relevant (most children inherit; some don't)
6. Optionally: `<!-- deps: #X, #Y -->` if the task is gated on other children

The `actions/open-child.sh` script does all of this; **don't bypass it** by calling `gh issue create` directly. Manual creation reliably forgets one or more of the required markers.

## Why provenance matters

The dispatcher uses `source:arch` as the **only signal** that an issue has been properly shaped. Without this label:
- Dispatcher will route the issue back through arch-shape (infinite loop or wasted LLM calls)
- Or: route to `arch-judgment` for being unclassifiable

With the label:
- Dispatcher recognises this is shaped and `route.sh` routes it directly to the named role
- The role's poll picks it up and starts work

## Self-check before delivery

For each child issue, after creation:

```bash
labels=$(gh issue view "$N" --repo "$REPO" --json labels --jq '[.labels[].name] | join(" ")')
echo "$labels" | grep -q "source:arch"     || die "missing source:arch on #$N"
echo "$labels" | grep -qE "agent:(fe|be|ops|qa|design)" || die "missing agent label on #$N"
echo "$labels" | grep -qE "status:(ready|blocked)" || die "missing status label on #$N"

bash _shared/actions/issue-meta.sh get "$N" parent >/dev/null \
  || die "missing parent marker on #$N"
```

If any check fails, abort delivery, fix the child, retry. Don't deliver a parent whose children are inconsistent.

## Renaming and historical hygiene

When you re-shape a parent (e.g., after Mode C pushback), you typically close existing children and open new ones. The new children carry `source:arch` and `<!-- parent: #N -->` (same parent). The old children, when closed, get a closing comment explaining the supersession:

```markdown
Superseded by #142, #143 in re-shaped decomposition.
```

This preserves audit trail. Don't delete or hard-edit old issues.
