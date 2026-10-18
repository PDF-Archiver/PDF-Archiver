# Issue tracker: GitHub, specs in the vault

Tickets for this repo live as GitHub issues; use the `gh` CLI for them. Specs do not: a spec is a note in the Obsidian vault at `~/KnowledgeBase/Resources/PDF Archiver/spec/` (decided 2026-10-18).

## Conventions

- **Create an issue**: `gh issue create --title "..." --body "..."`. Use a heredoc for multi-line bodies.
- **Read an issue**: `gh issue view <number> --json number,title,body,labels,comments`.
- **List issues**: `gh issue list --state open --json number,title,body,labels,comments --jq '[.[] | {number, title, body, labels: [.labels[].name], comments: [.comments[].body]}]'` with appropriate `--label` and `--state` filters.
- **Make an issue a sub-issue of a parent**: `gh issue create --parent <parent> ...`, or `gh issue edit <parent> --add-sub-issue <child>` afterwards (`gh` 2.94+). Older `gh`: `gh api --method POST repos/<owner>/<repo>/issues/<parent>/sub_issues -F sub_issue_id=<child-db-id>` (database id, as in **Blocking** below). Without sub-issues, put `Part of #<parent>` at the top of the child body.
- **Comment on an issue**: `gh issue comment <number> --body "..."`
- **Apply / remove labels**: `gh issue edit <number> --add-label "..."` / `--remove-label "..."`
- **Close**: `gh issue close <number> --comment "..."`

Infer the repo from `git remote -v`; `gh` does this automatically when run inside a clone.

## Pull requests as a triage surface

**PRs as a request surface: no.** _(Set to `yes` if this repo treats external PRs as feature requests; `/triage` reads this flag.)_

When set to `yes`, PRs run through the same labels and states as issues, using the `gh pr` equivalents:

- **Read a PR**: `gh pr view <number> --comments` and `gh pr diff <number>` for the diff.
- **List external PRs for triage**: `gh api --paginate 'repos/{owner}/{repo}/pulls?state=open' --jq '.[] | select(.author_association | IN("OWNER","MEMBER","COLLABORATOR") | not) | {number, title, author: .user.login, author_association, labels: [.labels[].name]}'`.
- **Comment / label / close**: `gh pr comment`, `gh pr edit --add-label`/`--remove-label`, `gh pr close`.

GitHub shares one number space across issues and PRs, so a bare `#42` may be either: resolve with `gh pr view 42` and fall back to `gh issue view 42`.

## When a skill says "publish to the issue tracker"

- **A spec** (`/to-spec`): write it to the vault, never as an issue. Rules under **Specs** below.
- **A ticket** (`/to-tickets`, `/triage`, `/wayfinder`): create a GitHub issue. A ticket cut from a spec starts its body with `Spec: ~/KnowledgeBase/Resources/PDF Archiver/spec/<file>.md`.

## When a skill says "fetch the relevant ticket"

Run `gh issue view <number> --comments`. If the body starts with a `Spec:` line, read that vault note too; it is the source of the ticket.

## Specs

- **Path and name:** `~/KnowledgeBase/Resources/PDF Archiver/spec/<topic>--<short-claim>.md`, kebab-case, at most 50 characters. Read `~/KnowledgeBase/CLAUDE.md` before the first write.
- **Frontmatter:** `type: task`, `tags: [spec]`, `project: "[[PDF Archiver]]"`, `status: Offen`. The vault's `Tasks.base` lists every spec whose status is not `Erledigt`; keep those two German values, the view filters on them.
- **Body:** English. A TL;DR callout, then the `/to-spec` template's sections as it ships them (Problem Statement, Solution, User Stories, Implementation Decisions, Testing Decisions, Out of Scope, Further Notes), then `## Related` with at least one wikilink. Add the spec to the "Specs" list in the vault hub.
- **Label:** none on the spec; `ready-for-agent` goes on the tickets cut from it.
- **Done:** once the last ticket closes, set `status: Erledigt`. An implementation decision that is hard to reverse and binds code beyond the feature becomes an ADR in the sibling `adr/` folder, linked under Related; the spec itself is never an ADR.
- **No vault on this machine** (cloud session, CI): say so and stop. Never write the spec into the repo or into an issue instead.

## Wayfinding operations

Used by `/wayfinder`. The **map** is a single issue with **child** issues as tickets.

- **Map**: a single issue labelled `wayfinder:map`, holding the Notes / Decisions-so-far / Fog body. `gh issue create --label wayfinder:map`.
- **Child ticket**: an issue linked to the map as a GitHub sub-issue (see **Make an issue a sub-issue of a parent**). Where sub-issues aren't enabled, add the child to a task list in the map body and put `Part of #<map>` at the top of the child body. Labels: `wayfinder:<type>` (`research`/`prototype`/`grilling`/`task`). Once claimed, the ticket is assigned to the driving dev.
- **Blocking**: GitHub's **native issue dependencies**, the canonical, UI-visible representation. Add an edge with `gh api --method POST repos/<owner>/<repo>/issues/<child>/dependencies/blocked_by -F issue_id=<blocker-db-id>`, where `<blocker-db-id>` is the blocker's numeric **database id** (`gh api repos/<owner>/<repo>/issues/<n> --jq .id`, _not_ the `#number` or `node_id`). GitHub reports `issue_dependencies_summary.blocked_by` (open blockers only, the live gate). Where dependencies aren't available, fall back to a `Blocked by: #<n>, #<n>` line at the top of the child body. A ticket is unblocked when every blocker is closed.
- **Frontier query**: list the map's open children (`gh issue list --state open`, scoped to the map's sub-issues / task list), drop any with an open blocker (`issue_dependencies_summary.blocked_by > 0`, or an open issue in the `Blocked by` line) or an assignee; first in map order wins.
- **Claim**: `gh issue edit <n> --add-assignee @me`, the session's first write.
- **Resolve**: `gh issue comment <n> --body "<answer>"`, then `gh issue close <n>`, then append a context pointer (gist + link) to the map's Decisions-so-far.
