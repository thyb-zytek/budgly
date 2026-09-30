# Budgly — Agent rules and refactor process

This file is the working contract for coding agents working on Budgly. It defines product invariants, architectural intent, safe change rules, and the evidence required before claiming a result.

## 1. Core principles

- Preserve product behavior unless the task explicitly changes it.
- Prefer the smallest coherent change that fixes a verified problem or improves a documented contract.
- Do not add architecture, abstractions, factories, repositories, managers, wrappers, or dependencies without a concrete, demonstrated benefit.
- A refactoring opportunity is not automatically technical debt. Distinguish observations, defects, measurable gaps, risks, and recommendations.
- Never trade offline correctness, session isolation, data ownership, or financial correctness for simpler code.
- Keep one class/widget per file whenever practical.
- Prefer stateless widgets; business and UI state belongs in Riverpod notifiers/ViewModels unless a framework lifecycle concern requires otherwise.
- Do not introduce new global mutable state or new singleton access.
- Keep changes focused. Do not mix unrelated cleanup into a behavioral or architectural change.

## 2. Architectural intent

The intended flow is:

```text
UI/View → Riverpod Notifier/ViewModel → Service → persistence/remote provider
```

- Riverpod is the application composition and dependency-injection boundary.
- Services receive runtime dependencies explicitly.
- Providers compose concrete dependencies and lifecycle-bound application resources.
- A truly process-wide resource may remain unique when its lifecycle is inherently application-wide, but access must remain controlled through the application composition boundary.
- Reactive shared application state belongs to Riverpod sessions/notifiers.
- Services own orchestration and technical concerns such as cache coordination or reconciliation; they must not become an accidental second reactive source of truth.
- Remote providers own backend-specific I/O and semantics.
- Local/cache structures must have a clearly defined scope and purpose.

Architectural intent describes the contract to preserve or deliberately change. It must never be treated as proof that the implementation already conforms.

## 3. Current data and domain invariants

The current shared reactive state is held by the Riverpod sessions for profile, accounts, categories, expenses, and account budgets.

`LocalCache` is durable local state used for startup/offline behavior and has an intended shared-instance scope.

`ExpensePeriodCache` is a technical optimistic/reconciliation mechanism for expenses. It is not a replacement for the reactive expense session.

Feature-local collections are allowed when they represent a concrete UI concern such as pagination or transient presentation state. They must not silently become a second application-wide source of truth.

Product invariants:

- Business dates are calendar dates only. Time-of-day must not change business-period semantics.
- Recurring expenses must preserve creation/effective dates, recurrence rules, exceptions, moved occurrences, inclusive end dates, month lengths, and leap years.
- Upward amount rounding is intentional.
- Account/category ownership must be preserved across all relevant persistence and synchronization paths.
- Every durable offline mutation carries authenticated Firebase user ownership independently of the domain payload.
- Never enqueue or replay a mutation without an authenticated owner.
- A session change invalidates work belonging to the previous authenticated session.

## 4. Offline and synchronization invariants

- Never drop a pending mutation merely because a local operation succeeded or was acknowledged locally.
- Preserve ordering where ordering is part of the entity contract.
- Retries must be safe and idempotent.
- Creates that can suffer an ambiguous timeout should use deterministic identities before the first remote attempt when the backend supports idempotent writes.
- Multi-write mutations must use stable identities so retries target the same remote documents.
- Remote refreshes must reconcile with pending local mutations rather than blindly overwriting them.
- A failure affecting one entity must not unnecessarily block unrelated entities.
- Firestore's native offline mechanism remains the expense write queue; do not introduce a second application queue for the same expense documents.
- Cross-backend cleanup must remain durable, retryable, idempotent, and ownership-aware.

## 5. UI, responsive design, and presentation

- Keep `flutter_screenutil_plus` as part of Budgly's responsive strategy.
- Prefer centralized responsive tokens and design values.
- Do not alter layout, typography, navigation, or interaction semantics during a structural refactor unless explicitly requested or required to fix a verified regression.
- Framework controllers (`TextEditingController`, `ScrollController`, `PageController`, `GlobalKey`, etc.) should remain tied to framework/view concerns unless a concrete contract requires otherwise.

## 6. Safe change process

### Before changing code

1. Read the relevant production code, tests, generated code, documentation, and dependency wiring.
2. Search usages and callers before changing an API, ownership boundary, or lifecycle contract.
3. Identify the behavior or invariant that must remain true.
4. Determine whether the task is a bug fix, refactor, behavior change, audit, or cleanup.
5. Define the validation needed to prove the change.

### During implementation

- Make the smallest coherent change.
- Update production code and affected tests together.
- Do not weaken or delete assertions merely to obtain green tests.
- If a test contradicts the documented product/domain contract, fix the test and record why.
- Remove compatibility code only after all references have migrated and the old path is no longer needed.
- Do not replace a working pattern with a "cleaner" abstraction without demonstrating the concrete gain.

### Before completion

- Inspect the final diff and working tree.
- Format changed code.
- Run static analysis.
- Run the smallest relevant tests first, then the appropriate broader suite.
- Regenerate generated files through the project tooling when required.
- Update the relevant thematic documentation when behavior, architecture, contracts, or progress changed.
- Re-read the final diff for accidental behavior changes, missing tests, dead code, and inconsistent dependency wiring.

When the user asks to correct analysis/test errors after a large refactor, fix the reported issues rather than changing the expected behavior to make the suite pass, then re-run the relevant validation at the end.

## 7. Evidence and verification

The repository is the primary evidence for the current implementation.

Use the following distinction:

```text
Documented intent → what should be true
Current source code → what is implemented
Test/runtime output → what was actually observed
```

When these disagree, do not silently reconcile them. Report the discrepancy and use the strongest available evidence for the specific claim.

Rules:

- Never state a project fact from memory when it can be checked in the current checkout.
- Quantitative claims require a reproducible command, query, or generated report.
- Do not estimate counts of files, tests, coverage, occurrences, or duplication.
- Scope searches to the relevant code when making scoped claims.
- Do not infer duplication from names, file sizes, or similar structure alone. Compare behavior, API, ownership, and callers.
- Do not infer that something is untested from directory layout alone. Inspect the actual test files, runners, CI, and wrappers.
- Do not infer that dependency injection is correct merely because a constructor accepts a dependency. Verify the production composition path and any fallback or manual construction.
- Do not infer that two state holders are redundant until their ownership, lifetime, readers, writers, and purpose are understood.
- Do not treat a class being large, a dependency list being long, or a `ref.read`/`ref.watch` ratio as proof of an architectural defect.
- Do not claim a performance improvement without measurement when runtime performance is the subject of the claim.
- Do not convert a test-coverage percentage into a statement about functional correctness.
- Do not convert low test coverage of an analytics wrapper into proof that analytics events are missing.
- Do not use arbitrary thresholds unless they are defined by a project requirement or supported by measurement.
- Do not assign numerical quality/confidence scores unless a reproducible scoring method has been explicitly defined.
- When evidence is unavailable, say so explicitly.

For important conclusions, prefer this structure:

```text
Observed fact
→ evidence
→ interpretation
→ impact
→ recommendation (only if justified)
```

## 8. Testing and validation priorities

Prioritize validation by contract risk rather than raw coverage:

1. offline synchronization and retries;
2. authentication and session ownership boundaries;
3. expense dates, recurrence, and occurrence exceptions;
4. optimistic mutations and remote revalidation;
5. account/category ownership;
6. financial calculations;
7. navigation/startup behavior affected by the change.

### Test environment

- Verify the active Flutter/Dart version before diagnosing SDK- or formatter-specific behavior.
- Treat the CI workflow and project test tooling as authoritative for how suites are intended to run.
- A skipped integration suite is not equivalent to a passing integration suite.
- Machine-readable test/coverage reports are evidence only for the run that produced them; regenerate stale reports when necessary.

### Failure handling

Before modifying a failing test, classify the failure:

- production regression;
- outdated test contract;
- fixture/mocking gap;
- environment/toolchain problem;
- unrelated pre-existing failure.

Then choose the smallest appropriate correction.

## 9. Dependency injection and lifecycle

- Providers compose concrete service dependencies.
- Runtime dependencies that form part of a service's production contract should be required where practical.
- Prefer explicit constructor dependencies over nullable parameters with hidden fallback construction.
- Avoid direct access to global clients or manual construction of application dependencies when those dependencies belong to the Riverpod composition boundary.
- Test doubles should be injectable through the same boundary used by production code whenever practical.
- If a legacy fallback or singleton remains temporarily, document its purpose and migration condition rather than extending it.
- Application-owned lifecycle/state resources must be created and disposed through Riverpod or an explicit composition root.

## 10. Startup and runtime performance

- Keep `main()` focused on dependencies required to construct the first frame and the application graph.
- Do not block `runApp()` on non-critical analytics, telemetry, Crashlytics, Google Sign-In setup, sync replay, remote profile hydration, or feature data unless the contract requires it.
- Defer non-critical initialization to an explicit post-first-frame lifecycle point and keep it retry-safe.
- Prefer local/cache state for the first render, with asynchronous remote revalidation afterwards.
- Startup optimization must preserve authentication/session ordering.
- Static inspection can identify potential hotspots; runtime profiling is required before claiming measured performance behavior.

## 11. Security and ownership

- Never add real credentials, tokens, personal data, or secrets to source, tests, logs, documentation, snapshots, or generated artifacts.
- Firebase authentication is the identity source for Supabase access.
- Ownership and RLS behavior are runtime contracts. A migration or policy definition proves intended configuration, not necessarily the deployed behavior.
- When a change affects authentication, ownership, sync ownership, or RLS assumptions, validate the affected contract with focused tests or runtime verification where practical.
- Distinguish clearly between source configuration and deployed configuration.

## 12. Audit and refactoring discipline

For audits and architectural reviews:

- Start from verified repository facts.
- Compare implementation against documented intent rather than assuming either one is correct.
- Trace important dependencies and production call paths instead of judging isolated files.
- Validate counterexamples and existing mitigations before declaring a problem.
- Separate facts, interpretation, risk, recommendation, and priority.
- Treat refactoring opportunities as optional until a concrete benefit or gap is demonstrated.
- Do not preserve a previous audit conclusion just because it appears in project documentation.
- Do not replace an implementation with a different pattern simply because that pattern is common elsewhere.
- Do not recommend work that is already implemented or covered by an existing test.
- Prioritize using impact, confidence, regression risk, implementation cost, and dependency ordering.
- Do not let the AGENTS.md itself become a substitute for inspecting the current code.

When documentation, previous audits, or comments conflict with current code, explicitly report the conflict rather than forcing the implementation to match the documentation.

## 13. Documentation and handoff

- Keep documentation thematic rather than creating one status file per checkpoint.
- `AGENTS.md` contains stable rules and high-value verification guardrails.
- Detailed historical progress belongs in the thematic documentation.
- Update only the documentation made necessary by the change or audit.
- Every delivered archive must include `AGENTS.md` and the current required thematic documentation.
- Never claim that tests, analysis, coverage, profiling, or runtime validation were performed unless they were actually performed in the current session.

## 14. Definition of done

A change is complete when:

- intended behavior is implemented;
- dependency wiring matches the intended composition boundary;
- relevant tests and fixtures match the current contract;
- generated code/configuration is current when applicable;
- formatting and static analysis are clean for the changed scope;
- the appropriate broader validation has been run when available;
- relevant documentation is updated when architecture or contracts changed;
- no competing old/new pattern remains active unless the transition is intentional and documented.
