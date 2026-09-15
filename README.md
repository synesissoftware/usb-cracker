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
attempts will be driven via macOS `diskutil` as a child process (no private
Apple frameworks).

This **0.0.6** release prompts twice for the long secret PREFIX (hidden
input, TTY only; both entries must match) and holds it in a wipeable
in-memory buffer. Argv parse and suffix-candidate enumeration live in
**lib/**. Unlock behaviour is not implemented yet.


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
usb-cracker <volume> --key-name <name> --charset <chars> --max-suffix-len <n>
usb-cracker <volume> --key-name <name> --no-bruteforce
```

Required: **volume** (device id or UUID) and `--key-name` / `-k` (informed
search). After argv parse the program prompts twice for PREFIX on a TTY
(no echo; confirm must match; not read from env, files, or argv). Search
order is unique
permutations of `--key-name`, then — when brute-force is enabled — all
non-empty strings of length 1..`--max-suffix-len` over `--charset` (charset
order; suffixes already produced as permutations are skipped). Bounded
brute-force is off unless **both** `--charset` / `-c` and
`--max-suffix-len` / `-m` (integer > 0) are supplied; supplying only one
is an error. `--no-bruteforce` / `-n` disables brute-force even when both
bounds are present. Unlock behaviour lands in a later release.


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
