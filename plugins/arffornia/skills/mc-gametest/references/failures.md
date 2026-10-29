# Reading GameTest failures

| Log line | Meaning | Next step |
|---|---|---|
| `All N required tests passed :)` + exit 0 | green | paste it in the PR |
| `N required tests failed:` then names | red | read the block above each name |
| `<test> failed! <message>` with `at x,y,z` | an assertion failed | the message has the actual value (write it so) |
| `Timed out` / `Didn't succeed or fail within N ticks` | the condition never became true | tick budget; does the BE tick (both blocks placed)? a future never completed? |
| `Exception` / stack trace in a test | usually a real bug | reproduce outside the test, fix in its own commit, keep the test |
| `Mod ftbteams requires ftblibrary` | missing `localRuntime` dependency | check `build.gradle` |
| `No test functions were given` / 0 tests | namespace or template prefix wrong | `enabledGameTestNamespaces`, `@PrefixGameTestTemplate(false)` |
| `Missing template arffornia:platform` | template path | `data/arffornia/structure/platform.nbt` |

Harmless noise (filtered by `run_gametests.sh`): recipes of absent optional mods failing to
parse, `api.minecraftservices.com` unreachable offline, `Couldn't load recipe`.

Flaky test? Run it 3 times. If it is order dependent, it shares state: use `nextId()` and a
fresh player per test, never a static mutable field.

Out of memory or a hung build: another Gradle build is running. One at a time, `-Xmx2g`,
`--no-daemon` (the script refuses to start a second one).
