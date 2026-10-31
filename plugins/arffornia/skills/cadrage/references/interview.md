# Interview question bank

Pick the 1-3 most decisive unanswered questions per round. Always propose a default.

**Problem.** What is broken or missing today, for whom? What triggered this now? What
happens if we do nothing for three months?

**Players and users.** Which players (new, veteran, builders, admins, staff)? What do they
do today instead? Is it visible in French first?

**Scope.** Smallest version that is worth shipping? What is explicitly out? Which repos
(mod, website, launcher, provisioning, infra)? Does it touch progression or the shop
(gameplay decisions are Brian's)?

**Constraints.** Must it run offline / on the homelab / on low-end PCs? Performance budget
(tick time, download size)? Libraries to reuse (Nexus_*, existing ADRs)? Deadline (a season
start, an event)?

**Success.** How do we know it worked: a metric, a player behaviour, a support question that
stops? Which test proves it?

**Risks.** What could hurt players' worlds or accounts? Security surface (packets, IPC,
endpoints, downloads)? What is one-way (data migrations, world data)?

**Ownership.** Who maintains it after launch? What is the support path when it breaks?
