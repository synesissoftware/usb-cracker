# frozen_string_literal: true
# ######################################################################## #
# File:     usb_cracker/search.rb
#
# Purpose:  Suffix search loop: candidates → Unlock.attempt → outcome
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

require 'usb_cracker/call_trace'
require 'usb_cracker/candidates'
require 'usb_cracker/cli'
require 'usb_cracker/diagnostics'
require 'usb_cracker/progress'
require 'usb_cracker/unlock'


module UsbCracker

  # End-to-end recovery loop. Enumerates suffixes via {Candidates.each} and
  # calls {Unlock.attempt} per candidate. Unlock assembles PREFIX + optional
  # mid-section + suffix. Stop-failure abort messages include a
  # PREFIX-masked passphrase ( `********` + mid + suffix) and never the live
  # PREFIX or {SecretBuffer} contents. Logged and reported "suffix" forms
  # include the mid-section when one was configured.
  #
  # Result policy:
  # * +:success+ — stop; report the winning display suffix (exit 0);
  # * +:already_unlocked+ — stop; non-zero; "volume already unlocked"; do
  #   not invent a suffix;
  # * +:auth_failed+ — continue to the next candidate;
  # * +:busy+ — fail closed immediately (volume busy);
  # * +:wrong_target+ — fail closed immediately (volume / engine);
  # * +:error+ — fail closed immediately (diskutil / macOS); abort message
  #   includes attempt context and PREFIX-masked passphrase;
  # * exhaustion — non-zero; "no matching suffix".
  #
  # When `options.trace_suffixes?` is set, each display suffix is logged to
  # stderr **before** {Unlock.attempt} and again afterward with unlock
  # status. Otherwise a Homebrew-style {Progress::Meter} is rewritten on
  # stderr (TTY only) with counts, the current display suffix, and an ETA
  # remaining estimate. Inject
  # +log:+ in tests. Never enable a file sink from this module (file sinks
  # would persist partial secrets).
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

    # Mask substituted for the live PREFIX in abort diagnostics.
    PREFIX_MASK = '********'

    class << self

      # Run the candidate loop.
      #
      # @param options [Cli::Options] parsed CLI options
      # @param prefix [SecretBuffer, String] live PREFIX; not wiped here
      # @param engine [Symbol] passed through to {Unlock.attempt}
      # @param log [#call, nil] injectable tracer
      #   `log.call(index, suffix, result)` ; +result+ is +nil+ before
      #   unlock and a {Unlock::Result} after when status tracing is on;
      #   +suffix+ is the display form (mid + generated suffix)
      # @param progress [Progress::Meter, nil] injectable meter; when
      #   omitted and suffixes are not traced, a TTY meter is created
      # @param runner [#call, nil] passed through to {Unlock.attempt}
      # @param unlock [#call, nil] injectable attempt callable with the same
      #   keyword arguments as {Unlock.attempt}; tests supply this so CI
      #   never spawns `diskutil`
      # @return [Outcome]
      def run(
        options,
        prefix,
        engine: :auto,
        log: nil,
        progress: :auto,
        runner: nil,
        unlock: nil
      )

        CallTrace.enable! if options.respond_to?(:trace_calls?) && options.trace_calls?
        CallTrace.enter(
          'UsbCracker::Search.run',
          "engine=#{engine} volume=#{options.volume}",
        )

        attempt = unlock || method(:default_attempt_)
        mid = mid_from_(options)
        meter = resolve_progress_(options, progress, log)
        index = 0
        outcome = nil

        begin

          Candidates.each(options) do |suffix|

            index += 1
            display = display_suffix_(options, suffix)
            emit_before_(index, display, log, meter, options)

            result = attempt.call(
              engine: engine,
              mid: mid,
              prefix: prefix,
              runner: runner,
              suffix: suffix,
              volume: options.volume,
            )

            emit_after_(index, display, result, options, log)

            case result.status
            when :success

              outcome = success_outcome_(display)
              break
            when *CONTINUE_STATUSES

              next
            when *STOP_FAILURE_STATUSES

              outcome = failure_outcome_(
                result,
                index: index,
                suffix: display,
                volume: options.volume,
              )
              break
            else

              outcome = failure_outcome_for_kind_(:error)
              break
            end
          end

          outcome ||= failure_outcome_for_kind_(:exhausted)
        ensure

          finish_progress_(meter, outcome)
        end

        outcome
      end

      # On success: when stdout is a TTY, write
      # `usb-cracker: winning suffix="…"` (suffix text green; quotes plain);
      # when stdout is piped, write only the bare display suffix
      # (scripting). Neither path uses {Diagnostics} / {CandidateLog}. On
      # failure: abort with a non-secret message. Pass +abort_exit: nil+
      # from tests.
      def report(
        outcome,
        abort_exit: :from_outcome,
        stderr: $stderr,
        stdout: $stdout
      )

        CallTrace.enter(
          'UsbCracker::Search.report',
          "kind=#{outcome.respond_to?(:kind) ? outcome.kind : :invalid}",
        )

        unless outcome.is_a?(Outcome)

          raise ArgumentError, 'outcome must be a UsbCracker::Search::Outcome'
        end

        if outcome.success?

          if stdout.respond_to?(:tty?) && stdout.tty?

            green = Progress::CLR_GREEN
            reset = Progress::CLR_RESET
            stdout.puts(
              "usb-cracker: winning suffix=\"#{green}#{outcome.suffix}#{reset}\"",
            )
          else

            stdout.puts outcome.suffix
          end

          return outcome
        end

        exit_code = abort_exit == :from_outcome ? outcome.exit_status : abort_exit

        Cli.abort outcome.message, exit: exit_code, stderr: stderr
      end

      private
      def default_attempt_(**kwargs)

        Unlock.attempt(**kwargs)
      end

      def resolve_progress_(options, progress, log)

        return nil if progress.nil?
        return progress unless progress == :auto
        return nil if log
        return nil if options.respond_to?(:trace_suffixes?) && options.trace_suffixes?

        Progress.meter_for(
          options,
          total: Candidates.count(options),
        )
      end

      def mid_from_(options)

        return options.mid if options.respond_to?(:mid)

        ''
      end

      def display_suffix_(options, suffix)

        if options.respond_to?(:display_suffix)

          return options.display_suffix(suffix)
        end

        suffix
      end

      def emit_before_(index, suffix, log, meter, options)

        if log

          log.call(index, suffix, nil)
          return
        end

        if options.respond_to?(:trace_suffixes?) && options.trace_suffixes?

          meter.clear! if meter
          CandidateLog.emit_before(index, suffix)
          return
        end

        meter.tick(index, suffix) if meter
      end

      def emit_after_(index, suffix, result, options, log)

        return unless options.trace_suffixes?

        if log

          log.call(index, suffix, result)
        else

          CandidateLog.emit_after(index, suffix, result)
        end
      end

      def finish_progress_(meter, outcome)

        return if meter.nil?

        if outcome.nil?

          meter.clear!
        elsif outcome.success?

          meter.finish(success: true)
        else

          meter.finish(success: false)
        end
      end

      def success_outcome_(suffix)

        Outcome.new(
          exit_status: 0,
          kind: :success,
          message: nil,
          suffix: suffix,
        )
      end

      def failure_outcome_(result, index:, suffix:, volume:)

        kind = result.status
        base = if kind == :error && result.detail.is_a?(String) && !result.detail.empty?

          result.detail
        else

          MESSAGE.fetch(kind, MESSAGE[:error])
        end

        Outcome.new(
          exit_status: 1,
          kind: kind,
          message: enrich_failure_message_(
            base,
            index: index,
            result: result,
            suffix: suffix,
            volume: volume,
          ),
          suffix: nil,
        )
      end

      # Append attempt context for stop failures. PREFIX is always shown as
      # {PREFIX_MASK}; the display suffix (mid + generated) follows.
      def enrich_failure_message_(base, index:, result:, suffix:, volume:)

        parts = [
          base,
          "attempt=#{index}",
          "volume=#{volume}",
          "engine=#{result.engine}",
        ]
        unless result.exitstatus.nil?

          parts << "exitstatus=#{result.exitstatus}"
        end
        parts << "passphrase=#{PREFIX_MASK}#{suffix}"
        stderr = result.respond_to?(:stderr) ? result.stderr : nil
        if stderr.is_a?(String) && !stderr.empty?

          parts << "diskutil=#{stderr}"
        end

        parts.join('; ')
      end

      def failure_outcome_for_kind_(kind)

        Outcome.new(
          exit_status: 1,
          kind: kind,
          message: MESSAGE.fetch(kind),
          suffix: nil,
        )
      end
    end

    # Opt-in pre-attempt candidate logging (and post-status lines) for
    # `--trace-suffixes` . Writes to +$stderr+ via
    # {Diagnostics.emit_stderr!}. Never logs PREFIX.
    module CandidateLog

      class << self

        def emit_before(index, suffix)

          Diagnostics.emit_stderr!("attempt #{index} suffix=#{suffix}")
        end

        def emit_after(index, suffix, result)

          Diagnostics.emit_stderr!(
            "attempt #{index} suffix=#{suffix} status=#{result.status}",
          )
        end
      end
    end

  end # module Search
end # module UsbCracker


# ############################## end of file ############################# #
