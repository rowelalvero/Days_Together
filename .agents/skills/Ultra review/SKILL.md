---
name: ultra-review
description: Multi-round, multi-agent adversarial code review. Maximize real defects found, minimize false positives via cross-critique. Language-agnostic, host-agnostic.
triggers: User typed "ultra review" or "ultra-review"; OR a coordinating agent invokes this skill at feature/PR completion.
host-requirements: filesystem read/write, code search, version control. Strongly preferred: parallel sub-agent execution, web research, read-only database query.
---

# Ultra Review

Coordinate a fleet of independent AI agents through a multi-round adversarial review of a code change. Reviewers investigate in parallel under narrow scopes, then cross-examine each other's findings — survivors are the defensible ones.

Designed for multi-agent collaboration across heterogeneous LLMs (Claude, Codex, Aider, custom harnesses), with the orchestrator composing the fleet and digesting results rather than reviewing code itself.

Optimizes for depth and adversarially-confirmed signal, not speed.

Credits: generalized from the original .NET-focused skill concept in PlatformPlatform by Thomas Jespersen.

---

## When to invoke

- **Interactive mode** — the user explicitly typed "ultra review" or "ultra-review". Run the full interview (STEP 1) and present results in chat (STEP 10).
- **Autonomous mode** — another agent (e.g., a team-lead orchestrator at feature completion) invokes this skill programmatically with scope, risk hotspots, size, and confidence policy already specified. Skip STEP 1's interview. Skip STEP 10's chat presentation. Always write `TASKS.md`; return its path to the caller.

If you cannot tell which mode you are in, ask once. Default to interactive.

---

## Host capability requirements

This skill is portable across LLM platforms (Claude Code, Codex CLI, Aider, Cursor, custom agent harnesses, etc.). It assumes:

| Capability | Required? | Used for |
|---|---|---|
| Filesystem read/write | **Required** | Writing artifacts to disk; agents communicate via files, not return values |
| Code search (grep / ripgrep / equivalent) | **Required** | Every reviewer needs to navigate the codebase |
| Version control (git or equivalent) | **Required** | Computing the diff under review |
| Parallel sub-agent / delegated-task execution | **Strongly preferred** | Each round launches N agents at once; without this, fall back to sequential execution and accept the wall-clock cost |
| Structured question / multi-choice prompt to user | Preferred | STEP 1 interview; degrades to plain-text questions if unavailable |
| Web research (search + fetch) | Preferred | Verifying external assumptions, API contracts, CVE data |
| Read-only database query | Optional | Verifying data-shape assumptions for backend reviews |
| Domain integrations (payment, CI, issue tracker, observability, etc.) | Optional | Whichever the host platform exposes; agents use what's available |

**Mapping to your host:** wherever this document says "spawn a sub-agent" or "delegated reviewer", invoke your platform's task-delegation primitive (Claude: `Task` tool with an appropriate `subagent_type`; Codex: spawned agent; custom harness: whatever your equivalent is). Wherever it says "code-search capability", use your platform's grep/find/ripgrep tool. None of the workflow depends on a specific tool name.

If parallel sub-agent execution is not available, run agents sequentially. Same artifacts written. Same workflow. Just slower.

---

## Glossary

- **Orchestrator** — the agent running this skill. Designs the review, launches reviewers, digests results. Does not read findings until the final digest step.
- **Reviewer agent** (or just "agent") — a delegated sub-agent assigned one narrow scope. Reads code, finds problems, writes findings to disk, returns a one-line triage. Never returns findings as prose.
- **Scope** — a one- to two-line description of an area and an angle. NOT a checklist. Names where to look, not what to find.
- **Round** — one parallel wave of agent work. This workflow has four: Discovery, Cross-review, Finalization, Digest.
- **Confidence** — categorical, not numeric: Certain / Likely / Possible. See Core principles.
- **High-impact area** — domains where false negatives are worse than false positives (security, data loss, privacy, regulatory, financial correctness). Subject to looser confidence rules.
- **Affinity cluster** — an orchestrator-side grouping of reviewers used to inform Round 2 assignment. Never shown to agents. Never a hard partition.

---

## Core principles

- **Depth, not efficiency.** Spend the tokens, time, and tool calls needed. This skill is invoked when the cost of missing a defect outweighs the cost of running a thorough review.
- **Generic by design.** Roster, clusters, and focus areas are co-designed with the user every time, from the diff. There is no fixed catalog of agent types.
- **80/20 effort split.** Each agent spends ~80% of its effort on the two or three highest-risk subareas of its scope (deep dive), ~20% sanity-scanning the rest.
- **No cap on agent count.** Match the change. A 20K-line PR touching money, third-party integrations, and schema changes may warrant 25+ agents. A small UI fix may warrant 4. Do not impose an arbitrary ceiling.
- **Multiple agents on hot areas.** Assign 3–4 agents per high-risk area from different angles ("correctness of the math", "behavior under partial failure", "what happens during a rolling deploy"). Overlap is expected and strengthens signal — when two independent agents land the same issue, that is a strong confirmation.
- **Agents run independent and parallel.** No mid-flight coordination. No splitting work between agents during a round. Independent investigation produces independent evidence.
- **False-positive hunt in Round 2.** Reviewers in Round 2 try to disprove findings, not validate them. Survivors must be defensible.
- **Confidence is categorical**, not numeric:
  - **Certain** — verified. The agent can reproduce, cite exact code paths, and quote evidence.
  - **Likely** — strong evidence, one step short of full verification. The agent must state what would close the gap.
  - **Possible** — plausible from patterns or partial evidence; not verified. The agent must state the gap.
- **Confidence policy** (set in interview or by caller):
  - **Certain only** — drop weaker findings.
  - **Allow Likely and Possible** — keep weaker findings, each with a "Why not Certain" note.
  - **High-impact exception** — reviewers flagged as covering high-impact areas may always keep Likely and Possible findings regardless of policy. Better to surface a possible breach than drop it.

---

## Output structure

All artifacts live under a stable, machine-readable path:

```
<workspace-root>/<branch>/ultra-review/<timestamp>/
├── CONTEXT.md              # Diff summary, ticket/spec excerpts, environment, scope
├── ROSTER.md               # Final agent list with affinity clusters
├── round1/
│   └── <agent-slug>.md     # One file per agent — discovery findings
├── round2/
│   ├── ASSIGNMENT.md                 # Reviewer-to-author table from Round 1 triage
│   └── <reviewer>__on__<author>.md   # One file per cross-review pair
├── round3/
│   └── <agent-slug>.md     # One file per agent — final findings + implementations
├── SUMMARY.md              # Orchestrator digest, deduplicated, prioritized
└── TASKS.md                # Optional — task list for engineers (always in autonomous mode)
```

Resolution rules:
- `<workspace-root>` — convention is `.workspace/` at the repository root. Adjust to host convention (e.g., `.agent-workspace/`, `.reviews/`).
- `<branch>` — current VCS branch name. Use the host's branch-detection command (`git branch --show-current` or equivalent). If detached HEAD, use the short commit SHA.
- `<timestamp>` — local-time `YYYYMMDD-HHmm`.
- `<agent-slug>` — lowercase, hyphenated agent name.

Create the directory tree at the start of STEP 2.

---

## Workflow

### STEP 1 — Interview (interactive mode only)

Infer what you can first; ask only what you cannot.

**Infer:**
- **Scope** — current branch and full diff vs the main branch (or whatever base the user named). Use VCS to list changed files, count lines added/removed, and bucket by directory.
- **Linked ticket / spec context** — scan branch name, commit messages, and recent conversation for ticket references. Fetch any found.
- **Environment** — current worktree, what tooling is available (web research, DB query, integrations).

**Then ask** (batch into one prompt if the host supports multi-question forms; otherwise ask one at a time):

1. **Scope** — confirm what's being reviewed. (Branch, PR, commit range.)
2. **Environment** — anything non-standard agents should know? (Staging DB available? Local services running? Feature flags?)
3. **Risk hotspots** — areas the user wants extra eyes on.
4. **Deprioritize** — areas to skip or treat lightly.
5. **Size** — small (~5 agents), medium (~10–15), large (20+). Default from diff size.
6. **Confidence policy** — single choice:
   - "Certain only" (drop weaker)
   - "Allow Likely and Possible with explanation" *(recommended for thorough reviews where missing a real issue is worse than surfacing a maybe)*

In autonomous mode, the caller supplies all of these directly — skip the interview.

---

### STEP 2 — Pre-fetch shared context

Create the artifact directory. Write `CONTEXT.md` with the small, shared inputs every agent needs. **The diff itself does not go in here** — each agent pulls its own slice from VCS. This file is metadata only.

Include:
- Branch name and base reference (so each agent can compute their own diff).
- Category breakdown of changed files: counts per area (e.g., backend / frontend / migrations / tests / config / docs / infra). Use whatever taxonomy fits the codebase.
- Excerpts (not full content) of any linked ticket, spec, or design doc.
- Special environment notes from the interview.
- Pointers (not contents) to any project-level rules, style guides, or architecture documents agents should respect (e.g., `<repo>/RULES.md`, `<repo>/ARCHITECTURE.md`).

Keep `CONTEXT.md` under one page. Detail belongs in the source files.

---

### STEP 3 — Co-design the agent roster

Propose a roster tailored to the diff. **There is no fixed catalog.** Design fresh every time from file paths, commit messages, and ticket context.

**Critical: keep scopes open-ended.** The single biggest failure mode of this workflow is the orchestrator confining agents to narrow checklists and missing what the orchestrator didn't think of. **Name AREAS worth a deep dive — do not pre-investigate them.** A one-line scope naming an area and an angle is right. Five lines listing specific classes, files, methods, columns, or expected outcomes is wrong: it tells the agent what to find instead of letting them discover it.

You do not deeply read code in this step. Agents do.

**Guidelines:**

- Identify which areas the diff touches and which carry highest risk. Risk axes that apply to almost any modern stack:
  - **Correctness of domain logic** — math, state machines, business invariants
  - **Concurrency and ordering** — races, deadlocks, lost updates, event ordering, retry/idempotency
  - **State and persistence** — schema evolution, migration safety, backfills, consistency
  - **External boundaries** — API contracts, third-party integrations, version skew, failure modes
  - **Security** — authn/authz, input validation, secret handling, injection, privilege escalation
  - **Multi-tenancy / scoping** — leakage between users, tenants, organizations
  - **Performance and scale** — hot paths, N+1, unbounded growth, memory pressure
  - **Observability and operability** — logs, metrics, traces, alerts, rollback safety
  - **User-facing behavior** — UX flows, accessibility, internationalization, error states
  - **Test coverage and quality** — what the tests claim vs. what they actually verify
- Propose **3–4 agents per hot area from different angles**, 1–2 on lighter areas.
- **Each scope is one line, two at most**: `<Area> — <angle / concern>`. Examples:
  - "Authentication and session handling — token lifecycle, replay, timing-sensitive checks"
  - "Schema changes — backwards compatibility and backfill correctness"
  - "Payment flow — idempotency under retry and partial failure"
  - "Frontend state management — derived state, stale closures, race conditions across async updates"
- **Do NOT enumerate** specific classes, methods, files, columns, line numbers, or expected outcomes in the scope.
- **No "general" agents.** Every agent has a sharp focus.
- **Flag each agent as high-impact (yes/no)** — areas where false negatives are worse than false positives. High-impact agents may always keep Likely/Possible findings regardless of the global policy.

Present the roster (name, scope, high-impact flag, one-line rationale) and confirm with the user. Iterate. In autonomous mode, the caller may have specified hotspots — derive the roster directly and skip confirmation.

---

### STEP 4 — Co-design review affinities

Cluster the roster into **3–5 affinity clusters** (e.g., "Domain Logic", "Integrations", "Frontend & UX", "Reliability", "Security & Access Control").

Clusters are **orchestrator-side hints for Round 2 reviewer selection only**. They are never shown to agents. They are not hard partitions — Round 2 assignment is dynamic and may cross clusters when scope demands it.

Design clusters per review. A domain-heavy review may cluster differently from a security-heavy one.

Present clusters with one-line rationale. Confirm (interactive mode) or proceed (autonomous mode). Write the final roster + clusters to `ROSTER.md`.

---

### STEP 5 — Round 1: Discovery (all agents in parallel)

Launch every agent in a **single parallel dispatch**. On hosts with parallel sub-agent execution, this is one batch call. On sequential hosts, launch them one after another using the same prompt.

**Selecting agent type / capabilities:** if your host offers specialized sub-agent variants (e.g., one tuned for backend, one for frontend, one for QA/E2E), pick the closest match per scope. If your host has only a generic code-reading agent, use that with full tool access. The prompt below is what matters — it is the same regardless of variant.

**Each agent's prompt (template — substitute the bracketed parts):**

```
You are an Ultra Review agent. Your scope is narrow and focused.

THIS IS NOT A NORMAL REVIEW
Not a line-by-line review. Not the validation pass you usually run alongside an
engineer. You run solo, in parallel with many peers, against a large diff. Find
REAL problems — bugs, defects, risks, design flaws, edge cases that break under
load, data corruption paths, security gaps, anything that should not ship.
Skip nitpicks, style, surface-level checks. Spend effort on the highest-risk
areas of your scope. Round 2 reviewers will try to disprove your findings —
commit only to claims you can defend with concrete evidence.

YOUR SCOPE
<scope from roster — 1–2 lines>

OTHER AGENTS WORKING IN PARALLEL
<full roster — name and scope per agent — overlap is expected and welcome>

CONTEXT
Read in order before starting:
1. <artifact-dir>/CONTEXT.md
2. <artifact-dir>/ROSTER.md

SHARED ENVIRONMENT
<one-paragraph environment note: current worktree, branch, base reference, and
the tool categories available to you — e.g., "code search, web research,
read-only database query, payment-provider read API, issue tracker query".
Reference the "Special environment notes" section of CONTEXT.md for any
non-standard details.>

YOUR JOB
Find real problems in your scope. Your scope names an AREA, not a checklist —
the orchestrator deliberately did NOT pre-list classes, files, edge cases, or
outcomes. You are the domain expert. Drive your own investigation.

Phase 1 — Discovery (first): read the code and build a mental model. Identify
entry points, boundaries, invariants, dependencies. Locate the risky subareas:
where the math is hard, where state is mutated under concurrency, where
failures cascade, where assumptions about external systems live, what is new
vs. an existing pattern. Commit to deep-diving the two or three highest-risk
subareas.

Phase 2 — Deep dive (~80% of your effort): investigate the chosen subareas
thoroughly. Read every relevant path. Run queries against any available data.
Reproduce edge cases mentally or in a sandbox if you can. Verify external
assumptions via web research or domain-integration tools when available.

Phase 3 — Sanity scan (~20%): sweep the rest of your area lightly. Note
anything that looks off but does not merit a full deep dive.

Tools: use everything your host platform makes available. Read code, search
(grep / ripgrep / equivalent), spawn helper search sub-agents for broad
investigation, run web research, query the database read-only, query domain
integrations. Do not save tokens or shortcut investigation.

Be specific. Cite <file>:<line> for every claim. Quote code, query results,
and external sources directly.

OUTPUT
Write findings to: <artifact-dir>/round1/<your-slug>.md using the template
below.

Return ONLY this one-line triage (nothing else):

DONE: <path> | findings=<N> | critical=<N> | high=<N> | medium=<N> | low=<N> | uncertain=<N> | hottest=<short title or "—">

(`uncertain` = Likely + Possible count. `hottest` = your single most concerning
finding's title, or "—" if none.)

Findings live in the file — never return them as prose in the triage line.

TEMPLATE for round1/<your-slug>.md:

# Round 1 — <Agent name>

## Scope
<one paragraph — your framing, derived from the code you actually read>

## Discovery
<area map: entry points, invariants, risky subareas and why. Then list the
subareas you deep-dived vs. sanity-scanned, with a one-line reason each.>

## Method
<files read, queries run, external sources consulted>

## Findings

### F1: <short title>
**Severity (preliminary):** Critical | High | Medium | Low
**Confidence:** Certain | Likely | Possible
**Location:** <file:line, or "system-wide">
**Description:** <what's wrong>
**Evidence:**
<code snippet, query result, or quoted source>
**Why it matters:** <impact — user, data, security, regulatory>
**Rough fix idea:** <optional, hand-wavy OK at this stage>
**Open questions:** <what you couldn't verify>

### F2: ... (repeat per finding)

## What you looked at and found clean
<short list — helps Round 2 reviewers calibrate>

## What you couldn't reach
<gaps — areas you couldn't fully assess and why>
```

After launching, wait for all agents. Do not read their findings into your context yet. Verify each agent returned a `DONE:` triage line and that the file exists on disk. On failure (missing file, malformed triage, timeout): decide whether to retry, reassign to a different agent, or proceed without that scope's coverage.

---

### STEP 6 — Triage and build Round 2 assignment

Use the **triage summaries only** (NOT the full findings) to design the Round 2 assignment. The orchestrator must stay out of the findings until Round 4.

**Goals:**
- Reviewers spend time where signal lives. An author with 0 findings needs one quick sanity check. An author with multiple Critical/High findings or an alarming "hottest" deserves 4–8 independent reviewers.
- Each reviewer carries ~2–3 reviews. Every author gets at least one external reviewer.
- Reviewers for hot authors come primarily from the matching affinity cluster but may cross clusters when scope demands.

**Heuristic (adjust freely):**

| Round 1 result | Reviewers assigned |
|---|---|
| 0 findings | 1 (light sanity check) |
| ≤ 3 findings, no Critical/High | 2 |
| Critical/High findings, or serious "hottest" | 4–8, scaled by severity |
| Author flagged high-impact | +1–2 reviewers regardless |

Write the explicit reviewer-to-author table — with full file paths for each pair — to `<artifact-dir>/round2/ASSIGNMENT.md` before launching Round 2. The table is the source of truth for which file each reviewer writes.

---

### STEP 7 — Round 2: Cross-review (all reviewers in parallel)

Launch all reviewers in a single parallel dispatch (or sequentially on hosts without parallelism). Reuse each reviewer's Round 1 agent type.

**Each reviewer's prompt:**

```
You are <Reviewer name>. In Round 1 you produced findings on your own scope
(<scope>). In Round 2 you read a list of peers' findings and TRY TO PROVE
THEM WRONG.

THIS IS NOT A NORMAL REVIEW
Adversarial false-positive hunt, not a friendly walkthrough. Skip nitpicks
and style. Focus on whether each claim is real, reachable in practice, and
at the right severity. Default to skepticism — adversarial confirmation is
the strongest signal a finding can get. Severity inflation is itself a
false positive.

YOUR ASSIGNMENT
Review these peers. Use the exact write paths below — do not invent filenames.

- <Author A> (scope: <scope>)
  Read:  <artifact-dir>/round1/<author-a-slug>.md
  Write: <artifact-dir>/round2/<your-slug>__on__<author-a-slug>.md
- <Author B>, <Author C>, ... — same pattern.

CONTEXT
CONTEXT.md and ROSTER.md were loaded in Round 1. Re-read only to refresh a
specific detail.

YOUR JOB
For each peer:
1. Read their Round 1 file.
2. For each finding, try to INVALIDATE it independently. Look at the code
   yourself. Run queries. Spawn helper search sub-agents. Use web research.
   Quote counter-evidence.
3. Common false-positive patterns to test for:
   - Context the author overlooked (a guard, a caller, a config)
   - Framework or runtime guarantees the author missed
   - Issue technically exists but is unreachable in practice
   - Two different code paths conflated
   - Severity inflated beyond actual impact
4. When you can confirm a finding, say so plainly with reproduced evidence —
   independent confirmation is the strongest signal.
5. Write your critique to the exact path above, using the template.

OUTPUT
One file per peer. When all are written, return exactly:
"DONE: reviewed <N> peers"

TEMPLATE (one per peer):

# Round 2 — <Your name> reviewing <Author name>

Author findings file: <path>

## Verdicts

### On <Author>'s F1: <title>
**Verdict:** Confirmed | Confirmed but severity wrong | Partial — <what holds> | False positive | Cannot verify
**Counter-evidence / corroboration:**
<what you found in the code, DB, or via external research>
**Suggested severity:** Critical | High | Medium | Low
**Notes:** <anything the author missed or got wrong>

### On <Author>'s F2: ... (repeat per finding)

## Findings the author missed (in their scope)
<optional — additional issues your investigation surfaced>
```

Wait for all reviewers. Verify all critique files exist. Same retry/reassign logic as Round 1 on failure.

---

### STEP 8 — Round 3: Finalization (all original agents in parallel)

Each Round 1 agent produces their final document, taking critiques into account. Launch in parallel, reusing each agent's original type.

**Each agent's prompt:**

```
You are <Agent name>. You wrote round1/<your-slug>.md and peers critiqued
each finding in round2/*__on__<your-slug>.md. In Round 3 you finalize.

THIS IS NOT A NORMAL REVIEW
Finalization pass. Decide which Round 1 findings survive adversarial
critique and are real enough to ship. Drop weak claims. Strengthen survivors
with evidence and a concrete implementation. Severity reflects impact, not
how hard the finding was to find.

CONTEXT
CONTEXT.md and ROSTER.md were loaded earlier; re-read only to refresh.
Read now:
- <artifact-dir>/round1/<your-slug>.md
- All critiques: <artifact-dir>/round2/*__on__<your-slug>.md

CONFIDENCE POLICY
- Default policy: <"Certain only" or "Allow Likely and Possible with explanation" — from STEP 1 or caller>
- This agent is high-impact: <yes / no — from roster>

Confidence is categorical: Certain (verified, reproducible), Likely (strong
evidence, one step short), Possible (plausible from patterns, not verified).

- "Certain only" AND NOT high-impact → drop anything weaker than Certain.
- "Allow Likely and Possible" OR high-impact → keep Likely/Possible findings,
  each with a "Why not Certain" note stating exactly what's missing. Better
  to surface a possible issue than drop it.

YOUR JOB
For each Round 1 finding:
1. Read every critique.
2. Do MORE research as needed: read more code, run more queries, spawn
   helper search agents, web research, domain integrations.
3. Decide: KEEP at Critical/High/Medium with a confidence level,
   DOWNGRADE, or DROP — per policy.
4. Severity reflects IMPACT, not confidence. A Certain Medium is fine.
   A Likely/Possible Critical with a "Why not Certain" note is fine when
   policy permits.
5. For each kept finding, write a CONCRETE implementation: code,
   queries, migrations, configuration — whatever applies. Make a future
   engineer's job nearly mechanical.
6. If your Round 2 / Round 3 research surfaced NEW findings, add them
   here under the same policy.

OUTPUT
Write to: <artifact-dir>/round3/<your-slug>.md using the template.
Return only: "DONE: <path>"

TEMPLATE:

# Round 3 — <Agent name> — Final

## Scope (recap)
<one line>

## Critical (must fix before merge)

### C1: <title>
**Location:** <file:line>
**Confidence:** Certain | Likely | Possible
**Description:** <what's wrong>
**Evidence:**
<code, query result, source>
**Why critical:** <user impact, data corruption, security exposure, regulatory, etc.>
**Round 2 critiques addressed:**
- <Reviewer X>: <what they said, how you resolved it>
**Why not Certain** (only when Likely or Possible): <what's missing, what would close the gap>
**Implementation:**
<concrete change — code, migration, config, exact diff if possible>
**Test:** <how to verify the fix>

### C2: ...

## High (should fix before merge) / ## Medium (worth considering)
Same template. Medium: only findings the policy permits.

## Dropped findings (from Round 1)
- F-X: <title> — Dropped because <reason, citing reviewer or own re-investigation>

## Notes for the orchestrator
<known overlaps with other agents' scopes, anything the digest should know>
```

Wait for all agents.

---

### STEP 9 — Round 4: Orchestrator digest

Read every `round3/*.md` file. **This is the only point findings enter your context.** Up to here you have stayed clean.

Produce `<artifact-dir>/SUMMARY.md`:

```markdown
# Ultra Review — <timestamp>

**Scope:** <branch / PR / diff range>
**Agents:** <N> across <G> affinity clusters
**Linked context:** <ticket links, spec links, if any>

## Critical (must fix before merge)

### C1: <consolidated title>
**Raised by:** <agent-a>, <agent-b>  *(independent confirmation)*
**Location:** <file:line>
**Summary:** <consolidated description>
**Why critical:** <impact>
**Implementation:**
<best implementation across agents — pick the most concrete and complete>
**Test:** <how to verify>
**Source files:** round3/<agent-a>.md, round3/<agent-b>.md

### C2: ...

## High / ## Medium
Same structure as Critical. Medium can be terser.

## Dropped during review
(One line each — raised in Round 1, dropped after critique. Audit trail.)

## Coverage map
| Area | Agent(s) |
| --- | --- |
| <area> | <agent slugs> |

## Notable disagreements between agents
<short list — Round 2 critiques that flipped severity or dropped findings,
especially the interesting ones. Useful for calibrating future reviews.>
```

**Deduplication rules:**

- Two agents at the same location → merge into one entry. Note both under "Raised by". Independent confirmation is strong signal — call it out, and bump confidence one level if both said Likely (two independent Likelys ≈ Certain).
- Disagreement on severity → take the higher one (carry the uncertainty note if not Certain).
- Disagreement on implementation → prefer the more concrete one. Note the alternative.
- Likely/Possible findings → preserve the "Why not Certain" note verbatim in the summary.

---

### STEP 10 — Present findings and write sink

**Autonomous mode:** skip presentation. Write `TASKS.md` (format below). Return its path to the caller. Done.

**Interactive mode:** present `SUMMARY.md` in chat — **Critical first, then High, then a one-line list of Medium titles**. Do not paste Medium implementations unless asked. Wait for the user (they may want to discuss, mark won't-fix, reprioritize, or request deeper investigation on specific items).

Once the user is satisfied, ask where findings should go (single choice, with whatever question primitive the host supports):

- **TASKS.md** — one row per Critical, High, and Medium, written to `<artifact-dir>/TASKS.md`
- **Issue tracker** — one ticket per Critical and High (or Critical/High/Medium, user's choice). Use whatever ticket-creation tool the host exposes.
- **Let me select** — present the list and let the user pick which findings to ticket.
- **Handle manually** — just keep the artifacts; the user will work from `SUMMARY.md`.

If creating tickets in an issue tracker: follow that tracker's project conventions (look for a project-level reference doc if one exists). Each ticket: title in imperative voice, description copied from the consolidated finding in `SUMMARY.md`, link to parent feature/epic if one exists, status = open / planned, current iteration / sprint.

#### TASKS.md format

```markdown
# Ultra Review Tasks — <timestamp>

<one-line summary>. Full per-agent reports in `round3/`. Consolidated digest in `SUMMARY.md`.

**Merge blockers:** <comma-separated IDs of Critical + High>.

## Tally
- Critical: <N> (<IDs>)
- High: <N> (<IDs>)
- Medium: <N>
- Low / Nit: <N>

## Tasks

| ID | Status | Severity | Title | Files | Fix size | Source |
| --- | --- | --- | --- | --- | --- | --- |
| C-1 | ⏳ Open | Critical | <title> | <file:line, ...> | <~lines or n/a> | <agent-slug> |
| H-1 | ⏳ Open | High | ... | ... | ... | ... |

ID format: `<severity>-<index>` where severity is `C` (Critical), `H` (High), `M` (Medium), `L` (Low), `N` (Nit).

Status values:
- `⏳ Open` — initial, not yet picked up
- `🔧 In progress` — engineer is working on the fix
- `👀 In review` — reviewer has it
- `✅ Done (<commit>)` — committed
- `🚫 Blocked — <reason>` — needs user input or external access

## Details

### C-1 — <title>
**Why:** <root cause>.
**Blast radius:** <impact>.
**Fix:** <concrete change>.
**Reference:** <link to project rule, RFC, or design doc, if applicable>.

### H-1 — ...
```

---

## Guidelines

**DO:**
- Co-design the roster and clusters with the user every time. Tailor to the diff. Never pull from a saved catalog.
- Launch each round in a single parallel dispatch when the host allows it.
- Make agents write findings to disk and return only the `DONE:` triage line. Findings as prose in tool returns will poison the orchestrator's context.
- Read agent outputs only at digest time (STEP 9, Round 4).
- Be specific in scopes — "review for security" is too vague; "review every new endpoint and handler for missing tenant scoping" is right.
- Prefer the strongest research tool the host has (web search with fetch over plain search; specialized domain integrations over generic ones).
- Treat overlap between agents as a feature — independent confirmation is the most reliable signal this workflow produces.

**DON'T:**
- Use a fixed agent catalog. Every review is custom.
- Cap agent count arbitrarily. Match the change.
- Let agents coordinate or split work mid-round.
- Read agent findings into the orchestrator's context before Round 4.
- Pre-list classes, methods, files, or expected outcomes in agent scopes — let agents discover them.
- Create tickets in an issue tracker before presenting findings to the user and getting approval (interactive mode).
- Commit, push, or amend code. **Findings are the output. Fixes are a separate workflow.**

---

## Host-platform notes

Brief mapping hints. Adapt to whatever your host actually provides — these are illustrative, not prescriptive.

| Generic concept | Claude (Sonnet/Opus, Claude Code) | Codex CLI | Aider | Custom harness |
|---|---|---|---|---|
| Spawn parallel sub-agent | `Task` tool, multiple calls in one message | spawned agents | sub-task spawn | task-queue dispatch |
| Code search | Grep/Glob, or `Explore` sub-agent | grep / rg via shell | grep / rg via shell | your search tool |
| Multi-choice user question | `AskUserQuestion` / equivalent | plain prompt | plain prompt | your UI |
| Web research | WebSearch / WebFetch / Perplexity MCP | web search tool | web search via shell | your research tool |
| Read-only DB query | DB MCP server | DB CLI via shell | DB CLI via shell | your DB adapter |
| Issue tracker writes | issue-tracker MCP | tracker CLI via shell | tracker CLI via shell | your tracker adapter |

If a capability is missing, agents work without it. They note "could not verify externally" in their findings rather than fabricating.
