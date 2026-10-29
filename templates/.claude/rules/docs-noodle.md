---
paths:
  - "docs/**/*.md"
  - "mkdocs.yml"
  - "architecture/**"
  - ".noodle/**"
---

# Docs (MkDocs) and diagrams (Noodle) conventions

- English, short sentences, one idea per paragraph. Every page answers a question a reader has;
  put the answer first.
- `make check` = `make lint-diagrams` + `mkdocs build --strict`: broken links and warnings fail.
- **Diagrams are code**: edit the Noodle model under `architecture/<system>/` (model, views,
  layouts), never the exports in `docs/assets/diagrams/` (they come from `make diagrams`).
  Draw from evidence (repo files, rendered manifests); note the source commit in the view `meta`.
- `noodle render <system> -view <id> -icons .noodle/icons` must print nothing (check + lint).
  An unknown icon only fails with `-o`, so run `make diagrams` before claiming the export works.
- Export both themes (dark + light), PNG + editable `.drawio.svg`; PNG width stays under ~3900 px
  (headless draw.io crops wider exports).
- Kubernetes facts come from `make discover INFRA=../infra`, not from memory.
- Mermaid is fine for small inline sketches; architecture views use Noodle.
- Link to code with full GitHub URLs pinned to a commit when the line matters.
