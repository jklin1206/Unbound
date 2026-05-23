# Agent Guidelines

These rules apply to coding agents working in this repository. They merge the repo's product needs with the caution-first guidance from `multica-ai/andrej-karpathy-skills`.

## Think Before Coding

- State important assumptions before implementing when the task is ambiguous.
- Ask a clarifying question when multiple interpretations would lead to meaningfully different code.
- Push back on changes that would make the product or codebase worse.
- Prefer a short plan with concrete verification steps for multi-file or architectural work.

## Simplicity First

- Build the minimum code that solves the requested problem.
- Do not add speculative features, generic configuration, or abstractions for single-use behavior.
- If a change grows large, pause and look for a smaller path before continuing.
- Match the existing patterns in the Swift codebase unless the task is explicitly to change them.

## Surgical Changes

- Touch only the files needed for the current request.
- Do not reformat, rename, or refactor nearby code just because it is adjacent.
- Keep every changed line traceable to the user's request or to verification required by that request.
- When editing a dirty worktree, assume unrelated changes belong to the user or another agent.

## Dead-Code Discipline

- Remove imports, variables, functions, files, and tests that become unused because of the current change.
- Do not leave obsolete duplicate paths behind when replacing a flow. Either delete the old path in the same change or document why it must remain.
- If you discover pre-existing dead code outside the current scope, call it out in the final response or a handoff doc instead of deleting it silently.
- For larger refactors, keep a "removed/replaced" checklist so old models, services, views, feature flags, and docs do not linger half-connected.
- Before finishing, search for old type names, old entry points, and comments that claim the previous behavior still exists.

## Goal-Driven Verification

- Define success criteria before changing code.
- Prefer tests that reproduce the bug or protect the new behavior.
- Run the most focused verification first, then broader builds/tests when the blast radius warrants it.
- If verification cannot run, explain exactly why and what remains risky.

## UNBOUND Product Architecture Guardrail

- Program workouts, skill sessions, quick logs, routines, custom workouts, cardio, carries, and recovery work should converge toward one session/logging spine.
- Different block types may need different logger UI, but completed training should feed one progress pipeline: XP, rank, attributes, badges, progression, history, and coach context.
- Avoid adding another parallel logging or reward path unless the work explicitly includes a plan to merge it back into the unified spine.

## UNBOUND Brand Language Guardrail

- UNBOUND is an anime training arc / fitness journey app first. The emotional promise is: start your arc, follow a real program, see proof that you are changing, and feel like you earned progress.
- "Break the restriction" is a brand-feel tagline, not a literal product mechanic. Do not build copy around "limiters", "weak links", "restrictions", "holding you back", or "fixing what is wrong with you" unless the user explicitly asks for that angle.
- Onboarding should not open by diagnosing the user as broken. It should invite them into the arc, then use assessment screens to build their starting point, rank, protocol, and proof.
- Prefer simple, direct copy: "Start your training arc", "Build your starting rank", "Your protocol is being forged", "Every session moves the arc forward."
- Avoid abstract productivity framing like "the loop", "system detected", "failure cycle", or "motivation problem" as the main hook. Those can appear only as secondary explanation if they support the training-arc fantasy.

## Parallel Agent Setup

Parallel work needs three separations:

- Worktree separates source files.
- DerivedData separates Xcode build outputs and `build.db`.
- Simulator separates app runtime/UI inspection.

Do not run multiple agents in the same source checkout on the same branch unless the user explicitly wants shared-working-tree collaboration. The default for parallel work is one git worktree and one branch per agent.

### Worktree Setup

Run these from `/Users/jlin/Documents/toji/UNBOUND` when creating parallel lanes:

```bash
git worktree add ../UNBOUND-agent-a -b codex/agent-a
git worktree add ../UNBOUND-agent-b -b codex/agent-b
git worktree add ../UNBOUND-agent-c -b codex/agent-c
git worktree add ../UNBOUND-integration -b codex/integration
```

Give each Codex thread exactly one lane:

| Lane | Code Path | Simulator | DerivedData |
| --- | --- | --- | --- |
| A | `/Users/jlin/Documents/toji/UNBOUND-agent-a` | iPhone 17 | `/private/tmp/unbound-dd-a` |
| B | `/Users/jlin/Documents/toji/UNBOUND-agent-b` | iPhone 17 Pro | `/private/tmp/unbound-dd-b` |
| C | `/Users/jlin/Documents/toji/UNBOUND-agent-c` | iPad mini (A17 Pro) | `/private/tmp/unbound-dd-c` |
| Verify | `/Users/jlin/Documents/toji/UNBOUND-integration` | iPhone 17 Pro Max | `/private/tmp/unbound-dd-verify` |

If fewer agents are active, use fewer lanes. Never reuse another active agent's DerivedData path.

### Agent Startup Prompt

Start implementation agents with:

```text
You are Agent A. Follow /Users/jlin/Documents/toji/UNBOUND/AGENTS.md.
Work only in /Users/jlin/Documents/toji/UNBOUND-agent-a.
Use simulator iPhone 17 only if explicitly needed.
Use DerivedData /private/tmp/unbound-dd-a for all Xcode builds.
Prefer compile-only verification. Do not merge to main.
End with the handoff format from AGENTS.md.
```

Start the integration agent with:

```text
You are the verification/integration agent. Follow /Users/jlin/Documents/toji/UNBOUND/AGENTS.md.
Work only in /Users/jlin/Documents/toji/UNBOUND-integration.
Use simulator iPhone 17 Pro Max.
Use DerivedData /private/tmp/unbound-dd-verify.
Merge implementation branches one at a time, verify, and report.
Do not do major feature work unless explicitly assigned.
```

### XcodeBuildMCP Defaults

Before any XcodeBuildMCP build/run/test, set the lane defaults. Example for Agent A:

```json
{
  "projectPath": "/Users/jlin/Documents/toji/UNBOUND-agent-a/UNBOUND.xcodeproj",
  "scheme": "UNBOUND",
  "configuration": "Debug",
  "simulatorName": "iPhone 17",
  "simulatorPlatform": "iOS Simulator",
  "derivedDataPath": "/private/tmp/unbound-dd-a"
}
```

For raw `xcodebuild`, always pass `-derivedDataPath`:

```bash
xcodebuild \
  -project /Users/jlin/Documents/toji/UNBOUND-agent-a/UNBOUND.xcodeproj \
  -scheme UNBOUND \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -derivedDataPath /private/tmp/unbound-dd-a \
  build
```

### Simulator Rules

- Implementation agents should not use the simulator unless their task truly requires visual or runtime validation.
- If an implementation agent uses a simulator, it must use only its assigned simulator.
- The verification agent is the default owner of final simulator testing.
- If simulator verification is needed but the lane is busy, write a handoff request instead of interrupting the simulator agent.

## RALPH Quality Loop

Agents should not optimize only for "compiled." Use this loop:

- Read: understand the user intent, existing patterns, and success criteria.
- Act: make the smallest coherent change.
- Look: verify locally using compile, static inspection, previews, assets, or simulator depending on lane.
- Polish: compare against UNBOUND taste criteria and make one focused improvement pass if needed.
- Handoff: report proof, risks, and exact verification needs.

For UI work, "good" means:

- It feels native to UNBOUND's anime training-arc product.
- It is readable on phone-sized screens.
- The visual reward feels earned, not like a generic tint.
- Premium art supports the workflow instead of competing with controls.
- Copy stays direct and non-negging.
- The changed surface is discoverable without becoming noisy.

For skill tree cosmetics specifically:

- Cosmetics are asset-backed, not only color themes.
- Each cosmetic has a distinct identity.
- Hex nodes, rails, and labels remain readable over the background.
- Purple/violet is not the only dominant mood.
- Picker previews show the actual cosmetic.
- The Skill Tree screen exposes cosmetics directly.

## Agent Handoff Format

Every implementation agent should end with this:

```md
## Agent Handoff

Branch:
Worktree:
Lane:

Summary:
- ...

Files changed:
- ...

Verification done:
- ...

Needs verification:
- ...

Risks / notes:
- ...
```

## Integration Agent Closeout

The integration agent should:

- Merge implementation branches one at a time into the integration worktree.
- Resolve conflicts carefully and preserve user/agent changes.
- Build after risky merges.
- Run final simulator verification in the Verify lane.
- Make only small integration fixes unless explicitly asked for larger implementation.
- Report merged branches, build status, simulator checks, screenshots if relevant, and remaining risks.
