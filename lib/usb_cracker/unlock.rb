# frozen_string_literal: true
# ######################################################################## #
# File:     usb_cracker/unlock.rb
#
# Purpose:  One unlock attempt: PREFIX + suffix via diskutil stdin
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
require 'usb_cracker/diskutil'
require 'usb_cracker/secret_buffer'


module UsbCracker

  # One passphrase attempt against a volume. Assembles PREFIX + optional
  # mid-section + suffix in memory, pipes the result to `diskutil` on stdin
  # ( `-stdinpassphrase` ), wipes the ephemeral full-passphrase buffer, and
  # returns a typed {Result}. Never logs PREFIX, suffix, or the
  # concatenation.
  #
  # Passphrase transport: Apple `diskutil` reads the passphrase from stdin
  # when `-stdinpassphrase` is given. The `-passphrase` flag is not used (it
  # would place the secret on process argv, visible via `ps` ). No temporary
  # file is used. See SECURITY.md.
  #
  # Engine selection ( `engine:` ):
  # * +:apfs+ — APFS unlockVolume only;
  # * +:core_storage+ — Core Storage unlockVolume only;
  # * +:auto+ (default) — try APFS first; fall back to Core Storage only
  #   when APFS classifies as +:wrong_target+ (the APFS verb does not apply
  #   to this volume). Authentication failure, busy, already unlocked,
  #   success, and unexpected errors do not fall back.
  #
  # The default runner is {Diskutil::Open3Runner} on Darwin. On other
  # platforms, a missing runner returns +:error+ ( `diskutil` unlock is
  # macOS-only) without spawning a child. Tests inject +runner:+.
  module Unlock

    ENGINES = [
      :apfs,
      :auto,
      :core_storage,
    ].freeze

    STATUSES = [
      :already_unlocked,
      :auth_failed,
      :busy,
      :error,
      :success,
      :wrong_target,
    ].freeze

    # Typed outcome of one attempt. +detail+ is a canned, non-secret phrase
    # (or a short non-secret diagnostic). +engine+ is the verb that produced
    # this result (+:apfs+ or +:core_storage+). +stderr+ may carry a
    # truncated `diskutil` stderr snippet for +:error+ diagnostics (never
    # the passphrase).
    Result = Struct.new(
      :detail,
      :engine,
      :exitstatus,
      :status,
      :stderr,
      keyword_init: true,
    ) do

      def success?

        status == :success
      end
    end

    DETAIL = {
      already_unlocked: 'already unlocked',
      auth_failed: 'authentication failed',
      busy: 'volume busy',
      error: 'diskutil failed',
      success: 'unlocked',
      wrong_target: 'not an applicable volume',
    }.freeze

    class << self

      # Attempt to unlock +volume+ with PREFIX + optional +mid+ + +suffix+.
      #
      # @param volume [String] device id or UUID ({Cli::Options#volume})
      # @param prefix [SecretBuffer, String] live PREFIX; not wiped here
      # @param mid [String] literal between PREFIX and suffix (may be empty)
      # @param suffix [String] candidate suffix (may be empty)
      # @param engine [Symbol] +:auto+, +:apfs+, or +:core_storage+
      # @param runner [#call] injectable Open3 wrapper; called as
      #   `runner.call(argv, stdin_data:)` and must not put +stdin_data+
      #   onto argv
      # @return [Result]
      def attempt(
        engine: :auto,
        mid: '',
        prefix:,
        runner: nil,
        suffix:,
        volume:
      )

        CallTrace.enter(
          'UsbCracker::Unlock.attempt',
          "engine=#{engine} volume=#{volume}",
        )

        validate_engine_(engine)
        argv_volume = validate_volume_(volume)
        suffix_s = validate_suffix_(suffix)
        mid_s = validate_mid_(mid)
        prefix_s = prefix_string_(prefix)

        passphrase = String.new(prefix_s)
        passphrase << mid_s
        passphrase << suffix_s
        passphrase << "\n" unless passphrase.end_with?("\n")

        begin

          run_attempt_(
            engine: engine,
            passphrase: passphrase,
            runner: runner,
            volume: argv_volume,
          )
        ensure

          SecretBuffer.wipe_string!(passphrase)
        end
      end

      private
      def run_attempt_(engine:, passphrase:, runner:, volume:)

        if runner.nil?

          unless darwin?

            return result_(
              :error,
              engine == :core_storage ? :core_storage : :apfs,
              nil,
              'diskutil unlock is macOS-only',
            )
          end

          runner = Diskutil::Open3Runner.new
        end

        engines = engine == :auto ? [ :apfs, :core_storage ] : [ engine ]
        last = nil

        engines.each_with_index do |item, index|

          argv = Diskutil.unlock_argv(item, volume)
          raw = runner.call(argv, stdin_data: passphrase)
          invocation = Diskutil.invocation_from(raw)
          status = Diskutil.classify_status(
            exitstatus: invocation.exitstatus,
            stderr: invocation.stderr,
            stdout: invocation.stdout,
          )
          last = result_(
            status,
            item,
            invocation.exitstatus,
            nil,
            invocation.stderr,
          )

          fallback = engine == :auto &&
            status == :wrong_target &&
            index < engines.size - 1

          return last unless fallback
        end

        last
      end

      def result_(status, engine, exitstatus, detail = nil, stderr = nil)

        Result.new(
          detail: detail || DETAIL.fetch(status, DETAIL[:error]),
          engine: engine,
          exitstatus: exitstatus,
          status: status,
          stderr: sanitize_stderr_(stderr),
        )
      end

      def sanitize_stderr_(stderr)

        return nil if stderr.nil?

        text = stderr.to_s.strip.gsub(/\s+/, ' ')
        return nil if text.empty?

        text.length > 200 ? "#{text[0, 200]}…" : text
      end

      def validate_engine_(engine)

        return if ENGINES.include?(engine)

        raise ArgumentError, "unknown engine #{engine.inspect}"
      end

      def validate_volume_(volume)

        Diskutil.unlock_argv(:apfs, volume)

        volume
      end

      def validate_suffix_(suffix)

        unless suffix.is_a?(String)

          raise ArgumentError, 'suffix must be a String'
        end

        suffix
      end

      def validate_mid_(mid)

        return '' if mid.nil?

        unless mid.is_a?(String)

          raise ArgumentError, 'mid must be a String'
        end

        mid
      end

      def prefix_string_(prefix)

        if prefix.is_a?(SecretBuffer)

          return prefix.to_s
        end

        unless prefix.is_a?(String)

          raise ArgumentError, 'prefix must be a SecretBuffer or String'
        end

        prefix
      end

      def darwin?

        RUBY_PLATFORM.include?('darwin')
      end
    end
  end # module Unlock
end # module UsbCracker


# ############################## end of file ############################# #
