# AGENTS.md

## Purpose

This repository should be modified with the smallest safe change necessary to satisfy the user's request.

Primary goals:

1. Preserve existing correct behavior.
2. Limit work to the explicitly requested scope.
3. Avoid unnecessary repository-wide exploration, refactoring, regeneration, or repeated retries.
4. Keep tool usage, context usage, and test execution proportional to the task.
5. Prefer clear evidence over speculative changes.

---

## Core operating rules

### 1. Scope first

Before editing, identify:

- the requested behavior,
- the smallest likely set of files involved,
- the relevant existing tests,
- any directly related configuration.

Do not inspect the entire repository unless the request genuinely requires it.

Do not perform repository-wide audits unless explicitly asked.

Do not expand the task into adjacent improvements, cleanup, modernization, or redesign.

If the requested change appears to require a much broader investigation than expected, explain why before expanding scope.

---

### 2. Make the smallest safe diff

Prefer:

- editing existing code instead of rewriting whole files,
- reusing existing patterns and utilities,
- changing only directly relevant files,
- preserving current architecture unless architecture change is requested.

Avoid:

- broad refactors,
- formatting unrelated files,
- renaming unrelated symbols,
- reorganizing folders,
- replacing working implementations for stylistic reasons,
- dependency upgrades unless required,
- "while we're here" improvements.

Do not change behavior that is unrelated to the user's request.

---

### 3. Preserve known-good behavior

Treat existing working behavior as a constraint.

Before modifying a shared function, component, service, rule, or configuration:

- check its direct callers/usages,
- identify the behavior that must remain unchanged,
- prefer a narrow conditional or isolated addition when practical.

Do not knowingly trade one working path for another without explicit approval.

---

### 4. Read only what is needed

Start with the most relevant files and expand outward only when evidence requires it.

Preferred order:

1. file named by the user,
2. directly related implementation,
3. directly related tests,
4. direct imports/callers,
5. broader repository search only if still unresolved.

Avoid repeatedly re-reading large files or the whole repository without a concrete reason.

When the cause is already identified, stop investigating and fix it.

---

### 5. Separate investigation from implementation

For unclear bugs:

1. inspect the minimum relevant code,
2. form a concrete hypothesis,
3. verify it with existing evidence or a targeted test,
4. make the smallest change,
5. test the changed path.

Do not make multiple speculative edits at once.

If the first hypothesis is wrong, revert or abandon it before trying a materially different approach.

---

## Testing policy

### 6. Use tiered testing

Run tests in this order:

1. the nearest unit/widget/component test,
2. the directly affected feature test,
3. static analysis/lint/typecheck for the changed area if supported,
4. broader test suite only when justified.

Do not automatically run the full suite after every small edit.

Run the full suite when:

- shared core behavior changed,
- the user explicitly requests it,
- release/merge verification is requested,
- local tests indicate possible wider impact,
- the change affects authentication, data integrity, security, billing, migration, or other high-risk shared behavior.

---

### 7. Do not retry blindly

For the same failing command or test:

- inspect the failure before retrying,
- make a reasoned change before the next retry.

Do not repeat an unchanged failing command more than twice unless there is a clear transient/environmental reason.

If an external service, permission, credential, quota, emulator, port, or environment issue blocks progress, report the blocker instead of consuming repeated attempts.

---

### 8. Avoid unnecessary build work

Do not clean caches, reinstall dependencies, regenerate lockfiles, rebuild all targets, or recreate environments unless there is evidence they are causing the problem.

Avoid commands such as full clean/reinstall cycles as a default troubleshooting step.

Prefer targeted commands.

---

## Dependencies and generated files

### 9. Do not upgrade dependencies casually

Do not:

- bump package versions,
- regenerate package locks,
- change SDK constraints,
- migrate frameworks,
- replace libraries,

unless required for the requested task or explicitly approved.

If an upgrade is required, explain the reason and likely impact first.

---

### 10. Do not generate unnecessary artifacts

Do not create:

- extra reports,
- duplicate documentation,
- temporary scripts,
- snapshots,
- large logs,
- screenshots,
- generated files,

unless they are necessary for the task or requested by the user.

Remove temporary files created solely for debugging when finished, unless they are useful and intentionally retained.

---

## Documentation and comments

### 11. Keep documentation proportional

Update documentation only when:

- behavior visible to developers/users changed,
- setup steps changed,
- a new required environment variable/configuration was added,
- the user explicitly requested documentation.

Do not rewrite README files for unrelated edits.

Add comments only where the code would otherwise be materially harder to understand.

---

## Security and high-risk areas

### 12. Be conservative with sensitive systems

For authentication, authorization, account deletion, database rules, migrations, storage rules, secrets, payment, production infrastructure, or destructive operations:

- inspect the relevant safety contract first,
- preserve deny-by-default behavior,
- prefer explicit validation,
- test failure paths as well as success paths,
- do not weaken security to make a test pass.

Never expose secrets in code, logs, documentation, or responses.

---

## User interaction / stopping rules

### 13. Stop when the task is complete

Once the requested behavior is implemented and the appropriate targeted verification passes:

- stop editing,
- summarize what changed,
- list tests actually run,
- mention any remaining uncertainty.

Do not continue searching for additional improvements.

---

### 14. Ask before materially expanding the job

Pause and ask before:

- touching a large number of unrelated files,
- changing architecture,
- introducing a new dependency,
- replacing an existing framework/library,
- performing a database migration not already requested,
- making destructive production changes,
- changing public APIs/contracts beyond the stated requirement.

A small number of directly related files does not require confirmation.

---

## Default response format after implementation

Keep the completion report concise:

### Changed
- files changed
- behavior changed

### Verified
- exact checks/tests run
- pass/fail result

### Not changed
- important adjacent behavior intentionally left untouched

### Remaining
- only real blockers or unresolved risks

Do not produce a long narrative unless requested.

---

## Efficiency rules for repeated project work

When the repository already contains project instructions, specifications, or accepted design decisions:

- use them as the source of truth,
- do not rediscover settled decisions from scratch,
- do not reinterpret stable requirements unless a conflict is found.

Prefer repository-local documentation such as:

- `AGENTS.md`
- `README.md`
- specification files
- architecture notes
- tests encoding expected behavior

over broad exploratory inference.

---

## Project-specific section

Add project-specific constraints below this line.

### Project
- Name:
- Stack:
- Main app/package:
- Main test command:
- Static analysis command:
- Build command:

### Protected behavior
- List behavior that must not regress.

### High-risk areas
- List authentication, database, production, migration, payment, account deletion, or other sensitive areas.

### Current phase constraints
- Describe only the current phase/release constraints.
- Remove obsolete temporary constraints when the phase ends.

---

## Recommended task instruction style

When assigning work, prefer a prompt like:

> Implement only the requested change.  
> First identify the smallest relevant file set.  
> Preserve existing normal behavior.  
> Do not perform unrelated refactors, dependency upgrades, repository-wide audits, or formatting sweeps.  
> Run the nearest relevant tests first.  
> Expand testing only if the change affects shared/high-risk behavior or a targeted test indicates wider impact.  
> Do not blindly retry the same failing command.  
> Stop once the requested change is implemented and appropriately verified.

For a small change, shorten it to:

> Make the smallest safe change for this request. Do not touch unrelated files. Run only the directly relevant tests unless broader verification is justified.

For a release audit, explicitly override the normal narrow-scope rule:

> This task is a release audit. Broad inspection is authorized for the areas listed below, but do not modify anything outside those areas without identifying the reason first.
