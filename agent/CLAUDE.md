# Antonio's agent instructions

These are common instructions for Antonio's agents across all scenarios.

## General Guidelines

- Never use the em dash "—". Use plain dash "-" instead
- When writing commit messages, NEVER auto-add your agent name as co-author
- Never manually modify CHANGELOG.md files or any files that are marked as auto-generated
- When writing or substantially editing long Markdown files, put each full sentence on its own line.
  Preserve normal Markdown structure, but avoid wrapping multiple sentences onto one physical line.
- When making technical decisions, do not give much weight to development cost.
  Instead, prefer quality, simplicity, robustness, scalability, and long term maintainability.
- When doing bug fixes, always start with reproducing the bug in an E2E setting as closely aligned with how an end user would hit it.
  This makes sure you find the real problem so your fix will actually solve it.
- When end-to-end testing a product, be picky about the UI you see and be obsessed with pixel perfection.
  If something clearly looks off, even if it is not directly related to what you are doing, try to get it fixed along the way.
- Apply that same high standard to engineering excellence: lint, test failures, and test flakiness.
  If you see one, even if it is not caused by what you are working on right now, still get it fixed.
- When working on a project, at the root directory of the project create CLAUDE.md and symlink it with AGENT.md.
  Do not fill it up at first, but over time as I talk to you, you can add what you think you should remember about the project,
  or store corrections that I give you so you do not make the same error over again.
- When editing the project level CLAUDE/AGENT.md, add only what you think is necessary by keeping in mind that if we add something, it should be saving us tokens and time later.

## Antonio's Opinions

When you are working on something that would benefit from being informed by Antonio's viewpoints, read ~/OPINIONS.md to understand them.

## Voice Profile

When you are talking/posting on behalf of Antonio using his identity, read ~/VOICE.md to see how Antonio talks.

## Axi instructions

Run `npx -y gh-axi` for Github operations
Run `npx -y chrome-devtools-axi` for browser automation
Use axi whenever applicable over cli or mcp

## Graphify-first repository navigation

For architecture, dependency, ownership, impact, or "where should I change this?" questions:

1. Query Graphify before broad grep, glob, or recursive file reads.
2. Use `query` to find the relevant subgraph.
3. Use `explain` for important symbols.
4. Use `path` when tracing cross-module dependencies.
5. Read the actual source files and tests before editing.
6. Treat INFERRED and AMBIGUOUS graph edges as leads to verify, not proof.
7. After a meaningful architectural change, refresh the graph or let the Git hook do it.
