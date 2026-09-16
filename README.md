# usb-cracker <!-- omit in toc -->

macOS CLI for recovering forgotten suffixes on the operator's own encrypted USB volumes

![Language](https://img.shields.io/badge/Ruby-CC342D?style=flat&logo=ruby&logoColor=white)
![License](https://img.shields.io/badge/license-proprietary-lightgrey)
[![GitHub release](https://img.shields.io/github/v/release/synesissoftware/usb-cracker.svg)](https://github.com/synesissoftware/usb-cracker/releases/latest)
![Visibility](https://img.shields.io/badge/visibility-private-lightgrey)


## Table of Contents <!-- omit in toc -->

- [Introduction](#introduction)
- [Installation](#installation)
- [Usage](#usage)
- [Project Information](#project-information)
  - [Where to get help](#where-to-get-help)
  - [Contribution guidelines](#contribution-guidelines)
  - [Dependencies](#dependencies)
    - [Efferent (fan-out)](#efferent-fan-out)
      - [Runtime Dependencies (aka "Normal Dependencies")](#runtime-dependencies-aka-normal-dependencies)
      - [Development Dependencies](#development-dependencies)
    - [Afferent (fan-in)](#afferent-fan-in)
      - [Runtime dependents](#runtime-dependents)
      - [Development dependents](#development-dependents)
  - [Related projects](#related-projects)
  - [License](#license)


## Introduction

**usb-cracker** is a **private** Synesis Information Systems tool — a macOS
command-line program for recovering forgotten passphrase *suffixes* on the
operator's **own** software-encrypted USB volumes (APFS Encrypted and/or
older Core Storage / Journaled Encrypted).

It is **not** published to RubyGems.org, **not** a general USB cracker for
third-party devices, and it does not target hardware crypto sticks. Unlock
attempts are driven via macOS `diskutil` as a child process (no private
Apple frameworks).

This **0.0.9** release prompts twice for the long secret PREFIX (hidden
input, TTY only; both entries must match), enumerates suffix candidates,
and attempts unlock via macOS `diskutil`. On success it prints **only**
the matching suffix to stdout (exit 0). PREFIX is wiped on every exit
path. Opt-in `--trace-suffixes` logs each attempted suffix (never PREFIX)
to the console for smoke-testing.


## Installation

This gem is **not** distributed via RubyGems.org. From a source checkout:

```
bundle install
bundle exec rake test
./build_gem.sh
gem install --local usb_cracker-*.gem
```


## Usage

```
usb-cracker --help
usb-cracker --version
usb-cracker <volume> --key-name <name>
usb-cracker <volume> --charset <chars> --max-suffix-len <n>
usb-cracker <volume> --charset <chars> --min-suffix-len <n> --max-suffix-len <n>
usb-cracker <volume> --key-name <name> --charset <chars> --max-suffix-len <n>
usb-cracker <volume> --key-name <name> --mid-section-literal <text>
usb-cracker <volume> --key-name <name> --mid-section-literal=-x-
usb-cracker <volume> --key-name <name> --no-bruteforce
usb-cracker <volume> --key-name <name> --trace-suffixes
usb-cracker <volume> --key-name <name> --trace-calls
```

Required: **volume** (device id or UUID). Provide at least one search
strategy: optional `--key-name` / `-k` (informed permutations of a **short**
mnemonic) and/or bounded brute-force via **both** `--charset` / `-c` and
`--max-suffix-len` / `-x` (integer > 0). Optional `--min-suffix-len` / `-n`
defaults to **1** and requires the charset/max pair. Optional
`--mid-section-literal` is inserted between PREFIX and each candidate
suffix (and is included in logged/reported suffix form). When the literal
begins with `-`, use the equals form
(`--mid-section-literal=-x-`); a separate `-…` argv token is treated as
flags by the CLI parser. Supplying only one of charset/max is an error.
`--no-bruteforce` / `-B` disables brute-force even when both bounds are
present. When `--key-name` is longer than **6** characters the program
warns about n! cost and requires confirmation (`y` / `yes`).

After argv parse (and any key-name confirmation) the program prompts twice
for PREFIX on a TTY (no echo; confirm must match; not read from env, files,
or argv). The confirmation prompt overlays the first prompt line; on
success that line is cleared before search output begins. While typing the
confirmation, a non-secret indicator shows how much of the first entry
matches and whether the typed text has diverged.
Search order is unique permutations of `--key-name` (streamed), then —
when brute-force is enabled — all strings of length
`--min-suffix-len`..`--max-suffix-len` over `--charset` (charset order;
suffixes already produced as permutations are skipped). Unlock is macOS
**diskutil**-driven (APFS first, Core Storage when APFS does not apply;
passphrase on stdin, never argv).

By default a Homebrew-style progress meter is rewritten on stderr (TTY)
while candidates are tried (counts, the current display suffix, and an
**ETA** remaining estimate after the first completed attempt). With
`--trace-suffixes` / `--T` each candidate **suffix** is written to stderr as
`attempt N suffix=…` **before** unlock and again afterward with status.
Treat stderr scrollback as secret-bearing for suffixes. See
[SECURITY.md](./SECURITY.md).

On success, when stdout is a TTY the program prints
`usb-cracker: winning suffix="…"` on stdout (suffix text in green; quotes
plain). When stdout is piped, only the bare display suffix is written (for
scripting).

| Unlock result      | Action                                      |
| ------------------ | ------------------------------------------- |
| `:success`         | TTY: stdout winning report; pipe: bare suffix; exit 0 |
| `:auth_failed`     | try the next candidate                      |
| `:already_unlocked`| abort; volume already unlocked (no suffix)  |
| `:busy`            | abort immediately                           |
| `:wrong_target`    | abort immediately                           |
| `:error`           | abort immediately with attempt context      |
| (exhausted)        | abort; no matching suffix                   |

Stop-failure aborts (busy / wrong-target / error / already-unlocked)
include attempt index, volume, engine, exit status when known, and the
attempted passphrase with PREFIX replaced by `********` (suffix remains
visible). Treat that abort line as secret-bearing for the suffix.

`--trace-calls` is **off** by default. When enabled, each public
function-call entry is logged at Pantheios **:info** to the coloured
console sink (callable name plus non-secret context such as volume /
engine / status). PREFIX and suffixes are never included in call traces.


## Project Information


### Where to get help

Internal Synesis Information Systems channels / the private repository owner.
A public project page is intentionally not provided.


### Contribution guidelines

This is a private project. Contributions are at the discretion of the
repository owner. See [CONTRIBUTING.md](./CONTRIBUTING.md).


### Dependencies


#### Efferent (fan-out)

Libraries upon which **usb-cracker** depends:


##### Runtime Dependencies (aka "Normal Dependencies")

* [**clasp-ruby**](https://rubygems.org/gems/clasp-ruby);
* [**highline**](https://rubygems.org/gems/highline);
* [**libclimate-ruby**](https://rubygems.org/gems/libclimate-ruby);
* [**pantheios-ruby**](https://rubygems.org/gems/pantheios-ruby);
* [**recls-ruby**](https://rubygems.org/gems/recls-ruby);
* [**xqsr3**](https://rubygems.org/gems/xqsr3);


##### Development Dependencies

* [**rake**](https://rubygems.org/gems/rake);
* [**test-unit**](https://rubygems.org/gems/test-unit);


#### Afferent (fan-in)

Projects that depend on **usb-cracker**:


##### Runtime dependents

* \<none>;


##### Development dependents

* \<none>;


### Related projects

* \<none>;


### License

**usb-cracker** is proprietary Synesis Information Systems software. See [LICENSE](./LICENSE) for details.


<!-- ########################### end of file ########################### -->
