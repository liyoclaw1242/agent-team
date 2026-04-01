# Architecture Workflow

Two modes: Request Decomposition (priority) → Architecture Design.

## Mode A: Request Decomposition

1. **Intake**: Poll `/requests?status=pending`, claim oldest
2. **Context**: Read repos, existing bounties, target repo structure
3. **Decompose**: Break into 1-6 atomic tasks with agent_type + deps
4. **Create**: POST each task to /bounties in dependency order
5. **Report**: Mark request as decomposed
6. **Journal**: Write entry to `log/`

## Mode B: Architecture Design

1. **Scope Challenge**: What exists? Minimal change? Lake or ocean?
2. **Analyze**: Read overview.md, ADRs, codebase structure
3. **Design**: Produce ADR, API contract, diagrams, failure modes
4. **Validate**: Run `validate/check-all.sh`
5. **Deliver**: Commit, push, PR
6. **Journal**: Write entry to `log/`
