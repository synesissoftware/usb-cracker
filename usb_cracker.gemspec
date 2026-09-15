# ######################################################################## #
# File:     usb_cracker.gemspec
#
# Purpose:  Gemspec for usb-cracker (private Synesis project)
#
# Created:  9th September 2026
# Updated:  15th September 2026
#
# ######################################################################## #


$:.unshift File.join(File.dirname(__FILE__), 'lib')

require 'usb_cracker/version'


# Private project: not published to RubyGems.org. Homepage / source metadata
# are omitted until a private remote URL is configured.


Gem::Specification.new do |spec|

  spec.name         = 'usb_cracker'
  spec.summary      = 'macOS CLI for recovering forgotten suffixes on the operator\'s own encrypted USB volumes'
  spec.version      = UsbCracker::VERSION
  spec.description  = <<END_DESC
Private Synesis Information Systems macOS command-line tool for recovering
forgotten passphrase suffixes on the operator's own APFS Encrypted and/or
Core Storage encrypted USB volumes. Not intended for third-party devices.
Not published to RubyGems.org.
END_DESC

  spec.authors      = [
    'Matt Wilson',
  ]
  spec.email        = [
    'matthew@synesis.com.au',
  ]
  # Proprietary (see LICENSE). Not an SPDX open-source identifier; omitted
  # from RubyGems metadata because this gem is not published publicly.

  spec.required_ruby_version = [ '>= 2.0', '< 5' ]

  spec.bindir = 'exe'
  spec.executables = [
    'usb-cracker',
  ]

  spec.files = Dir[
    'Rakefile',
    '{bin,docs,examples,exe,lib,man,spec,test}/**/*',
    'AUTHORS*',
    'CHANGES*',
    'CONTRIBUTING*',
    'EXAMPLES*',
    'FAQ*',
    'INSTALL*',
    'LICENSE*',
    'NEWS*',
    'README*',
    'SECURITY*',
    'TODO*',
  ] & `git ls-files -z`.split("\0")
  spec.files -= [
    '.ruby-version',
    'Gemfile.lock',
  ]
end


# ############################## end of file ############################# #
