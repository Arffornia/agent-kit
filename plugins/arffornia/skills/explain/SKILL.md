---
name: explain
description: "Explain how an Arffornia module, flow or repo works from its code, with a mermaid (or Noodle) diagram and path:line sources. Use whenever someone asks how something works, how data or a request gets from A to B (a vote to a reward, a login to the game), to walk through or document a module, or to understand code before changing it."
argument-hint: "<module, path, flow or question>"
context: fork
agent: Explore
background: false
---

# Explain a module

Question: `$ARGUMENTS`. You run in a fresh context: you have only this text and the repo.
Explain from the code, not from docs or names. Every claim cites `path:line`.

## 1. Find the boundaries

Locate the entry points (routes, IPC channels, packet handlers, commands, scheduled jobs,
public functions), the data it owns (tables, files, NBT, config keys) and what it calls
outside itself (HTTP, the website API, Nexus_* libraries, the filesystem). Use Grep and Glob;
read the files that matter end to end rather than skimming many.

## 2. Trace one real path

Follow one concrete request or event from start to end (a player clicks "Buy"; a client sends
`select_recipe`; the launcher starts the game), naming each hop with `path:line`. Then note
the error paths that change the flow (401, timeout, invalid input).

## 3. Draw it

- A flow over time (requests, retries, auth): mermaid `sequenceDiagram`.
- Structure (modules, dependencies): mermaid `flowchart LR`, at most ~12 nodes.
- Deployment or cross-system architecture (Kubernetes, gateway, several repos): say that it
  belongs in the docs repo's Noodle model (`architecture/arffornia/`) and give the elements and
  connections as a list a later Noodle update can use, instead of a mermaid deployment chart.

Diagram rules: arrows go from the caller to the callee, requests only (responses as notes),
labels `verb · protocol`, one question per diagram as its title.

## 4. Write the explainer

Use the shape in [references/explainer-format.md](references/explainer-format.md): one-paragraph
summary, the diagram, the walkthrough with sources, invariants and gotchas, risks (security,
concurrency, data loss), open questions where code and docs disagree. Under ~120 lines. Do
not propose fixes unless asked; list risks as facts with sources.
