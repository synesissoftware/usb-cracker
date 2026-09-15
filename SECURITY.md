# usb-cracker - Security <!-- omit in toc -->


## Table of Contents <!-- omit in toc -->

- [Reporting a vulnerability](#reporting-a-vulnerability)
- [Secret handling](#secret-handling)
- [Passphrase transport](#passphrase-transport)
- [Supported versions](#supported-versions)


## Reporting a vulnerability

**usb-cracker** is a private Synesis Information Systems project. Report
security issues privately to the repository owner. Do not file public
advisories or attach exploit proofs of concept against third-party systems.


## Secret handling

**usb-cracker** is intended only for recovering forgotten suffixes on the
operator's own encrypted volumes.

The long passphrase PREFIX is prompted **twice** via hidden TTY input
(**IO#getpass**; `Prefix: ` then `Confirm prefix: `) and accepted only when
both entries match, so a mistype cannot drive a long unlock search. It is
held only in a mutable in-memory buffer (**SecretBuffer**); the confirmation
copy is wiped immediately, and the buffer is best-effort wiped on exit paths
(including the current search-not-implemented abort). PREFIX is never read
from the environment, files, or CLI flags, and must never be written to
disk, logs, history files, crash artefacts, or configuration. Usage errors
and **inspect** omit the secret.

Later releases will print only a successful suffix on success.


## Passphrase transport

Unlock attempts invoke Apple **diskutil** as a child process (`diskutil apfs
unlockVolume`, then `diskutil coreStorage unlockVolume` when APFS does not
apply). The assembled passphrase (PREFIX + suffix) is written to the child's
**stdin** with `-stdinpassphrase`. The `-passphrase` flag is never used: it
would place the secret on process argv (visible via `ps`). No temporary
file is used (that would write the secret to disk).

The ephemeral full-passphrase buffer is best-effort wiped after the child
returns. **Unlock::Result** carries only a status symbol and a canned,
non-secret detail — never PREFIX, suffix, or the concatenation.


## Supported versions

| Version | Supported |
| ------- | --------- |
| 0.0.x   | ✅        |


<!-- ########################### end of file ########################### -->
