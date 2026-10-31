# Model choice per role

Rule: **quality over tokens.** A role moves off Opus only where public evidence shows little or
no loss for that kind of work, and our own evals (`evals/`) confirm it. Everything else stays on
Opus. Prices and benchmarks below were checked on 2026-10-29; re-check when a model ships
(the harness audit does this monthly).

## The models (Claude API list prices, per million tokens)

| Model | API id (alias) | Input | Output | Cache read | Notes |
|---|---|---|---|---|---|
| Claude Fable 5.1 | `claude-fable-5-1` (`fable`) | $10 | $50 | n/a here | Slowest; for long-horizon work when Opus at high effort still falls short |
| Claude Opus 5.5 | `claude-opus-5-5` (`opus`) | $4 | $20 | $0.20 | Default model in Claude Code; "the default choice for most workloads" |
| Claude Sonnet 5.5 | `claude-sonnet-5-5` (`sonnet`) | $2 | $10 | $0.10 | "Best balance of speed and intelligence" |
| Claude Haiku 5.5 | `claude-haiku-5-5` (`haiku`) | $0.10 (≤100k prompt) / $0.50 | $0.50 / $2.50 | $0.01 / $0.05 | Fastest; classification, extraction, routing, simple subagents |

Sources: [Models overview](https://platform.claude.com/docs/en/about-claude/models/overview),
[Introducing Claude Opus 5.5](https://www.anthropic.com/claude-opus-5-5) (2026-09-22),
[Introducing Claude Sonnet 5.5](https://www.anthropic.com/claude-sonnet-5-5) (2026-09-28),
[Introducing Claude Haiku 5.5](https://www.anthropic.com/claude-haiku-5-5) (2026-10-07).

## What the benchmarks say (vendor-reported, at launch)

| Benchmark (what it measures) | Opus 5.5 | Sonnet 5.5 | Haiku 5.5 | Fable 5.1 |
|---|---|---|---|---|
| Terminal-Bench 4.0 (agentic work in a terminal) | 66.4% (xhigh) | **70.6%** | 39.2% | 55.8% |
| FrontierCode 1.1 Main (agentic coding) | **54.4%** | 52.1% (xhigh), 46.2% (max) | 46.4% | 50.3% |
| CursorBench 4.0 (agentic coding in an IDE) | **57.8%** | 55.5% | n/a | 51.8% |
| GDPval-AA v2.1 (knowledge work, Elo) | 1846 | 1844 | 1620 | 1735 |
| Humanity's Last Exam, with tools (reasoning) | **67.7%** | 64.5% | 57.4% | 65.6% |
| OSWorld 2.1 (computer use, partial credit) | **81.8%** | 80.1% | 72.4% (offline subset) | 80.7% |

Read with care:

- These are Anthropic's own launch numbers with Anthropic's scaffolds. Independent trackers had
  not published standardized runs for the 5.5 family at the time of writing; vendor scaffolds
  run well above standardized ones on SWE-bench Pro (15-30 points, per
  [morphllm's benchmark tracker](https://www.morphllm.com/claude-benchmarks), checked 2026-10-29).
- **SWE-bench Verified is not used here.** No 5.5 launch reports it, and trackers note it is
  saturated around 80-90% with a known contamination history (same source). Terminal-Bench,
  FrontierCode and CursorBench are the agentic-coding signals Anthropic now reports.
- Effort matters as much as the model: Sonnet 5.5's FrontierCode drops from 52.1% (xhigh) to
  46.2% (max). The Sonnet launch notes say that at max effort it "ran Claude Code's code-review
  skill, which splits the review across many subagents", and two runs timed out or made
  out-of-scope edits. We therefore pin **effort**, not only the model, per role.
- Field reports quoted by Anthropic: Deloitte, "Even at its lowest effort setting, Claude Opus
  5.5 caught 72% of known bugs in our code reviews" (Opus 5: 56% at high effort); CodeRabbit
  says Sonnet 5.5 "shows better judgment than Sonnet 5" and plans to move simple and moderate
  reviews to it; Anthropic says Haiku 5.5 "pairs well with Opus 5.5 and Sonnet 5.5 as a subagent
  on coding work" while Sonnet and Opus "remain better choices for complex agentic coding".
- Claude Code docs: "the default Opus 5.5 handles most coding well and Sonnet costs less on
  routine work … Haiku is a good fit for subagents doing simple jobs"
  ([best practices](https://code.claude.com/docs/en/best-practices)); "Save `max` for a hard
  problem … like hunting for a security vulnerability"; a subagent's `model` accepts
  `sonnet`, `opus`, `haiku`, `fable`, a full id or `inherit`, and a per-invocation `model`
  overrides the frontmatter ([subagents](https://code.claude.com/docs/en/sub-agents)).

## Decisions per role

| Role | Model · effort | Why (evidence) | Set in |
|---|---|---|---|
| Main session (implementer) | Opus 5.5 · default (medium; raise with `/effort` for tricky work) | Claude Code default; leads FrontierCode and CursorBench; Boris Cherny runs Opus with thinking for everything because "you have to steer it less" | user setting |
| `reviewer` (PR review on request) | Opus · high | Orchestrates and ranks; judgment-heavy; runs once per review | `agents/reviewer.md` |
| `review-finder` (correctness, rules + tests, security lenses) | **Opus · high** | Recall decides what the review can ever report. Opus leads every coding row above, Deloitte's bug-catch rate, and Sonnet at high effort showed instability in exactly this multi-subagent review setup. No downgrade | `agents/review-finder.md` |
| `review-verifier` (one claim, prove or refute) | **Sonnet · high**; at high risk a second verifier on **Opus**, both must confirm | A bounded task: read the cited lines, trace one caller, run one command. Sonnet leads Terminal-Bench 4.0 (70.6 vs 66.4) and ties on knowledge work (GDPval 1844 vs 1846) at half the price; a different model from the finder also lowers correlated blind spots. High-risk changes keep an Opus vote | `agents/review-verifier.md`, review skill |
| `security-reviewer` | Opus · max | Claude Code docs recommend `max` for vulnerability hunting; misses here are the costliest | `agents/security-reviewer.md` |
| `test-writer` | Opus · high | Writing tests from acceptance criteria is agentic coding (FrontierCode gap 54.4 vs 52.1) and the tests are the judge of the implementation | `agents/test-writer.md` |
| `verifier` (drive the real app, collect evidence) | Sonnet · high | Terminal and tool execution: Sonnet's best category (Terminal-Bench 4.0 70.6%); no edit rights; reports PASS/FAIL with evidence that the caller reads | `agents/verifier.md` |
| `doc-gardener` | Sonnet · high | Claim-by-claim checking of docs against code: knowledge work where Sonnet ties Opus (GDPval); the output is a proposal a human or the PR reviews | `agents/doc-gardener.md` |
| `fact-finder` | Sonnet · high | Extraction from code and manifests into YAML with a source per fact. Haiku considered and rejected: 39.2% vs 70.6% on Terminal-Bench and 72.4% vs 83.9% on OSWorld is too big a gap for facts that end up in architecture diagrams | `agents/fact-finder.md` |
| Built-in `Explore` | inherit (main model) | Exploration feeds every later decision; Claude Code keeps Explore on the main model by default. Not overridden | (default) |
| Mechanical sweeps (link checks, "list every importer of X") | Haiku, per invocation | Anthropic and Claude Code docs both recommend Haiku for simple subagent jobs; a wrong answer is cheap to detect | ad hoc `model: haiku` in the Agent call |
| Fable 5.1 | not used by default | 2.5x Opus price and slower; below Opus 5.5 on Terminal-Bench 4.0 (55.8 vs 66.4) and FrontierCode (50.3 vs 54.4) in Anthropic's own table. Use only when an Opus run at `xhigh` fails an eval | — |

Scheduled automations (the model is chosen in the scheduled task's prompt box, or with
`claude -p --model`; each prompt file states it):

| Automation | Model | Why |
|---|---|---|
| `weekly-brief`, `onboarding-audit`, `quality-score`, `review-feedback` | Sonnet | Reading, summarising and counting; knowledge-work parity, output reviewed by Brian |
| `doc-gardener` | Sonnet | As the agent above; draft PRs only |
| `deps-upgrade` | Opus | Changes code and fixes the breakage an upgrade causes |
| `harness-feedback` | Opus | Edits hooks, skills and rules that every future session runs on |
| `harness-audit`, `security-audit` | Opus | Judgment across many repos; security misses are costly |
| `practice-watch` | Opus | Judging which new practice deserves a change to the skill layers |
| Skip gate ("anything changed since the last run?") | none | A shell script (`automations/activity.sh`) answers it before any model starts: zero tokens |

## Is Haiku enough for mechanical tasks?

Short answer: **yes, but only for the truly mechanical ones**, and most "simple-looking" agent
work is not mechanical. Brian asked (2026-10-31) whether "mechanical" means the most basic of
the basic: it does.

What the evidence says:
- Anthropic positions Haiku 5.5 "for high-volume, latency-sensitive tasks such as
  classification, extraction, and routing" ([models overview](https://platform.claude.com/docs/en/about-claude/models/overview),
  read 2026-10-31), and Claude Code's docs say "Haiku is a good fit for subagents doing simple
  jobs" ([best practices](https://code.claude.com/docs/en/best-practices)).
- On multi-step agentic work it falls far behind: Terminal-Bench 4.0 39.2% vs Sonnet 70.6% and
  Opus 66.4%; FrontierCode 46.4% vs 52-54% (table above, Anthropic launch numbers). A loop of
  tool calls with decisions in between is exactly where the gap shows.
- Price: Haiku input is 20x cheaper than Sonnet ($0.10 vs $2 per million tokens below 100k
  prompt). The saving is real only when the task is repeated often; an occasional run saves cents.

So a task is **mechanical** (Haiku is fine) only when all of these hold:
1. One step, or a fixed sequence with no judgement between steps.
2. The output can be checked by a rule or a script (a schema, a test, "the file exists", a
   count), so a wrong answer is caught for free.
3. No code is written or changed, and nothing is decided for Brian.

| Task | Model | Why |
|---|---|---|
| "List every file that imports X", "which repos have a Makefile check target" | Haiku | Lookup; result checkable with grep |
| Classify an issue into fixed labels; route a request to a skill | Haiku | Fixed label set; a wrong label is visible and cheap |
| Extract fields into a JSON schema that a script validates | Haiku | Schema validation catches errors |
| Summarise a CI log to "first failing test + error line" | Haiku | Short, checkable against the log |
| Anything that edits code, writes tests, reviews, or verifies a claim | Sonnet or Opus | Multi-step, judgement, errors are costly to spot |
| Facts for diagrams (`fact-finder`), doc checking (`doc-gardener`) | Sonnet | Extraction across many files with judgement; Haiku tried and rejected (gap above) |
| Scheduled reports read by Brian (`weekly-brief`) | Sonnet | One run a week: the Haiku saving is cents, a missed red CI is not |

Rule for the harness: a role moves to Haiku only after its eval runs at pass^3 on Haiku with no
loss (method below). Where a script can do the job (the skip gate, link checks, guard checks),
use the script and no model at all.

## Cost per review

Estimates at API list prices, assuming each subagent reads ~150k input tokens over its tool
loop (70% served from the prompt cache) and writes ~8k output tokens, a verifier ~40k in
(60% cached) and ~3k out, and the security reviewer at max effort ~250k in and ~20k out. Real
numbers: `/usage` in the session shows the share per subagent type; `review-feedback` should
record them.

| Change | Agents | Estimated cost | All-Opus equivalent |
|---|---|---|---|
| Low risk (one combined finder, ~2 candidates) | 1 Opus finder + 2 Sonnet verifiers | **≈ $0.6** | ≈ $0.8 |
| Standard (correctness + rules/tests finders, ~6 candidates) | 2 Opus finders + 6 Sonnet verifiers | **≈ $1.3** | ≈ $1.7 |
| High / security (3 finders + security reviewer, ~8 candidates) | 3 Opus finders + Opus security reviewer + 8 Sonnet + 8 Opus verifiers | **≈ $3.6** | ≈ $4.1 |
| Delta re-review (round 2-3, small fix-ups) | 1 Opus finder + 1-3 verifiers | ≈ $0.5 | ≈ $0.6 |

**Measured on this rework (2026-10-29, `total_cost_usd` from `claude -p`, API-equivalent):**
round 1, a full high-risk review of a 2,400-code-line diff, cost **$7.19** for the four finders
alone (the run ended before verification, a bug since fixed); round 2, a high-risk delta
(353+/127− lines, 20 candidates, two verifiers each), cost **$14.28** end to end. So the
estimates above hold for task-sized diffs, while a big high-risk change with many candidates
costs several times more: the per-candidate verifier pairs dominate. Levers if that matters:
fewer, larger tasks are not cheaper; smaller PRs are; and `review-feedback` will show whether
the second (Opus) verifier at high risk changes outcomes.

For comparison, Anthropic's managed Code Review "generally costs $15-25" per review
([blog](https://claude.com/blog/code-review), 2026-03-09). On a Claude subscription these runs
draw plan usage instead of money. The Sonnet verifiers save 10-25%; the finders, where quality
is decided, stay on Opus.

## How we keep these choices honest

Following Anthropic's [Demystifying evals for AI agents](https://www.anthropic.com/engineering/demystifying-evals-for-ai-agents)
(2026-01-09) and [Harness design for long-running apps](https://www.anthropic.com/engineering/harness-design-long-running-apps)
(re-test each harness component as models improve):

1. `python3 evals/run.py reviewer --runs 3` runs every reviewer case three times; we track
   **pass^3** (all three runs pass), because a reviewer must be consistent, not lucky.
2. A model change for a role is an ablation: run the suite with the role on the old and the new
   model (`--model` for the reviewer; edit the agent's `model:` for finders and verifiers) and
   keep the cheaper one only if pass^3 does not drop and no `must_match` finding is lost.
3. `wrong` and `noise` labels from real reviews (PR markers) become regression cases; a rising
   wrong rate for a lens is a signal to move its verifier back to Opus.
