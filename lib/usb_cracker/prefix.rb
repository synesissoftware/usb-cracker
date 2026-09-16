# frozen_string_literal: true
# ######################################################################## #
# File:     usb_cracker/prefix.rb
#
# Purpose:  Confirmed hidden PREFIX prompt (TTY-only; in-memory)
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
require 'usb_cracker/cli'
require 'usb_cracker/secret_buffer'


module UsbCracker

  # Confirmed PREFIX read. Prompts twice with hidden input and accepts only
  # when both entries match, so a mistyped PREFIX cannot drive a long unlock
  # search. On a TTY the first prompt uses stdlib {IO#getpass}; the
  # confirmation prompt then **overlays** that same terminal line (cursor up
  # + clear) with a character-at-a-time reader and a non-secret match
  # indicator. On success that line is cleared before return so the next
  # output (progress / abort) reuses it. There is no non-TTY fallback:
  # PREFIX is never read from the environment, a file, argv, or redirected
  # stdin. HighLine is not used for this prompt (avoids extra copies).
  #
  # Inject +getpass:+ (a callable that receives the prompt string on each
  # call — twice on the success path) in unit tests so CI needs no real TTY;
  # the live match indicator and line overlay are skipped when +getpass+ is
  # injected.
  module Prefix

    DEFAULT_CONFIRM_PROMPT = 'Confirm prefix: '
    DEFAULT_PROMPT = 'Prefix: '

    # Pure match-state for confirmation indicator / tests. Never embeds
    # secret characters — only lengths and a diverge flag.
    MatchState = Struct.new(
      :diverged,
      :matched,
      :total,
      :typed,
      keyword_init: true,
    ) do

      def matching?

        !diverged
      end
    end

    class << self

      # Compare confirmation so far against the first PREFIX entry.
      def match_state(first, second)

        first_s = first.to_s
        second_s = second.to_s
        matched = 0
        diverged = false

        second_s.each_char.with_index do |ch, index|

          if index >= first_s.length || first_s[index] != ch

            diverged = true
            break
          end

          matched += 1
        end

        if !diverged && second_s.length > first_s.length

          diverged = true
        end

        MatchState.new(
          diverged: diverged,
          matched: matched,
          total: first_s.length,
          typed: second_s.length,
        )
      end

      # Format a single non-secret indicator line for +state+ (no PREFIX
      # characters). Used by the live confirm reader and unit tests.
      def format_match_indicator(state)

        total = [ state.total, 0 ].max
        matched = [ state.matched, 0 ].max
        matched = [ matched, total ].min if total > 0

        if total <= 0

          return '[] 0/0'
        end

        chars = Array.new(total, '-')
        matched.times { |i| chars[i] = '#' }

        if state.diverged

          pos = matched
          pos = total - 1 if pos >= total
          chars[pos] = '!' if pos >= 0
          status = 'diverge'
        else

          status = matched == total && state.typed == total ? 'match' : 'matching'
        end

        "[#{chars.join}] #{matched}/#{total} #{status}"
      end

      # Prompt twice for PREFIX and return a {SecretBuffer} when both
      # entries match. With a block, yields the buffer and always
      # {SecretBuffer#wipe}s it in +ensure+ (including {SystemExit} from
      # {Cli.abort}). The confirmation copy is wiped before the buffer is
      # returned. Failures go through {Cli.abort} (same as LibCLImate usage
      # aborts): a single non-secret stderr line, no Ruby backtrace.
      #
      # @param abort_exit [Integer, nil] exit status for {Cli.abort}; pass
      #   +nil+ from unit tests to receive {Cli::UsageError} instead
      # @param input [IO] stdin-like object; {IO#tty?} and {IO#getpass} are
      #   used when +getpass+ is omitted
      # @param getpass [Proc, nil] injectable hidden-input callable
      # @param prompt [String] first prompt label (no echo of the secret)
      # @param confirm_prompt [String] second prompt label
      # @param stderr [IO] destination for abort messages and the live
      #   confirmation match indicator
      def read!(
        abort_exit: 1,
        confirm_prompt: DEFAULT_CONFIRM_PROMPT,
        getpass: nil,
        input: $stdin,
        prompt: DEFAULT_PROMPT,
        stderr: $stderr
      )

        CallTrace.enter('UsbCracker::Prefix.read!')

        first = normalize_raw_(obtain_raw_(input, getpass, prompt, abort_exit, stderr))

        if blank_prefix_(first)

          wipe_raw_(first)
          clear_prompt_line_(stderr) if getpass.nil?
          fail_usage_('prefix must not be empty', abort_exit, stderr)
        end

        unless first.is_a?(String)

          raise ArgumentError, 'getpass must return a String'
        end

        second = if getpass.nil?

          reclaim_prompt_line_(stderr)
          normalize_raw_(
            confirm_raw_(
              first,
              abort_exit: abort_exit,
              input: input,
              prompt: confirm_prompt,
              stderr: stderr,
            ),
          )
        else

          normalize_raw_(obtain_raw_(input, getpass, confirm_prompt, abort_exit, stderr))
        end

        begin

          unless second.is_a?(String)

            wipe_raw_(first)
            raise ArgumentError, 'getpass must return a String'
          end

          if blank_prefix_(second) || first != second

            wipe_raw_(first)
            wipe_raw_(second)
            clear_prompt_line_(stderr) if getpass.nil?
            fail_usage_('prefixes do not match', abort_exit, stderr)
          end
        ensure

          wipe_raw_(second)
        end

        clear_prompt_line_(stderr) if getpass.nil?

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

      # Character-at-a-time confirmation with a live match indicator on
      # +stderr+. Never echoes PREFIX characters.
      def confirm_raw_(first, abort_exit:, input:, prompt:, stderr:)

        require 'io/console'

        unless input.respond_to?(:tty?) && input.tty?

          fail_usage_('prefix prompt requires a TTY; stdin is not a terminal', abort_exit, stderr)
        end

        unless input.respond_to?(:getch) || input.respond_to?(:raw)

          fail_usage_('prefix prompt requires a TTY; stdin is not a terminal', abort_exit, stderr)
        end

        second = String.new
        redraw_confirm_(stderr, prompt, first, second)

        read_confirm_chars_(input, first, second, prompt, stderr)

        # Leave the shared prompt line in place for {#clear_prompt_line_}
        # after match validation (or clear it on interrupt below).
        second
      end

      def read_confirm_chars_(input, first, second, prompt, stderr)

        loop do

          ch = read_one_char_(input)
          case ch
          when nil

            break
          when "\r", "\n"

            break
          when "\u0003"

            clear_prompt_line_(stderr)
            raise Interrupt
          when "\u007F", "\b", "\u0015"

            if ch == "\u0015"

              second.clear
            else

              second.chop! unless second.empty?
            end
            redraw_confirm_(stderr, prompt, first, second)
          when "\e"

            # Ignore bare escapes / arrow prefixes.
            next
          else

            next if ch.nil? || ch.empty?
            next if ch.ord < 32

            second << ch
            redraw_confirm_(stderr, prompt, first, second)
          end
        end
      end

      def read_one_char_(input)

        if input.respond_to?(:getch)

          return input.getch
        end

        input.raw do

          input.getc
        end
      end

      def redraw_confirm_(stderr, prompt, first, second)

        state = match_state(first, second)
        indicator = format_match_indicator(state)
        colour = if !stderr.respond_to?(:tty?) || !stderr.tty?

          indicator
        elsif state.diverged

          "\e[31m#{indicator}\e[0m"
        elsif state.matched == state.total && state.typed == state.total

          "\e[32m#{indicator}\e[0m"
        else

          "\e[36m#{indicator}\e[0m"
        end

        stderr.print "\r\e[2K#{prompt}#{colour}"
        stderr.flush
      end

      # After {IO#getpass} advances past the prompt line, move up and clear
      # so Confirm can overwrite the same terminal row.
      def reclaim_prompt_line_(stderr)

        return unless stderr.respond_to?(:tty?) && stderr.tty?

        stderr.print "\e[1A\r\e[2K"
        stderr.flush
      end

      def clear_prompt_line_(stderr)

        return unless stderr.respond_to?(:tty?) && stderr.tty?

        stderr.print "\r\e[2K"
        stderr.flush
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
