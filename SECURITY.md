# usb-cracker - Security <!-- omit in toc -->


## Table of Contents <!-- omit in toc -->

- [Reporting a vulnerability](#reporting-a-vulnerability)
- [Secret handling](#secret-handling)
- [Supported versions](#supported-versions)


## Reporting a vulnerability

**usb-cracker** is a private Synesis Information Systems project. Report
security issues privately to the repository owner. Do not file public
advisories or attach exploit proofs of concept against third-party systems.


## Secret handling

**usb-cracker** is intended only for recovering forgotten suffixes on the
operator's own encrypted volumes. The long passphrase PREFIX must never be
written to disk, logs, history files, crash artefacts, or configuration.
Future releases will prompt for PREFIX once in-process and print only a
successful suffix on success.


## Supported versions

| Version | Supported |
| ------- | --------- |
| 0.0.x   | ✅        |


<!-- ########################### end of file ########################### -->
