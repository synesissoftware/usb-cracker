# frozen_string_literal: true
# ######################################################################## #
# File:     usb_cracker/diskutil.rb
#
# Purpose:  diskutil unlockVolume argv builder, runner, and classifier
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

require 'open3'

require 'usb_cracker/call_trace'


module UsbCracker

  # Apple `diskutil` child-process adapter. Builds argv, runs the command,
  # and classifies stdout/stderr. The passphrase is never placed on argv:
  # callers must pass it as stdin alongside `-stdinpassphrase` .
  #
  # Engine selection for unlock verbs:
  # * +:apfs+ — `diskutil apfs unlockVolume <id> -stdinpassphrase`
  # * +:core_storage+ —
  #   `diskutil coreStorage unlockVolume <id> -stdinpassphrase`
  #
  # {Unlock.attempt} with `engine: :auto` tries APFS first and falls back to
  # Core Storage only when APFS classifies as +:wrong_target+.
  module Diskutil

    COMMAND = 'diskutil'
    STDIN_PASSPHRASE_FLAG = '-stdinpassphrase'
    UNLOCK_VERB = 'unlockVolume'

    ENGINES = [
      :apfs,
      :core_storage,
    ].freeze

    Invocation = Struct.new(
      :exitstatus,
      :stderr,
      :stdout,
      keyword_init: true,
    )

    # Default production runner. Uses {Open3.capture3} with an argv array
    # (no shell). +stdin_data+ is the passphrase line; it is not copied onto
    # argv.
    class Open3Runner

      def call(argv, stdin_data:)

        CallTrace.enter('UsbCracker::Diskutil::Open3Runner#call')

        unless argv.is_a?(Array)

          raise ArgumentError, 'argv must be an Array'
        end

        stdout, stderr, status = Open3.capture3(*argv, stdin_data: stdin_data)

        Invocation.new(
          exitstatus: status && status.exitstatus,
          stderr: stderr,
          stdout: stdout,
        )
      rescue Errno::ENOENT

        Invocation.new(
          exitstatus: 127,
          stderr: 'diskutil not found',
          stdout: '',
        )
      end
    end

    class << self

      # Argv for an unlockVolume attempt. +volume+ is a device id or UUID
      # already supplied by the CLI. Never includes `-passphrase` .
      def unlock_argv(engine, volume)

        CallTrace.enter(
          'UsbCracker::Diskutil.unlock_argv',
          "engine=#{engine} volume=#{volume}",
        )

        unless volume.is_a?(String) && !volume.empty?

          raise ArgumentError, 'volume must be a non-empty String'
        end

        if volume.start_with?('-')

          raise ArgumentError, 'volume must be a device id or UUID'
        end

        case engine
        when :apfs

          [
            COMMAND,
            'apfs',
            UNLOCK_VERB,
            volume,
            STDIN_PASSPHRASE_FLAG,
          ]
        when :core_storage

          [
            COMMAND,
            'coreStorage',
            UNLOCK_VERB,
            volume,
            STDIN_PASSPHRASE_FLAG,
          ]
        else

          raise ArgumentError, "unknown engine #{engine.inspect}"
        end
      end

      # Classify a diskutil invocation. Patterns are matched against
      # stdout+stderr (case-insensitive). The passphrase must not be passed
      # in. Returns a status symbol for {Unlock::Result}.
      def classify_status(stdout:, stderr:, exitstatus:)

        CallTrace.enter(
          'UsbCracker::Diskutil.classify_status',
          "exitstatus=#{exitstatus}",
        )

        text = "#{stdout}\n#{stderr}"

        return :already_unlocked if already_unlocked_output?(text)
        return :auth_failed if auth_failed_output?(text)
        return :busy if busy_output?(text)
        return :wrong_target if wrong_target_output?(text)
        return :success if exitstatus == 0

        :error
      end

      # Coerce a runner return value to {Invocation}. Accepts {Invocation},
      # an object with +stdout+/+stderr+/+exitstatus+, or a three-element
      # array +[stdout, stderr, exitstatus]+.
      def invocation_from(raw)

        CallTrace.enter('UsbCracker::Diskutil.invocation_from')

        case raw
        when Invocation

          raw
        when Array

          stdout, stderr, exitstatus = raw
          exitstatus = exitstatus.exitstatus if exitstatus.respond_to?(:exitstatus)

          Invocation.new(
            exitstatus: exitstatus,
            stderr: stderr.to_s,
            stdout: stdout.to_s,
          )
        else

          exitstatus = raw.respond_to?(:exitstatus) ? raw.exitstatus : nil
          stderr = raw.respond_to?(:stderr) ? raw.stderr.to_s : ''
          stdout = raw.respond_to?(:stdout) ? raw.stdout.to_s : ''

          Invocation.new(
            exitstatus: exitstatus,
            stderr: stderr,
            stdout: stdout,
          )
        end
      end

      private
      def already_unlocked_output?(text)

        match_any?(text, [
          /already attached/i,
          /already unlocked/i,
          /not locked/i,
        ])
      end

      def auth_failed_output?(text)

        match_any?(text, [
          /-69749\b/,
          /authentication (error|failed)/i,
          /incorrect passphrase/i,
          /passphrase incorrect/i,
          /passphrase is incorrect/i,
          /unable to register passphrase/i,
          /unable to unlock the core\s*storage volume/i,
          /user does not exist/i,
        ])
      end

      def busy_output?(text)

        match_any?(text, [
          /resource busy/i,
          /temporarily unavailable/i,
        ])
      end

      def wrong_target_output?(text)

        match_any?(text, [
          /could not find (disk|.+\s)?volume/i,
          /could not find disk/i,
          /does not appear to be a (valid )?core\s*storage/i,
          /invalid disk identifier/i,
          /is not a core\s*storage/i,
          /not a core\s*storage/i,
          /not an apfs (container|volume)/i,
          /unrecognized (disk|volume)/i,
        ])
      end

      def match_any?(text, patterns)

        patterns.any? { |re| text.match?(re) }
      end
    end
  end # module Diskutil
end # module UsbCracker


# ############################## end of file ############################# #
