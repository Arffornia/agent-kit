# Threat model output

```
Threat model: <surface> · <repo> · <date>
Entry point: <blob URL with full SHA #L..> - <handler>
Caller / trust: <who, identity>
Assets: <list>

Flow
1. client sends set_machine_mode(pos, mode)   (hypothetical example)
2. server: enqueueWork → handler
3. ...

Threats (kept)
| # | STRIDE | Step | Threat | L | I | Mitigation | Proof (test) | Status |
|---|---|---|---|---|---|---|---|---|
| T1 | T,E | 2 | a client changes the mode of a machine it is not using | M | M | menu open + distance + owner check | GameTest setModeRejectedFromFarAway | mitigated |

Rejected (does not apply, one line why): ...
Trifecta (agents only): private data <y/n> · untrusted input <y/n> · external output <y/n> → <verdict>
Open: <threats without mitigation, each with an issue URL (neutral title)>
```
