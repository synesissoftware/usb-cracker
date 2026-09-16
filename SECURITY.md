# usb-cracker - Security <!-- omit in toc -->


## Table of Contents <!-- omit in toc -->

- [Reporting a vulnerability](#reporting-a-vulnerability)
- [Secret handling](#secret-handling)
- [Passphrase transport](#passphrase-transport)
- [Candidate logging](#candidate-logging)
- [Call tracing](#call-tracing)
- [Supported versions](#supported-versions)


## Reporting a vulnerability

**usb-cracker** is a private Synesis Information Systems project. Report
security issues privately to the repository owner. Do not file public
advisories or attach exploit proofs of concept against third-party systems.


## Secret handling

**usb-cracker** is intended only for recovering forgotten suffixes on the
operator's own encrypted volumes.

The long passphrase PREFIX is prompted **twice** via hidden TTY input
(`Prefix: ` then `Confirm prefix: `) and accepted only when both entries
match, so a mistype cannot drive a long unlock search. The confirmation
prompt redraws a **non-secret** match indicator (matched length and
diverge flag) — never the PREFIX characters themselves. PREFIX is held
only in a mutable in-memory buffer (**SecretBuffer**); the confirmation
copy is wiped immediately, and the buffer is best-effort wiped on exit
paths (including the search-loop abort paths). PREFIX is never read from
the environment, files, or CLI flags, and must never be written to disk,
logs, history files, crash artefacts, or configuration. Usage errors and
**inspect** omit the secret.

On success the program prints `usb-cracker: winning suffix="…"` on stdout
when stdout is a TTY (suffix text green; quotes plain). When stdout is
piped, only the matching display suffix is written (plus a newline) for
scripting. Stop-failure paths emit a stderr line that may include attempt
context and a PREFIX-masked passphrase (`********` + mid + suffix) —
never the live PREFIX. Exhaustion and usage failures remain canned
non-secret messages.


## Passphrase transport

Unlock attempts invoke Apple **diskutil** as a child process (`diskutil apfs
unlockVolume`, then `diskutil coreStorage unlockVolume` when APFS does not
apply). The assembled passphrase (PREFIX + optional mid-section + suffix)
is written to the child's **stdin** with `-stdinpassphrase`. The
`-passphrase` flag is never used: it would place the secret on process
argv (visible via `ps`). No temporary file is used (that would write the
secret to disk).

The ephemeral full-passphrase buffer is best-effort wiped after the child
returns. **Unlock::Result** carries only a status symbol and a canned,
non-secret detail — never PREFIX, suffix, or the concatenation.


## Candidate logging

By default a Homebrew-style **progress meter** is rewritten on stderr
(TTY only) while candidates are tried. The line includes attempt counts,
the current **display suffix** (mid-section + generated suffix when
configured), and an **ETA** remaining estimate (after the first completed
attempt). Treat terminal scrollback as secret-bearing for those suffixes.

`--trace-suffixes` / `--T` is **opt-in** and **off** by default. When
enabled, each candidate **suffix** (from informed `--key-name`
permutations or bounded `--charset` brute-force, including any
`--mid-section-literal`) is written to **stderr** as
`attempt N suffix=…` **before** the unlock attempt and again afterward
with unlock status. Do not redirect this output to a file. PREFIX,
PREFIX+suffix, and **SecretBuffer** contents are never logged.

Success stdout is either the labeled winning report (TTY) or the bare
matching display suffix (piped). That path is not Pantheios / diagnostic
logging.


## Call tracing

`--trace-calls` is **opt-in** and **off** by default. When enabled, public
API entry points log at Pantheios **:info** to the same coloured console
sink (`enter <name> …`). Detail strings may include volume, engine, or
status symbols — never PREFIX, suffix, or the assembled passphrase.


## Supported versions

| Version | Supported |
| ------- | --------- |
| 0.1.x   | ✅        |
| 0.0.x   | ❌        |


<!-- ########################### end of file ########################### -->
