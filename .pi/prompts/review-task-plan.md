---
description: Review for a task plan
argument-hint: "<TASK-ID>"
---

We're going to review the implementation plan for task $1.

Perform the review considering:

1. Does the plan achieve the objective of the issue?
2. Is the plan too complex for the objective of the issue? Are there alternatives that should be considered and that could achieve an equal result with a simpler implementation?
3. Is the plan thorough, covering all implementation steps in a reasonable order?
4. Are there clear instructions and verification steps that guarantee the soundness of the implementation?
5. Does the plan take into account any significant architecture variation, and its impact on the rest of the application?
6. Is the performance profile of the chosen implementation route clearly explained and understood?
7. Does the implementation require benchmarks (either one off or regular ones)?
8. If the implementation requires using paid resources, does the plan include a cost prediction/profile?
9. In case the implementation requires manual steps in the production infrastructure (e.g. setting new environment variables, provisioning resources, etc.), are these steps clearly documented in a separate section?
10. Does the plan include instructions on what documentation needs to be created or updated?
