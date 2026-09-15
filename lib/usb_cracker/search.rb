# frozen_string_literal: true
# ######################################################################## #
# File:     usb_cracker/search.rb
#
# Purpose:  Suffix search loop: candidates → Unlock.attempt → outcome
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

require 'usb_cracker/candidates'
require 'usb_cracker/cli'
require 'usb_cracker/unlock'


module UsbCracker

  # End-to-end recovery loop. Enumerates suffixes via {Candidates.each}
  # and calls {Unlock.attempt} per candidate. Never concatenates PREFIX
  # and suffix itself (Unlock does that) and never logs PREFIX, the
  # concatenation, or {SecretBuffer} contents.
  #
  # Result policy:
  # * +:success+ — stop; report the successful suffix (exit 0);
  # * +:already_unlocked+ — stop; non-zero; "volume already unlocked";
  #   do not invent a suffix;
  # * +:auth_failed+ — continue to the next candidate;
  # * +:busy+ — fail closed immediately (volume busy);
  # * +:wrong_target+ — fail closed immediately (volume / engine);
  # * +:error+ — fail closed immediately (diskutil / macOS);
  # * exhaustion — non-zero; "no matching suffix".
  #
  # Opt-in suffix tracing (`options.trace_suffixes?`): each attempt may
  # log **suffix**, 1-based index, and {Unlock::Result#status} to a
  # console sink. Tracing is off by default and does not call Pantheios
  # at all when off. Inject +log:+ in tests. Never enable a file sink
  # from this module (file sinks would persist partial secrets).
  module Search

    # Structured loop outcome for {#report} / the executable.
    Outcome = Struct.new(
      :exit_status,
      :kind,
      :message,
      :suffix,
      keyword_init: true,
    ) do

      def success?

        kind == :success
      end
    end

    KINDS = [
      :already_unlocked,
      :busy,
      :error,
      :exhausted,
      :success,
      :wrong_target,
    ].freeze

    MESSAGE = {
      already_unlocked: 'volume already unlocked',
      busy: 'volume busy',
      error: 'diskutil failed',
      exhausted: 'no matching suffix',
      wrong_target: 'not an applicable volume',
    }.freeze

    CONTINUE_STATUSES = [
      :auth_failed,
    ].freeze

    STOP_FAILURE_STATUSES = [
      :already_unlocked,
      :busy,
      :error,
      :wrong_target,
    ].freeze

    class << self

      # Run the candidate loop.
      #
      # @param options [Cli::Options] parsed CLI options
      # @param prefix [SecretBuffer, String] live PREFIX; not wiped here
      # @param engine [Symbol] passed through to {Unlock.attempt}
      # @param log [#call, nil] injectable tracer
      #   `log.call(index, suffix, result)`; used only when tracing is on
      # @param runner [#call, nil] passed through to {Unlock.attempt}
      # @param unlock [#call, nil] injectable attempt callable with the
      #   same keyword arguments as {Unlock.attempt}; tests supply this
      #   so CI never spawns `diskutil`
      # @return [Outcome]
      def run(
        options,
        prefix,
        engine: :auto,
        log: nil,
        runner: nil,
        unlock: nil
      )

        attempt = unlock || method(:default_attempt_)
        tracer = resolve_tracer_(options, log)
        index = 0

        Candidates.each(options) do |suffix|

          index += 1
          result = attempt.call(
            engine: engine,
            prefix: prefix,
            runner: runner,
            suffix: suffix,
            volume: options.volume,
          )

          tracer.call(index, suffix, result) if tracer

          case result.status
          when :success

            return success_outcome_(suffix)
          when *CONTINUE_STATUSES

            next
          when *STOP_FAILURE_STATUSES

            return failure_outcome_(result)
          else

            return failure_outcome_for_kind_(:error)
          end
        end

        failure_outcome_for_kind_(:exhausted)
      end

      # Emit the success suffix on stdout, or abort with a non-secret
      # message. Stdout on success is exactly the suffix plus a newline
      # (no PREFIX, no labels). Pass +abort_exit: nil+ from tests.
      def report(
        outcome,
        abort_exit: :from_outcome,
        stderr: $stderr,
        stdout: $stdout
      )

        unless outcome.is_a?(Outcome)

          raise ArgumentError, 'outcome must be a UsbCracker::Search::Outcome'
        end

        if outcome.success?

          stdout.puts outcome.suffix

          return outcome
        end

        exit_code = abort_exit == :from_outcome ? outcome.exit_status : abort_exit

        Cli.abort outcome.message, exit: exit_code, stderr: stderr
      end

      private
      def default_attempt_(**kwargs)

        Unlock.attempt(**kwargs)
      end

      def resolve_tracer_(options, log)

        return nil unless options.trace_suffixes?

        return log unless log.nil?

        method(:pantheios_suffix_trace_)
      end

      def success_outcome_(suffix)

        Outcome.new(
          exit_status: 0,
          kind: :success,
          message: nil,
          suffix: suffix,
        )
      end

      def failure_outcome_(result)

        kind = result.status
        message = if kind == :error && result.detail.is_a?(String) && !result.detail.empty?

          result.detail
        else

          MESSAGE.fetch(kind, MESSAGE[:error])
        end

        Outcome.new(
          exit_status: 1,
          kind: kind,
          message: message,
          suffix: nil,
        )
      end

      def failure_outcome_for_kind_(kind)

        Outcome.new(
          exit_status: 1,
          kind: kind,
          message: MESSAGE.fetch(kind),
          suffix: nil,
        )
      end

      def pantheios_suffix_trace_(index, suffix, result)

        SuffixTrace.emit(index, suffix, result)
      end
    end

    # Console-only Pantheios wiring for `--trace-suffixes`. Loaded lazily
    # the first time tracing runs without an injected +log+ callable.
    # Logs suffix, attempt index, and status — never PREFIX.
    module SuffixTrace

      class << self

        def emit(index, suffix, result)

          logger.log(:informational, "attempt #{index} suffix=#{suffix} status=#{result.status}")
        end

        private
        def logger

          return @logger if @logger

          require 'pantheios'
          require 'pantheios/services/simple_console_log_service'

          Pantheios::Core.set_service(
            Pantheios::Services::SimpleConsoleLogService.new,
          )
          Pantheios::Core.process_name = 'usb-cracker'

          @logger = Object.new
          @logger.extend ::Pantheios::API
          @logger
        end
      end
    end
  end # module Search
end # module UsbCracker


# ############################## end of file ############################# #
