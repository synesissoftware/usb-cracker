# usb-cracker - TODO <!-- omit in toc -->


## Functional improvements

* [x] ~~~Prompt twice for the long secret PREFIX (hidden input; confirm match); never persist it~~~ - ✅;
* [x] ~~~CLI argv: required **volume**; optional **--key-name**; fail-closed brute-force bounds~~~ - ✅;
* [x] ~~~Informed search: unique permutations of the key-name suffix (streamed)~~~ - ✅;
* [x] ~~~Optional bounded brute-force fallback (charset + max length; fail closed)~~~ - ✅;
* [x] ~~~Warn + confirm when **--key-name** is longer than 6 characters~~~ - ✅;
* [x] ~~~Always log each candidate suffix before unlock~~~ - ✅ (superseded: default is progress meter; suffixes via **--trace-suffixes**);
* [x] ~~~Unlock via macOS `diskutil` child process (APFS, then Core Storage)~~~ - ✅;
* [x] ~~~Avoid exposing the passphrase on process argv~~~ - ✅;
* [x] ~~~On success print only the successful SUFFIX; exit codes correct~~~ - ✅;
* [x] ~~~Opt-in **--trace-suffixes** (post-attempt status; never PREFIX)~~~ - ✅;
* [x] ~~~Opt-in **--trace-calls** (Pantheios coloured console; :info enter logs)~~~ - ✅;
* [x] ~~~PREFIX confirm live match indicator (matched length / diverge)~~~ - ✅;
* [x] ~~~Homebrew-style progress meter when not tracing suffixes~~~ - ✅;
* [x] ~~~**--min-suffix-len** and **--mid-section-literal**~~~ - ✅;
* [x] ~~~Contingent winning-suffix stdout report (non-diagnostic)~~~ - ✅;
* [x] ~~~Unit tests for CLI parsing~~~ - ✅;
* [x] ~~~Unit tests for candidate generation~~~ - ✅;
* [x] ~~~Unit tests for the search loop (injected unlock / log)~~~ - ✅;
* [x] ~~~Component tests with mocked `diskutil` / Open3~~~ - ✅;
* [ ] Apply as much as is useful of **xqsr3** `ParameterChecking` module constructs at public entry points;
* [ ] Use **woad.Ruby** for coloured TTY output (progress meter, PREFIX confirm indicator, and related stderr chrome);
* [ ] Prompt to elevate / re-exec as super-user when unlock requires it (e.g. Core Storage on newer macOS);


## Performance improvements

* \<none>


## Packaging improvements

* [x] ~~~Ruby gem boilerplate (gemspec, **Gemfile** `lockfile false`, **ruby.yml**, docs set)~~~ - ✅;
* [x] ~~~document as **private** (no RubyGems.org / public homepage metadata)~~~ - ✅;
* [x] ~~~integrate **misc-dev-scripts** Ruby exemplars; **LibCLImate** CLI; runtime deps~~~ - ✅;
* [ ] When a private remote exists: restore gemspec homepage/metadata URIs and optional CI badge;


<!-- ########################### end of file ########################### -->
