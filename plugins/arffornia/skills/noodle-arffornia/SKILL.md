---
name: noodle-arffornia
description: "Update the Arffornia architecture model and diagrams in the docs repo (architecture/arffornia: discover from infra, match discovered objects, edit model/views/layouts, lint, export PNG/SVG headless with draw.io). Use when infra, a service, a connection or a flow of Arffornia changed, when a diagram in arffornia.github.io/docs is wrong or missing, or when asked to update the architecture docs."
argument-hint: "[view id | what changed]"
paths:
  - "architecture/**"
  - "docs/architecture/**"
---

# Update architecture/arffornia (docs repo)

Change: `$ARGUMENTS`. The docs repo (https://github.com/Arffornia/docs) holds one Noodle
system, `architecture/arffornia/`: `model.yaml` (what exists), `views/*.yaml` (what each
diagram shows), `layouts/*.yaml` (where topology views draw), `discovered/*.yaml` (generated
from the infra repo). Diagrams are generated: never hand-edit `.drawio` exports. The house
style and model format are Noodle's own skill (`noodle-diagram`, `reference.md` in
TheGostsniperfr/Noodle); read its reference before editing YAML. This skill is the Arffornia
workflow around it.

## 1. Discover (infra facts)

```bash
make discover INFRA=../infra        # kustomize build --enable-helm per overlay → noodle discover k8s
```
Overlays and namespaces are listed in `scripts/discover.sh`; a new Arffornia app in
`k8s/config/arffornia/` needs a line there first.

## 2. Match and find drift

```bash
python3 ${CLAUDE_SKILL_DIR}/scripts/drift.py architecture/arffornia
```
`GONE` = a `matches` id in `model.yaml` that discovery no longer finds (renamed or deleted:
fix the model). `UNMATCHED` = a discovered object with no curated element (model it, or decide
it is out of scope). `CONN` = a discovered connection between curated elements that the model
lacks. Code facts for application-level flows (routes, packets, IPC, API calls) come from the
`arffornia:fact-finder` agent: give it the question and the repo paths, work from its sourced
inventory, and open files only to settle its `unknowns`.

## 3. Edit

Extend `model.yaml` (stable kebab-case ids, `matches` for discovered objects, `src` facts),
then the view that answers the question (one question per view, its subtitle), then the
layout for topology views. Workflow details, conventions specific to this model and the
review checklist: [references/workflow.md](references/workflow.md).

## 4. Lint, export, look

```bash
CHECK_ONLY=1 ${CLAUDE_SKILL_DIR}/scripts/export.sh          # noodle check + lint of every view
${CLAUDE_SKILL_DIR}/scripts/export.sh <view> [<view>...]    # dark + light: .drawio, PNG, editable SVG
make check                                                  # lint + mkdocs build --strict (what CI runs)
```
`export.sh` runs draw.io headless under `xvfb-run` with
`--no-sandbox --use-angle=swiftshader --enable-unsafe-swiftshader` (without them the PNG is
empty or black) and caps the PNG scale at `min(2, 3900 / (pageWidth + 40))`, because headless
exports wider than ~3900 px are cropped. It fails if a PNG comes out empty. `make diagrams`
renders every view the same way when `DRAWIO` is set to the headless command.

**Look at the PNGs** (Read the image): the lint checks geometry, not meaning. Expect two or
three rounds. Then commit model, views, layouts and the exports in `docs/assets/diagrams/`
together (`docs(architecture): ...`).

Report per [references/reporting.md](references/reporting.md): the PR, the views changed (PNG
paths or URLs), drift left on purpose, and code-vs-docs gaps found.
