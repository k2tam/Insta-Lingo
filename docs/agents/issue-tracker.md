# Issue tracker: GitHub

Specs and implementation tickets for this repository live in GitHub Issues at `k2tam/TransAtGlance`. Use the `gh` CLI to read, create, label, and inspect issues.

- Read an issue's complete body and comments before using it as a source: `gh issue view <number> --comments`.
- Create one issue per implementation ticket. Link its source issue in a `Parent` section without modifying or closing the source issue.
- Apply the `ready-for-agent` label to agent-ready implementation tickets.
- Create blockers first. Represent blocking edges with GitHub issue dependencies when available. If unavailable, put issue references in the ticket's `Blocked by` section.
- A ticket is ready to claim when all blocking issues are closed and it is not already claimed. Among ready tickets, start with the earliest ticket in the approved breakdown.

Pull requests are not a triage request surface for this repository.
