# Proxy, libraries, Provisioning, infra

- **Arffornia_Proxy (Velocity, Java 17)**: `./gradlew test --no-daemon -Dorg.gradle.jvmargs=-Xmx2g`;
  `ApiService` against a local `HttpServer` stub (token fetch, one re-auth on 401, 5xx queued).
  Manual: `run-velocity` and NuVotifier's test vote command.
- **Nexus_* (TypeScript)**: `npm test`; then link it into the caller (`npm pack` + install the
  tarball in the launcher) and run the caller's e2e. A library change is verified in its user.
- **Arffornia_Provisioning**: `make check`, `make indexes` and `git diff --stat` on `index.json`
  (only the expected entries change); for a mod change, the modpack script's `resolve` and
  `dupes` output.
- **infra (Kubernetes / Argo CD)**: `kustomize build --enable-helm <overlay> | kubeconform -strict`
  and `argocd app diff` (read-only). Never apply. Evidence: the rendered diff.
- **docs**: `make check` (Noodle lint + `mkdocs build --strict`), and the rendered page.
