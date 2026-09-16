# frozen_string_literal: true
# ######################################################################## #
# File:     usb_cracker/cli.rb
#
# Purpose:  LibCLImate argv parse/validate for usb-cracker
#
# Created:  15th September 2026
# Updated:  16th September 2026
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

require 'usb_cracker/call_trace'
require 'usb_cracker/version'


module UsbCracker

  # Command-line parse/validate. Search, PREFIX prompt, and unlock are out
  # of scope for this module.
  module Cli

    # Abort/validation failure with a non-secret usage message.
    class UsageError < StandardError
    end

    # Warn and confirm when --key-name exceeds this many characters
    # (informed search cost is n!).
    KEY_NAME_WARN_LEN = 6

    # Parsed CLI options. Brute-force is enabled only when charset and
    # `--max-suffix-len` are supplied and `--no-bruteforce` is not set.
    # Optional `--min-suffix-len` defaults to 1 when omitted.
    # `--mid-section-literal` is inserted between PREFIX and each candidate
    # suffix. At least one of informed `--key-name` or bounded brute-force
    # must be present.
    Options = Struct.new(
      :charset,
      :key_name,
      :min_suffix_len,
      :max_suffix_len,
      :mid_section_literal,
      :no_bruteforce,
      :trace_calls,
      :trace_suffixes,
      :volume,
      keyword_init: true,
    ) do

      def bruteforce?

        !no_bruteforce && !charset.nil? && !max_suffix_len.nil?
      end

      def informed?

        !(key_name.nil? || key_name.empty?)
      end

      # Literal between PREFIX and the generated suffix; never nil.
      def mid

        mid_section_literal.nil? ? '' : mid_section_literal.to_s
      end

      # Effective brute-force minimum length (default 1).
      def min_suffix_len_or_default

        min_suffix_len.nil? ? 1 : min_suffix_len
      end

      # Display form of a candidate: mid-section + generated suffix.
      def display_suffix(suffix)

        "#{mid}#{suffix}"
      end

      alias_method :no_bruteforce?, :no_bruteforce
      alias_method :trace_calls?, :trace_calls
      alias_method :trace_suffixes?, :trace_suffixes
    end

    class << self

      # Parse and validate +argv+. On success returns {Options}. On failure
      # writes a usage line and, by default, exits (LibCLImate abort). Pass
      # +abort_exit: nil+ (and typically +exit_on_missing: false+) from unit
      # tests to receive {UsageError} instead of process exit.
      #
      # Recognised keys: +:abort_exit+, +:exit_on_missing+,
      # +:exit_on_unknown+, +:exit_on_usage+, +:program_name+, +:stderr+,
      # +:stdout+.
      def parse(argv = ARGV, **opts)

        collected = {
          charset: nil,
          charset_given: false,
          key_name: nil,
          key_name_given: false,
          max_suffix_len: nil,
          max_suffix_len_given: false,
          mid_section_literal: nil,
          mid_section_literal_given: false,
          min_suffix_len: nil,
          min_suffix_len_given: false,
          no_bruteforce: false,
          trace_calls: false,
          trace_suffixes: false,
        }

        abort_exit = opts.key?(:abort_exit) ? opts[:abort_exit] : 1

        climate = build_climate(collected, **opts)

        r = climate.run argv

        CallTrace.enable! if collected[:trace_calls]
        CallTrace.enter('UsbCracker::Cli.parse')

        assemble_options_(climate, r, collected, abort_exit)
      end

      # When +options.key_name+ is longer than {KEY_NAME_WARN_LEN}, warn
      # about n! cost and require an affirmative confirmation. Pass
      # +confirm:+ (callable returning a string) from tests.
      def confirm_key_name!(
        options,
        abort_exit: 1,
        confirm: nil,
        input: $stdin,
        stderr: $stderr
      )

        CallTrace.enter('UsbCracker::Cli.confirm_key_name!')

        key_name = options.key_name
        return options if key_name.nil? || key_name.empty?
        return options if key_name.length <= KEY_NAME_WARN_LEN

        n = key_name.length
        stderr.puts(
          "usb-cracker: warning: --key-name is #{n} characters " \
          "(informed search tries up to #{n}! unique permutations); " \
          'continue? [y/N]',
        )
        stderr.flush

        answer = if confirm

          confirm.call
        else

          input.gets
        end
        answer = answer.nil? ? '' : answer.to_s.strip

        unless answer.match?(/\Ay(es)?\z/i)

          abort(
            'cancelled: long --key-name not confirmed',
            exit: abort_exit,
            stderr: stderr,
          )
          raise UsageError, 'cancelled: long --key-name not confirmed'
        end

        options
      end

      # Write +message+ prefixed by the program name and exit.
      def abort(message, exit: 1, stderr: $stderr)

        CallTrace.enter('UsbCracker::Cli.abort')

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

          cl.add_option('--charset', alias: '-c', help: 'charset for bounded brute-force; must pair with --max-suffix-len (omit both to skip)') do |o, _a|

            collected[:charset_given] = true
            collected[:charset] = o.value
          end

          cl.add_option('--key-name', alias: '-k', help: 'optional short key-name whose permutations form informed suffixes (omit when using only --charset / --max-suffix-len)') do |o, _a|

            collected[:key_name_given] = true
            collected[:key_name] = o.value
          end

          cl.add_option('--min-suffix-len', alias: '-n', help: 'positive integer min suffix length for bounded brute-force (default 1); requires --charset and --max-suffix-len') do |o, _a|

            collected[:min_suffix_len_given] = true
            collected[:min_suffix_len] = o.value
          end

          cl.add_option('--max-suffix-len', alias: '-x', help: 'positive integer max suffix length for bounded brute-force; must pair with --charset') do |o, _a|

            collected[:max_suffix_len_given] = true
            collected[:max_suffix_len] = o.value
          end

          cl.add_option('--mid-section-literal', help: 'optional literal inserted between PREFIX and each candidate suffix (use --mid-section-literal=VALUE when VALUE begins with -); included in logged/reported suffix form') do |o, _a|

            collected[:mid_section_literal_given] = true
            collected[:mid_section_literal] = o.value
          end

          cl.add_flag('--no-bruteforce', alias: '-B', help: 'disable bounded brute-force (off unless both bounds are given)') do

            collected[:no_bruteforce] = true
          end

          cl.add_flag('--trace-calls', alias: '--C', help: 'log each public function-call entry at Pantheios :info to the console sink; default off; never logs PREFIX or suffixes') do

            collected[:trace_calls] = true
            CallTrace.enable!
          end

          cl.add_flag('--trace-suffixes', alias: '--T', help: 'log each candidate suffix before unlock and again with status after; default off (Homebrew-style progress meter instead); never logs PREFIX') do

            collected[:trace_suffixes] = true
          end
        end
      end

      def assemble_options_(climate, results, collected, abort_exit)

        volume = results.values[0]
        volume = volume.nil? ? '' : volume.strip

        if volume.empty?

          fail_usage_(climate, 'volume must be a non-empty value; use --help for usage', abort_exit)
        end

        key_name = nil
        if collected[:key_name_given]

          key_name = collected[:key_name]
          key_name = key_name.nil? ? '' : key_name.strip
          if key_name.empty?

            fail_usage_(climate, '--key-name must be a non-empty string when supplied; use --help for usage', abort_exit)
          end
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

          max_suffix_len = parse_positive_len_(
            climate,
            collected[:max_suffix_len],
            '--max-suffix-len',
            abort_exit,
          )
        end

        min_suffix_len = nil
        if collected[:min_suffix_len_given]

          min_suffix_len = parse_positive_len_(
            climate,
            collected[:min_suffix_len],
            '--min-suffix-len',
            abort_exit,
          )
        end

        mid_section_literal = nil
        if collected[:mid_section_literal_given]

          mid_section_literal = collected[:mid_section_literal]
          mid_section_literal = '' if mid_section_literal.nil?
        end

        charset_given = collected[:charset_given]
        max_len_given = collected[:max_suffix_len_given]
        min_len_given = collected[:min_suffix_len_given]

        if charset_given ^ max_len_given

          fail_usage_(climate, '--charset and --max-suffix-len must be supplied together (or omit both to skip brute-force); use --help for usage', abort_exit)
        end

        if min_len_given && !(charset_given && max_len_given)

          fail_usage_(climate, '--min-suffix-len requires --charset and --max-suffix-len; use --help for usage', abort_exit)
        end

        if !min_suffix_len.nil? && !max_suffix_len.nil? && min_suffix_len > max_suffix_len

          fail_usage_(climate, '--min-suffix-len must be less than or equal to --max-suffix-len; use --help for usage', abort_exit)
        end

        will_bruteforce = !collected[:no_bruteforce] && charset_given && max_len_given
        has_informed = !key_name.nil?

        unless has_informed || will_bruteforce

          fail_usage_(climate, 'provide --key-name and/or --charset with --max-suffix-len; use --help for usage', abort_exit)
        end

        Options.new(
          charset: charset,
          key_name: key_name,
          max_suffix_len: max_suffix_len,
          mid_section_literal: mid_section_literal,
          min_suffix_len: min_suffix_len,
          no_bruteforce: collected[:no_bruteforce],
          trace_calls: collected[:trace_calls],
          trace_suffixes: collected[:trace_suffixes],
          volume: volume,
        )
      end

      def parse_positive_len_(climate, raw, flag_name, abort_exit)

        n = Integer(raw, 10)
        if n <= 0

          fail_usage_(climate, "#{flag_name} must be an integer greater than 0; use --help for usage", abort_exit)
        end

        n
      rescue ArgumentError, TypeError

        fail_usage_(climate, "#{flag_name} must be an integer greater than 0; use --help for usage", abort_exit)
      end

      def fail_usage_(climate, message, abort_exit)

        climate.abort message, exit: abort_exit

        raise UsageError, message
      end
    end
  end # module Cli
end # module UsbCracker


# ############################## end of file ############################# #
