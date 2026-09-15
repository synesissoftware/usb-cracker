# usb-cracker - Changes <!-- omit in toc -->


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
