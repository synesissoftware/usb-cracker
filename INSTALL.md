# usb-cracker - Installation and Use <!-- omit in toc -->


## Table of Contents <!-- omit in toc -->

- [From a source checkout](#from-a-source-checkout)
- [Install a local gem](#install-a-local-gem)
- [Using the CLI](#using-the-cli)


## From a source checkout

**usb-cracker** is a private project and is **not** published to
RubyGems.org. Requires **Ruby** >= 3.0.

```
bundle install
bundle exec rake test
```


## Install a local gem

```
./build_gem.sh
gem install --local usb_cracker-*.gem
```


## Using the CLI

Required: **volume** and `--key-name`. After argv parse the program
prompts twice for PREFIX on a TTY (hidden input; confirm must match; never
from env, files, or argv). Bounded brute-force is off unless both
`--charset` and `--max-suffix-len` are supplied. Unlock is macOS
**diskutil**-driven; the candidate search loop is not in this release.

```
usb-cracker --help
usb-cracker --version
usb-cracker <volume> --key-name <name>
usb-cracker <volume> --key-name <name> --charset <chars> --max-suffix-len <n>
```


<!-- ########################### end of file ########################### -->
