# frozen_string_literal: true
# ######################################################################## #
# File:     usb_cracker/prefix.rb
#
# Purpose:  Confirmed hidden PREFIX prompt (TTY-only; in-memory)
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

require 'usb_cracker/cli'
require 'usb_cracker/secret_buffer'


module UsbCracker

  # Confirmed PREFIX read. Prompts twice with hidden input and accepts
  # only when both entries match, so a mistyped PREFIX cannot drive a
  # long unlock search. Primary prompt path is stdlib {IO#getpass}
  # (io/console) on a TTY. There is no non-TTY fallback: PREFIX is never
  # read from the environment, a file, argv, or redirected stdin. HighLine
  # is not used for this prompt (avoids extra copies).
  #
  # Inject +getpass:+ (a callable that receives the prompt string on each
  # call — twice on the success path) in unit tests so CI needs no real TTY.
  module Prefix

    DEFAULT_CONFIRM_PROMPT = 'Confirm prefix: '
    DEFAULT_PROMPT = 'Prefix: '

    class << self

      # Prompt twice for PREFIX and return a {SecretBuffer} when both
      # entries match. With a block, yields the buffer and always
      # {SecretBuffer#wipe}s it in +ensure+ (including {SystemExit} from
      # {Cli.abort}). The confirmation copy is wiped before the buffer is
      # returned. Failures go through {Cli.abort} (same as LibCLImate
      # usage aborts): a single non-secret stderr line, no Ruby backtrace.
      #
      # @param abort_exit [Integer, nil] exit status for {Cli.abort};
      #   pass +nil+ from unit tests to receive {Cli::UsageError} instead
      # @param input [IO] stdin-like object; {IO#tty?} and {IO#getpass}
      #   are used when +getpass+ is omitted
      # @param getpass [Proc, nil] injectable hidden-input callable
      # @param prompt [String] first prompt label (no echo of the secret)
      # @param confirm_prompt [String] second prompt label
      # @param stderr [IO] destination for abort messages
      def read!(
        abort_exit: 1,
        confirm_prompt: DEFAULT_CONFIRM_PROMPT,
        getpass: nil,
        input: $stdin,
        prompt: DEFAULT_PROMPT,
        stderr: $stderr
      )

        first = normalize_raw_(obtain_raw_(input, getpass, prompt, abort_exit, stderr))

        if blank_prefix_(first)

          wipe_raw_(first)
          fail_usage_('prefix must not be empty', abort_exit, stderr)
        end

        unless first.is_a?(String)

          raise ArgumentError, 'getpass must return a String'
        end

        second = normalize_raw_(obtain_raw_(input, getpass, confirm_prompt, abort_exit, stderr))

        begin

          unless second.is_a?(String)

            wipe_raw_(first)
            raise ArgumentError, 'getpass must return a String'
          end

          if blank_prefix_(second) || first != second

            wipe_raw_(first)
            wipe_raw_(second)
            fail_usage_('prefixes do not match', abort_exit, stderr)
          end
        ensure

          wipe_raw_(second)
        end

        buffer = SecretBuffer.new(first)

        return buffer unless block_given?

        begin

          yield buffer
        ensure

          buffer.wipe
        end
      end

      private
      def obtain_raw_(input, getpass, prompt, abort_exit, stderr)

        if getpass.nil?

          unless input.respond_to?(:tty?) && input.tty?

            fail_usage_('prefix prompt requires a TTY; stdin is not a terminal', abort_exit, stderr)
          end

          return default_getpass_(input, prompt, abort_exit, stderr)
        end

        getpass.call(prompt)
      end

      def default_getpass_(input, prompt, abort_exit, stderr)

        require 'io/console'

        unless input.respond_to?(:getpass)

          fail_usage_('prefix prompt requires a TTY; stdin is not a terminal', abort_exit, stderr)
        end

        input.getpass(prompt)
      end

      def fail_usage_(message, abort_exit, stderr)

        Cli.abort message, exit: abort_exit, stderr: stderr

        raise Cli::UsageError, message
      end

      def normalize_raw_(raw)

        return raw unless raw.is_a?(String)

        if raw.frozen?

          raw.chomp
        else

          raw.chomp!
          raw
        end
      end

      def wipe_raw_(raw)

        SecretBuffer.wipe_string!(raw) if raw.is_a?(String)
      end

      def blank_prefix_(raw)

        return true if raw.nil?
        return false unless raw.is_a?(String)
        return true if raw.empty?

        raw.match?(/\A[[:space:]]*\z/)
      end
    end
  end # module Prefix
end # module UsbCracker


# ############################## end of file ############################# #
