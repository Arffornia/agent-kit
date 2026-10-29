# Verify result shape

```
Verify: 4/5 checks passed · 1 not run · Playwright-Electron (xvfb), Vitest
Target: https://github.com/Arffornia/Arffornia_Launcher_V.5.2/tree/fix/31-vote-ranking @ 3f2a9c1

1. PASS  Vote ranking shows a number for every player
         xvfb-run -a npx playwright test -g "vote ranking" → 1 passed (14.2s)
         evidence: build/verify/2026-10-29-votes/ranking-en.png
2. PASS  A player with 0 votes shows "0", not "undefined"
         evidence: build/verify/2026-10-29-votes/ranking-zero.png
3. PASS  Unit: formatVotes() handles null, 0 and large numbers
         npx vitest run src/renderer/src/utils/votes.test.js → 6 passed
4. FAIL  French label of the ranking header
         expected "Classement des votes", got the key "home.votes.ranking"
         repro: xvfb-run -a npx playwright test -g "fr vote ranking"
5. NOT RUN  Live vote API: no network in this environment (mocked in 1-4)

Not verified: macOS and Windows window sizes.
```

Rules: one line per check; evidence is a command with its result line, a file path or a URL;
no check is PASS without evidence; FAIL includes the reproduction command; NOT RUN includes
the reason.
