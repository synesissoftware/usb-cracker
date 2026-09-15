# frozen_string_literal: true
# ######################################################################## #
# File:     usb_cracker/prefix.rb
#
# Purpose:  One-shot hidden PREFIX prompt (TTY-only; in-memory)
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

  # One-shot PREFIX read. Primary prompt path is stdlib {IO#getpass}
  # (io/console) on a TTY. There is no non-TTY fallback: PREFIX is never
  # read from the environment, a file, argv, or redirected stdin. HighLine
  # is not used for this prompt (avoids extra copies).
  #
  # Inject +getpass:+ (a callable that receives the prompt string once) in
  # unit tests so CI needs no real TTY.
  module Prefix

    DEFAULT_PROMPT = 'Prefix: '

    class << self

      # Prompt once for PREFIX and return a {SecretBuffer}. With a block,
      # yields the buffer and always {SecretBuffer#wipe}s it in +ensure+
      # (including {SystemExit} from {Cli.abort}).
      #
      # @param input [IO] stdin-like object; {IO#tty?} and {IO#getpass}
      #   are used when +getpass+ is omitted
      # @param getpass [Proc, nil] injectable hidden-input callable
      # @param prompt [String] prompt label (no echo of the secret)
      def read!(input: $stdin, getpass: nil, prompt: DEFAULT_PROMPT)

        raw = obtain_raw_(input, getpass, prompt)

        if raw.is_a?(String)

          if raw.frozen?

            raw = raw.chomp
          else

            raw.chomp!
          end
        end

        if blank_prefix_(raw)

          SecretBuffer.wipe_string!(raw) if raw.is_a?(String)
          raise Cli::UsageError, 'prefix must not be empty'
        end

        unless raw.is_a?(String)

          raise ArgumentError, 'getpass must return a String'
        end

        buffer = SecretBuffer.new(raw)

        return buffer unless block_given?

        begin

          yield buffer
        ensure

          buffer.wipe
        end
      end

      private
      def obtain_raw_(input, getpass, prompt)

        if getpass.nil?

          unless input.respond_to?(:tty?) && input.tty?

            raise Cli::UsageError, 'prefix prompt requires a TTY; stdin is not a terminal'
          end

          return default_getpass_(input, prompt)
        end

        getpass.call(prompt)
      end

      def default_getpass_(input, prompt)

        require 'io/console'

        unless input.respond_to?(:getpass)

          raise Cli::UsageError, 'prefix prompt requires a TTY; stdin is not a terminal'
        end

        input.getpass(prompt)
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
