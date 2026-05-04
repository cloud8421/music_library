---
description: Plan implementation of an existing backlog task
argument-hint: "<TASK-ID>"
---

We're going to write the implementation plan for task $1.

For a plan to be valid, it has to cover these requirements:

1. **Objective alignment** — The plan clearly states how it achieves the stated objective of the issue, with a direct mapping between the problem and the proposed solution.

2. **Simplicity and alternatives considered** — The plan identifies the simplest viable approach. It documents alternatives that were evaluated, explains why they were rejected or deferred, and
justifies why the chosen approach is the right trade-off for the objective.

3. **Completeness and sequencing** — The plan covers every implementation step in a logical order. No gaps exist between "current state" and "done state." Dependencies between steps are
explicit so the plan can be executed sequentially without backtracking.

4. **Verifiability** — Each implementation step includes concrete verification instructions (tests to run, manual checks to perform, queries to validate) that prove the step was completed
correctly before moving on.

5. **Architecture impact analysis** — The plan identifies all architectural touchpoints affected by the change (schemas, contexts, PubSub topics, supervision tree, routes, external APIs, UI
components) and describes how each is impacted, including any migration or deprecation path.

6. **Performance profile** — The plan explains the performance characteristics of the chosen approach: expected runtime complexity, database query patterns (including N+1 risks), memory
footprint, and any latency or throughput implications under realistic load.

7. **Benchmarking requirements** — The plan identifies whether one-off or ongoing benchmarks are needed to validate or monitor the performance profile, and if so, specifies what to measure, how
to measure it, and what thresholds define acceptable performance.

8. **Cost profile** — If the implementation consumes paid resources (API calls, compute, storage, third-party services), the plan includes a cost estimate or model so the financial impact is
understood before implementation begins.

9. **Production infrastructure steps** — Any manual changes required in production (environment variables, service provisioning, database migrations with special handling, DNS changes, firewall
rules) are documented in a dedicated "Production Changes" section, separate from the implementation steps, with rollout and rollback instructions.

10. **Documentation updates** — The plan enumerates which project documentation files must be created or updated as part of the implementation (e.g., `docs/architecture.md`,
`docs/project-conventions.md`, README, API docs), with a summary of what changes each file needs.

At the end, do not offer to start implementation. Instead, offer to start a new session so that I can review the plan via `/review-task-plan`.
