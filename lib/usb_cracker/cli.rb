# frozen_string_literal: true
# ######################################################################## #
# File:     usb_cracker/cli.rb
#
# Purpose:  LibCLImate argv parse/validate for usb-cracker
#
# Created:  15th September 2026
# Updated:  15th September 2026
#
# Home:     private Synesis Information Systems project
#
# Author:   Matthew Wilson
#
# Copyright (c) 2026, Matthew Wilson and Synesis Information Systems
# All rights reserved.
#
# Proprietary software. See the LICENSE file in the project root.
#
# ######################################################################## #


=begin
=end

require 'libclimate'

require 'usb_cracker/version'


module UsbCracker

  # Command-line parse/validate. Search, PREFIX prompt, and unlock are
  # out of scope for this module.
  module Cli

    # Abort/validation failure with a non-secret usage message.
    class UsageError < StandardError
    end

    # Parsed CLI options. Brute-force is enabled only when both bounds
    # are supplied and `--no-bruteforce` is not set.
    Options = Struct.new(
      :charset,
      :key_name,
      :max_suffix_len,
      :no_bruteforce,
      :volume,
      keyword_init: true,
    ) do

      def bruteforce?

        !no_bruteforce && !charset.nil? && !max_suffix_len.nil?
      end

      alias_method :no_bruteforce?, :no_bruteforce
    end

    class << self

      # Parse and validate +argv+. On success returns {Options}. On
      # failure writes a usage line and, by default, exits (LibCLImate
      # abort). Pass +abort_exit: nil+ (and typically
      # +exit_on_missing: false+) from unit tests to receive
      # {UsageError} instead of process exit.
      #
      # Recognised keys: +:abort_exit+, +:exit_on_missing+,
      # +:exit_on_unknown+, +:exit_on_usage+, +:program_name+,
      # +:stderr+, +:stdout+.
      def parse(argv = ARGV, **opts)

        collected = {
          charset: nil,
          charset_given: false,
          key_name: nil,
          max_suffix_len: nil,
          max_suffix_len_given: false,
          no_bruteforce: false,
        }

        abort_exit = opts.key?(:abort_exit) ? opts[:abort_exit] : 1

        climate = build_climate(collected, **opts)

        r = climate.run argv

        assemble_options_(climate, r, collected, abort_exit)
      end

      # Write +message+ prefixed by the program name and exit.
      def abort(message, exit: 1, stderr: $stderr)

        stderr.puts "usb-cracker: #{message}"

        Kernel.exit(exit) unless exit.nil?

        message
      end

      private
      def build_climate(collected, **opts)

        LibCLImate::Climate.new(value_attributes: true) do |cl|

          cl.program_name = opts.fetch(:program_name, 'usb-cracker')
          cl.stdout = opts[:stdout] if opts.key?(:stdout)
          cl.stderr = opts[:stderr] if opts.key?(:stderr)

          unless opts[:exit_on_missing].nil?

            cl.exit_on_missing = opts[:exit_on_missing]
          end
          unless opts[:exit_on_unknown].nil?

            cl.exit_on_unknown = opts[:exit_on_unknown]
          end
          unless opts[:exit_on_usage].nil?

            cl.exit_on_usage = opts[:exit_on_usage]
          end

          cl.info_lines = [

            'usb-cracker',
            'Copyright (c) 2026, Matthew Wilson and Synesis Information Systems',
            :version,
            "Recover forgotten suffixes on the operator's own encrypted USB volumes",
            '',
          ]

          cl.usage_values     = '<volume>'
          cl.constrain_values = 1..1
          cl.value_names      = [
            'volume',
          ]

          cl.version = [
            UsbCracker::VERSION_MAJOR,
            UsbCracker::VERSION_MINOR,
            UsbCracker::VERSION_REVISION,
          ]

          cl.add_option('--key-name', alias: '-k', required: true, help: 'key-name whose permutations form informed suffixes (required)') do |o, _a|

            collected[:key_name] = o.value
          end

          cl.add_option('--charset', alias: '-c', help: 'charset for bounded brute-force; must pair with --max-suffix-len (omit both to skip)') do |o, _a|

            collected[:charset_given] = true
            collected[:charset] = o.value
          end

          cl.add_option('--max-suffix-len', alias: '-m', help: 'positive integer max suffix length for bounded brute-force; must pair with --charset') do |o, _a|

            collected[:max_suffix_len_given] = true
            collected[:max_suffix_len] = o.value
          end

          cl.add_flag('--no-bruteforce', alias: '-n', help: 'disable bounded brute-force (off unless both bounds are given)') do

            collected[:no_bruteforce] = true
          end
        end
      end

      def assemble_options_(climate, results, collected, abort_exit)

        volume = results.values[0]
        volume = volume.nil? ? '' : volume.strip

        if volume.empty?

          fail_usage_(climate, 'volume must be a non-empty value; use --help for usage', abort_exit)
        end

        key_name = collected[:key_name]
        key_name = key_name.nil? ? '' : key_name.strip

        if key_name.empty?

          fail_usage_(climate, '--key-name is required; use --help for usage', abort_exit)
        end

        charset = nil
        if collected[:charset_given]

          charset = collected[:charset]
          if charset.nil? || charset.empty?

            fail_usage_(climate, '--charset must be a non-empty string; use --help for usage', abort_exit)
          end
        end

        max_suffix_len = nil
        if collected[:max_suffix_len_given]

          max_suffix_len = parse_max_suffix_len_(climate, collected[:max_suffix_len], abort_exit)
        end

        charset_given = collected[:charset_given]
        max_len_given = collected[:max_suffix_len_given]

        if charset_given ^ max_len_given

          fail_usage_(climate, '--charset and --max-suffix-len must be supplied together (or omit both to skip brute-force); use --help for usage', abort_exit)
        end

        Options.new(
          charset: charset,
          key_name: key_name,
          max_suffix_len: max_suffix_len,
          no_bruteforce: collected[:no_bruteforce],
          volume: volume,
        )
      end

      def parse_max_suffix_len_(climate, raw, abort_exit)

        n = Integer(raw, 10)
        if n <= 0

          fail_usage_(climate, '--max-suffix-len must be an integer greater than 0; use --help for usage', abort_exit)
        end

        n
      rescue ArgumentError, TypeError

        fail_usage_(climate, '--max-suffix-len must be an integer greater than 0; use --help for usage', abort_exit)
      end

      def fail_usage_(climate, message, abort_exit)

        climate.abort message, exit: abort_exit

        raise UsageError, message
      end
    end
  end # module Cli
end # module UsbCracker


# ############################## end of file ############################# #
