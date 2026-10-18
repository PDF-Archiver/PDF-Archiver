# Domain Docs

How the engineering skills should consume this repo's domain documentation when exploring the codebase.

## Before exploring, read these

- **`GLOSSARY.md`** at the repo root, or
- **`GLOSSARY-MAP.md`** at the repo root if it exists: it points at one `GLOSSARY.md` per context. Read each one relevant to the topic.
- **`~/KnowledgeBase/Resources/PDF Archiver/adr/`**: read the ADRs that touch the area you're about to work in. They live in the Obsidian vault, not in this repo (decided 2026-10-18); where a skill names `docs/adr/`, it means this vault path. Never create `docs/adr/` in this repo. `CLAUDE.md` lists them under "Domain docs".

If the glossary doesn't exist, **proceed silently**; the `/domain-modeling` skill (reached via `/grill-with-docs` and `/improve-codebase-architecture`) creates it lazily when terms actually get resolved. If the vault is not on this machine, as in a cloud session or CI, also proceed silently and don't write ADRs anywhere else.

## Writing an ADR

The vault's own `~/KnowledgeBase/CLAUDE.md` sets the rules for notes; read it before the first write. An ADR is German, named `adr-NNN--<kurze-behauptung>.md` with the next free number, frontmatter `type: explanation` and `tags: [adr]`. The sections are a TL;DR callout, then Kontext, Entscheidung, Folgen, Verworfene Alternativen, Verwandt. Add it to the ADR index in the vault hub `PDF Archiver.md` and to "Domain docs" in this repo's `CLAUDE.md`.

## File structure

```
/
├── GLOSSARY.md
└── ArchiverLib/

~/KnowledgeBase/Resources/PDF Archiver/adr/
├── adr-001--ocr-marker-mit-version.md
└── …
```

## Use the glossary's vocabulary

When your output names a domain concept (in an issue title, a refactor proposal, a hypothesis, a test name), use the term as defined in `GLOSSARY.md`. Don't drift to synonyms the glossary explicitly avoids.

If the concept you need isn't in the glossary yet, that's a signal: either you're inventing language the project doesn't use (reconsider) or there's a real gap (note it for `/domain-modeling`).

## Specs are not ADRs

A spec says what one feature builds and is finished when its tickets close; an ADR says why the code is the way it is and stays true until it is edited. A spec yields an ADR only for a decision that is hard to reverse and binds code beyond the feature; most yield none. Specs: see `docs/agents/issue-tracker.md`.

## Flag ADR conflicts

If your output contradicts an existing ADR, surface it explicitly rather than silently overriding:

> _Contradicts ADR-003 (derived read model), but worth reopening because…_
