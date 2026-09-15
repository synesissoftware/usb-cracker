# usb-cracker - TODO <!-- omit in toc -->


## Functional improvements

* [ ] Prompt once for the long secret PREFIX (hidden input); never persist it;
* [x] ~~~CLI argv: required **volume** value; **--key-name**; fail-closed brute-force bounds~~~ - ✅;
* [ ] Informed search: unique permutations of the key-name suffix;
* [ ] Optional bounded brute-force fallback (charset + max length; fail closed);
* [ ] Unlock via macOS `diskutil` child process (APFS, then Core Storage);
* [ ] Avoid exposing the passphrase on process argv;
* [ ] On success print only the successful SUFFIX; exit codes correct;
* [x] ~~~Unit tests for CLI parsing~~~ - ✅;
* [ ] Unit tests for candidate generation;
* [ ] Component tests with mocked `diskutil` / Open3;


## Performance improvements

* \<none>


## Packaging improvements

* [x] ~~~Ruby gem boilerplate (gemspec, **Gemfile** `lockfile false`, **ruby.yml**, docs set)~~~ - ✅;
* [x] ~~~document as **private** (no RubyGems.org / public homepage metadata)~~~ - ✅;
* [x] ~~~integrate **misc-dev-scripts** Ruby exemplars; **LibCLImate** CLI; runtime deps~~~ - ✅;
* [ ] When a private remote exists: restore gemspec homepage/metadata URIs and optional CI badge;


<!-- ########################### end of file ########################### -->
