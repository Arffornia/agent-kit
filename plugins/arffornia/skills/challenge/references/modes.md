# Constraints and question bank

## Arffornia constraints every plan is tested against

- **Solo maintainer.** Brian reviews and merges everything. A design that needs constant
  human attention, many moving services or manual releases is a cost, not a detail.
- **Small machine, homelab cluster.** Gradle capped at 2 GB, one build at a time; Kubernetes
  on a home network behind Cloudflare; GPU-less CI.
- **Players on 330 mods.** Client performance, download size, joining without registry
  mismatch, French-first players.
- **Live content.** Provisioning `main` is production; the website owns progression data;
  the mod trusts nothing from clients.
- **Owner's libraries.** Nexus_* are improved, never replaced.
- **Public repos.** Security details stay out of issues until fixed.
- **Reversibility.** Prefer what can be rolled back by a revert; data migrations and world
  data changes are one-way.

## against / pre-mortem prompts

- Which assumption, if false, breaks it? How would we know early?
- What is the failure mode under load, offline, with a malicious client, with stale data?
- What does it cost Brian per week to run? Who is paged when it breaks?
- What existing thing does it duplicate or contradict (ADR, spec, library)?
- What does a player see when it fails? In French?
- What becomes impossible or expensive later (lock-in, data shape, protocol)?
- Is there a number behind the claim (tick time, download MB, cost per month)? Where from?

## alternatives prompts

Always include the smallest version that delivers most of the value, and "keep what we
have". Compare on: effort, risk, reversibility, maintenance load, player impact, security
surface, fit with ADRs. Name the decision criteria before scoring.

## jury prompts (oral exam)

- Define the problem in one sentence without naming the solution.
- Why now? What happens if we wait three months?
- Walk through the data flow for one player action. Where is it validated?
- What is the threat model? Which trust boundary does this cross?
- How do you test it? What would a failing test look like?
- How do you roll it back? What is lost?
- What did you consider and reject, and why?
- What metric tells you it worked?
