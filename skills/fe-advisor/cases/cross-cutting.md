# Case — Cross-Cutting

A request that touches many components / surfaces, where the architectural decision is "how to make the change without breaking everything else".

## The consultation

Parent issue #310: "Add 'last seen' timestamp to all user-facing displays of a user (avatar tooltips, comment headers, profile cards)."

arch-shape opened consultation #311 to fe-advisor:

```
- Where do user displays currently live?
- Is there a shared component, or are they duplicated?
- What pattern would minimise breakage?
- Roughly how many surfaces would change?
```

## Phase 1 — Investigate

```bash
# Find avatar / user display components
git grep -l "Avatar\|UserName\|UserCard" apps/ | head
# → 7 unique components, used in 28 places

# Are they shared or per-feature?
ls components/users/
# → AvatarBase.tsx, UserAvatar.tsx, UserCard.tsx, UserMention.tsx
ls apps/billing/components/user/
# → UserBadge.tsx (separate)
ls apps/messages/components/
# → MessageAuthor.tsx (yet another implementation)

# How does user data flow currently?
git grep -l "useUser\|getUserById" apps/ | head
# → 5 files use useUser; varies by surface

# Existing user shape?
cat lib/types/user.ts | head
# → interface User { id, name, email, avatarUrl, createdAt }
# → no lastSeenAt field; would need adding

# Backend API?
curl /api/users/{id} (or check API contract)
# → not in scope for FE-advisor; flag for be-advisor
```

## Phase 2 — Compose response

```markdown
## Advice from fe-advisor

### Existing constraints

- User display components are duplicated across the codebase. Found 7 distinct
  components covering similar territory:
  - components/users/AvatarBase.tsx (shared base — used by 18 callers)
  - components/users/UserAvatar.tsx (most common; consumes AvatarBase)
  - components/users/UserCard.tsx (profile card variant)
  - components/users/UserMention.tsx (in-text mentions)
  - apps/billing/components/user/UserBadge.tsx (billing-specific; doesn't reuse base)
  - apps/messages/components/MessageAuthor.tsx (message-specific; doesn't reuse base)
  - apps/admin/components/UserRow.tsx (admin lists; doesn't reuse base)
- The shared base (AvatarBase) is used by 18 callers; the three feature-specific
  variants serve specific layout needs and don't extend it.
- User type in lib/types/user.ts has no `lastSeenAt` field; adding it is a
  type change visible to all 5 useUser-style consumers.
- Tooltip on AvatarBase exists already (apps/components/users/AvatarBase.tsx:34);
  currently shows just `name` + `email`. Adding "last seen" is a minor
  addition there.

### Suggested approach

- **Centralise the lastSeenAt display** in AvatarBase's tooltip and a new
  shared `LastSeenLabel` component; make the three outliers (UserBadge,
  MessageAuthor, UserRow) opt into the new label.
- The three outliers can stay as-is; not every place needs lastSeen
  prominently. The decision per outlier:
  - UserBadge (billing): show — it's relevant for "last activity" in billing
  - MessageAuthor: don't show — chat already has implicit recency from
    message timestamps; double info clutters
  - UserRow (admin): show — admins want this signal
- Don't attempt to unify the four user-display components in this PR;
  that's a separate refactor with its own scope. Just thread lastSeenAt
  through where wanted.

### Conflicts with request

- "All user-facing displays" — interpreted strictly, that's all 4
  feature-specific implementations. As above, recommend not adding it
  to MessageAuthor (already implicit). Ask arch-shape to confirm or
  override this interpretation.
- The User type currently doesn't include lastSeenAt; adding it is a
  type-level change visible to 5 useUser consumers. None of them will
  break (the field is optional), but their props' shape will change.

### Estimated scope

- M — ~9 files:
  - lib/types/user.ts (add lastSeenAt: string | null to User)
  - components/users/AvatarBase.tsx (display in tooltip)
  - components/users/LastSeenLabel.tsx (new — reusable label component)
  - apps/billing/components/user/UserBadge.tsx (consume LastSeenLabel)
  - apps/admin/components/UserRow.tsx (consume LastSeenLabel)
  - 4 test files for new + modified components
- Excludes backend changes (BE provides lastSeenAt; out of scope here)
- Excludes the question of "should MessageAuthor show this" — assumed no

### Risks

- The lastSeenAt format choice (relative "5 minutes ago" vs absolute "Mar 4
  14:30") affects scan-ability. Recommend relative for tooltips, absolute
  for admin views; would need to pick deliberately.
- "Last seen" implies privacy: users may not want to broadcast their
  online state. Worth verifying with product whether this is a privacy
  setting; if so, FE needs to handle the "user has hidden lastSeen" case
  with a fallback (often shows nothing, not "Unknown").
- AvatarBase has 18 callers; if adding lastSeen accidentally changes the
  rendered DOM (extra element in tooltip), CSS in some callers may shift.
  Risk is low (we're adding inside the existing tooltip) but verify.

### Drift noticed

- arch-ddd/bounded-contexts/users.md mentions "User profile" but doesn't
  enumerate the four parallel user-display components — drift between
  documented architecture and code reality. The fragmentation is worth
  documenting (or addressing) but not in scope for this consultation.
- The User type's last documentation update was 2024-09; the field
  list is current as of that date.
```

## Phase 3 — Validate + post

```bash
bash actions/respond.sh \
  --issue 311 \
  --advice-file /tmp/advice-issue-311.md
```

## What this case demonstrates

- **Inventory before recommendation**: enumerated all 7 user-display components with grep, then proposed where to add the change
- **Selective application**: pushed back on "all" — argued MessageAuthor doesn't need it, with rationale
- **Outliers acknowledged**: didn't pretend the codebase is unified; surfaced the parallel implementations honestly
- **Adjacent concerns flagged**: privacy implications, format choice (relative vs absolute), DOM shift risk — none of these were asked but they affect implementation
- **Stayed in scope**: noted that "unify the user-display components" is its own refactor; didn't bundle that into the answer
- **Drift surfaced for follow-up**: documentation drift mentioned but not "fixed" via the consultation

## Key lessons for cross-cutting consultations

1. Inventory the affected surfaces first (grep, find, list). Surprises in inventory often change the recommendation.
2. The default approach should respect existing fragmentation; don't proposal-creep into "let's also unify everything".
3. Push back on "all X" requests when honest analysis says "all minus a few" is better. Name the few.
4. Privacy / UX / format choices are not the FE-advisor's call — surface them; let arch-shape route to the right decider.
5. M-scope cross-cutting is doable in one PR; L-scope cross-cutting is usually 2-3 PRs and worth recommending decomposition.
