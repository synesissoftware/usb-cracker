# usb-cracker - Changes <!-- omit in toc -->


## 0.0.16 - 16th September 2026

* PREFIX confirmation shows a live non-secret match indicator (matched length vs first entry, and diverge when the typed confirmation differs);
* default search UI is a Homebrew-style stderr progress meter (counts + current display suffix + **ETA** h/m/s remaining after the first completed attempt); full per-attempt suffix lines only with **--trace-suffixes**;
* **--min-suffix-len** (default 1) and **--mid-section-literal** (PREFIX + mid + suffix; mid included in logged/reported suffix form);
* contingent plain stdout report of the winning suffix on success (`usb-cracker: winning suffix="…"` on a TTY with green suffix text; bare suffix when stdout is piped);
* TTY PREFIX confirm overlays the first prompt line and clears it before search output;


## 0.0.15 - 16th September 2026

* classify Core Storage `Unable to register passphrase` as **:auth_failed** (continue) rather than a hard **:error**;


## 0.0.14 - 16th September 2026

* classify Core Storage `-69749` / `Unable to unlock the Core Storage volume` as **:auth_failed** (continue to next candidate) rather than a hard **:error**;


## 0.0.13 - 16th September 2026

* classify APFS `Could not find APFS Volume …` as **:wrong_target** so `engine: :auto` falls back to Core Storage (LV UUID unlock path);


## 0.0.12 - 16th September 2026

* stop-failure aborts (including **diskutil failed**) include attempt index, volume, engine, exit status, and PREFIX-masked passphrase (`********` + suffix); optional truncated `diskutil` stderr snippet on unlock errors;


## 0.0.11 - 16th September 2026

* **--key-name** is optional; require at least one of informed `--key-name` or bounded `--charset` + `--max-suffix-len`;
* warn and require confirmation when `--key-name` is longer than **6** characters (n! cost);
* always log each candidate **suffix** to stderr **before** unlock (informed and brute-force); `--trace-suffixes` still adds post-attempt status;
* stream unique key-name permutations (no full-array materialisation); Ctrl-C abort avoids Pantheios in the trap;


## 0.0.10 - 16th September 2026

* added **--trace-calls**: opt-in Pantheios **:info** function-entry tracing via **CallTrace** / **Diagnostics** (**ColouredConsoleLogService**);
* public API entry points log `enter <name> …` (non-secret detail only); off by default; no file sink;
* **--trace-suffixes** now logs the informed permutation list up front, each suffix **before** unlock (visible while `diskutil` blocks), and again with status after; each line is written to **$stderr** (and Pantheios); coloured console sink;
* unit tests for the flag and enter logging (**test/unit/tc_call_trace.rb**, **tc_cli.rb**);


## 0.0.9 - 15th September 2026

* added **lib/usb_cracker/search.rb**: candidate loop with **Unlock.attempt** per suffix; fail-closed result policy;
* success prints only the suffix on stdout (exit 0); exhaustion / busy / wrong-target / error / already-unlocked abort non-zero with non-secret messages;
* **--trace-suffixes** / **-T** opt-in **Pantheios** console tracing of attempted suffixes (never PREFIX); default off; no file logging;
* **exe/usb-cracker** wires parse → PREFIX → Search → suffix-only report;
* unit tests with injected unlock and log (**test/unit/tc_search.rb**);


## 0.0.8 - 15th September 2026

* added **lib/usb_cracker/diskutil.rb**: `diskutil` unlockVolume argv builder (APFS and Core Storage), **Open3** runner, and stdout/stderr classifier;
* added **lib/usb_cracker/unlock.rb**: **Unlock.attempt** assembles PREFIX+suffix in memory, pipes the passphrase via **-stdinpassphrase** (never argv), wipes the ephemeral buffer, and returns a typed **Result**;
* **engine: :auto** tries APFS first and falls back to Core Storage only when APFS is inapplicable (**:wrong_target**);
* unit tests for argv and classification (**test/unit/tc_diskutil.rb**); component tests with a mocked runner (**test/component/tc_unlock.rb**);


## 0.0.7 - 15th September 2026

* **Prefix.read!** usage failures (blank, mismatch, non-TTY) go through **Cli.abort** — single `usb-cracker:` stderr line, no Ruby backtrace; injectable **abort_exit: nil** for tests;


## 0.0.6 - 15th September 2026

* **Prefix.read!** prompts twice (`Prefix: ` / `Confirm prefix: `) and accepts only when both entries match; mismatch fails closed without echoing secrets;
* confirmation copy is wiped before the PREFIX buffer is returned; blank first entry still rejects without a second prompt;


## 0.0.5 - 15th September 2026

* added **lib/usb_cracker/secret_buffer.rb**: mutable PREFIX holder with best-effort **#wipe** / **#clear!**;
* added **lib/usb_cracker/prefix.rb**: one-shot hidden PREFIX prompt via **IO#getpass**; TTY-only (fail closed); injectable **getpass** for tests;
* blank PREFIX rejected with a non-secret message; **exe/usb-cracker** wipes PREFIX on the unlock-not-implemented abort path;
* unit tests for secret-buffer wipe and PREFIX read (**test/unit/tc_secret_buffer.rb**, **test/unit/tc_prefix.rb**);


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
