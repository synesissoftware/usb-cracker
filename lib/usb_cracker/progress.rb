# frozen_string_literal: true
# ######################################################################## #
# File:     usb_cracker/progress.rb
#
# Purpose:  Homebrew-style stderr progress meter for suffix search
#
# Created:  16th September 2026
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


module UsbCracker

  # Single-line stderr progress meter modelled on Homebrew bottle download
  # lines: spinner, blue label/counts, cyan hash bar, quoted display suffix
  # (green text, plain quotes, two trailing spaces), then an estimated time
  # remaining (`ETA …`) from mean attempt duration. Never prints PREFIX.
  # Active only when +stderr+ is a TTY (or when +force:+ is set in tests).
  module Progress

    SPINNER_FRAMES = [
      '⠋',
      '⠙',
      '⠹',
      '⠸',
      '⠼',
      '⠴',
      '⠦',
      '⠧',
      '⠇',
      '⠏',
    ].freeze

    BAR_WIDTH = 40
    LABEL = 'Attempting '

    CLR_BLUE = "\e[34m"
    CLR_CYAN = "\e[36m"
    CLR_GREEN = "\e[32m"
    CLR_RESET = "\e[0m"

    # Mutable meter rewritten in place with `\r` / clear-line.
    class Meter

      def initialize(clock: nil, force: false, stderr: $stderr, total:)

        CallTrace.enter(
          'UsbCracker::Progress::Meter.new',
          "total=#{total}",
        )

        @total = total.nil? || total < 0 ? 0 : total.to_i
        @stderr = stderr
        @frame = 0
        @active = false
        @enabled = force || (stderr.respond_to?(:tty?) && stderr.tty?)
        @colour = @enabled
        @clock = clock || method(:default_clock_)
        @started_at = nil
        @ticks_seen = 0
      end

      def enabled?

        @enabled
      end

      # Redraw the in-place progress line for attempt +index+ (1-based).
      # +suffix+ is the display form (mid + generated); never PREFIX.
      # ETA uses the mean duration of completed attempts (prior ticks).
      def tick(index, suffix = nil)

        return self unless @enabled

        @active = true
        now = @clock.call
        @started_at ||= now
        @last_suffix = suffix.nil? ? nil : suffix.to_s
        @frame = (@frame + 1) % SPINNER_FRAMES.size
        line = format_line_(
          completed: @ticks_seen,
          done: false,
          index: index,
          now: now,
          spinner: SPINNER_FRAMES[@frame],
          suffix: @last_suffix,
        )
        @ticks_seen += 1
        @stderr.print "\r\e[2K#{line}"
        @stderr.flush

        self
      end

      # Clear the progress line (before an abort or suffix trace line).
      def clear!

        return self unless @enabled && @active

        @stderr.print "\r\e[2K"
        @stderr.flush
        @active = false

        self
      end

      # Finish with a check or cross and advance to the next line.
      def finish(success:)

        return self unless @enabled && @active

        mark = success ? '✔︎' : '✘'
        line = format_line_(
          completed: @ticks_seen,
          done: true,
          index: @last_index || @total,
          now: @clock.call,
          spinner: mark,
          suffix: @last_suffix,
        )
        @stderr.print "\r\e[2K#{line}\n"
        @stderr.flush
        @active = false

        self
      end

      private
      def default_clock_

        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end

      def format_line_(completed:, done:, index:, now:, spinner:, suffix: nil)

        @last_index = index
        n = index.to_i
        total = @total
        fraction = if total > 0

          [ n.to_f / total, 1.0 ].min
        else

          0.0
        end
        filled = (fraction * BAR_WIDTH).floor
        filled = BAR_WIDTH if done && total > 0 && n >= total
        filled = [ filled, BAR_WIDTH ].min
        empty = BAR_WIDTH - filled
        bar = ('#' * filled) + ('-' * empty)
        counts = if total > 0

          format(' %d/%d ', n, total)
        else

          format(' %d ', n)
        end

        parts = [
          spinner,
          ' ',
          paint_(CLR_BLUE, LABEL),
          paint_(CLR_CYAN, bar),
          paint_(CLR_BLUE, counts),
        ]

        unless suffix.nil?

          parts << '"'
          parts << paint_(CLR_GREEN, suffix)
          parts << '"  '
        end

        eta = eta_text_(completed: completed, done: done, now: now)
        parts << paint_(CLR_BLUE, eta) unless eta.nil?
        parts << ' '

        parts.join
      end

      # Mean duration of completed attempts × remaining (including current).
      # No estimate until at least one attempt has finished.
      def eta_text_(completed:, done:, now:)

        return nil if done
        return nil if @started_at.nil?
        return nil if @total <= 0
        return nil if completed <= 0

        elapsed = now - @started_at
        return nil if elapsed <= 0

        remaining_attempts = @total - completed
        return nil if remaining_attempts <= 0

        mean = elapsed / completed.to_f
        secs = mean * remaining_attempts
        "ETA #{Progress.format_eta(secs)}"
      end

      def paint_(colour, text)

        return text unless @colour

        "#{colour}#{text}#{CLR_RESET}"
      end
    end

    class << self

      # Format a non-negative duration as `Hh Mm Ss`, omitting leading
      # zero-hour / zero-minute units (always includes seconds).
      def format_eta(seconds)

        secs = seconds.to_f
        secs = 0 if secs.nan? || secs.infinite?
        secs = [ secs.round, 0 ].max

        hours = secs / 3600
        mins = (secs % 3600) / 60
        rem_s = secs % 60

        parts = []
        parts << "#{hours}h" if hours > 0
        parts << "#{mins}m" if hours > 0 || mins > 0
        parts << "#{rem_s}s"
        parts.join(' ')
      end

      # Build a meter, or +nil+ when progress should stay silent.
      def meter_for(options, force: false, stderr: $stderr, total:)

        CallTrace.enter('UsbCracker::Progress.meter_for')

        return nil if options.respond_to?(:trace_suffixes?) && options.trace_suffixes?

        Meter.new(force: force, stderr: stderr, total: total)
      end
    end
  end # module Progress
end # module UsbCracker


# ############################## end of file ############################# #
