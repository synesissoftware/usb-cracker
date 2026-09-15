# usb-cracker - Changes <!-- omit in toc -->


## 0.0.4 - 15th September 2026

* added **lib/usb_cracker/candidates.rb**: unique **key_name** permutations (lexicographic), then optional bounded brute-force suffixes;
* brute-force is generated only when **Options#bruteforce?**; lengths 1..**max_suffix_len** over **charset** order; duplicates across phases skipped; empty suffix is not tried;
* unit tests for candidate generation (**test/unit/tc_candidates.rb**);


## 0.0.3 - 15th September 2026

* extracted **LibCLImate** argv parse/validate into **lib/usb_cracker/cli.rb**; **exe/usb-cracker** stays orchestration-only;
* **--key-name** / **-k** is required; blank **volume** and blank **--key-name** abort;
* bounded brute-force is fail-closed: enabled only when both **--charset** and **--max-suffix-len** (integer > 0) are supplied; **--no-bruteforce** disables it;
* unit tests for CLI parse success and validation failures (**test/unit/tc_cli.rb**);


## 0.0.2 - 15th September 2026

* refreshed Ruby exemplars from **misc-dev-scripts** (**.editorconfig**, **.gitattributes**, **.gitignore**, **.vimrc**, **.vscode/settings.json**, **run_all_unit_tests.sh**); added **test/unit/ts_all.rb**;
* runtime dependencies: **clasp-ruby**, **highline**, **libclimate-ruby**, **pantheios-ruby**, **recls-ruby**, **xqsr3**;
* **exe/usb-cracker** converted to **LibCLImate** (required **volume** value; reserved search options; unlock still unimplemented);
* `required_ruby_version` raised to `[ '>= 3.0', '< 5' ]` for **highline** 3.x; CI matrix dropped Ruby 2.x cells;


## 0.0.1 - 9th September 2026

* initial scaffold: gem packaging (**usb_cracker**), stub **exe/usb-cracker**, CI (**ruby.yml**), Synesis Ruby docs set, and version unit test;
* documented as a **private** Synesis Information Systems project (local gem install only; no public homepage / RubyGems metadata);
* **LICENSE** is proprietary; README / CONTRIBUTING / gemspec aligned (no BSD-3-Clause claim);


<!-- ########################### end of file ########################### -->
