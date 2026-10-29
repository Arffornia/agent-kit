# Do not report

From Anthropic's code-review plugin and our own wrong findings (each new wrong finding goes to
`evals/reviewer/` as a case, then here as a class).

- Issues on lines the change did not touch (→ pre-existing, at most, with proof).
- Something that looks like a bug but is correct: read the caller and the tests first.
- What the linter, formatter, type checker or `make check` already catches. Do not run the
  linter to "verify" a style point.
- General quality ("add more tests", "consider logging") unless a rule file requires it or
  the untested path is the risky one.
- A rule explicitly silenced in code with a reason (`// i18n-ignore`, `@SuppressWarnings` with
  a comment, `# noqa: reason`).
- Speculation that depends on inputs you cannot name. Name the input or drop it.
- Behaviour claims inferred from a name: cite the line that does it.
- Missing French for strings that are not player-facing (logs, admin CLI, exceptions).
- Suggestions to replace Nexus_* libraries with third-party ones (a hard rule says improve them).
- "Hardcoded secret" on placeholders such as `${CFG_*}`, `changeme`, or `.env.example` values.
