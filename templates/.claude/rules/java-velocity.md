---
paths:
  - "src/main/java/**/*.java"
  - "build.gradle*"
  - "src/main/resources/**"
---

# Velocity / Java 17 conventions (Arffornia_Proxy)

- The plugin has one job: forward NuVotifier votes to the website API. Routing, auth and
  whitelisting live in the Velocity config in `infra`, not here.
- **Never block the proxy event thread**: event handlers return fast; HTTP runs async
  (`HttpClient.sendAsync`) or on the Velocity scheduler.
- **HTTP**: `connectTimeout` on the client, `.timeout()` on each request, status checked,
  exactly one re-auth on 401, bounded retry with backoff. An unbounded retry loop is a bug.
- **Config** comes from the plugin data dir (`config.properties`), with secrets as placeholders
  replaced at deploy time; defaults use `https://`.
- Pin dependencies to releases, not `-SNAPSHOT` (velocity-api) and not jitpack `main`.
- Log through the injected SLF4J `Logger`; never log tokens or the forwarding secret.
- Tests: JUnit with a stub HTTP server for the API client (success, 401 → re-auth, 5xx, timeout).
- Gradle: `--no-daemon -Dorg.gradle.jvmargs=-Xmx2g`.
