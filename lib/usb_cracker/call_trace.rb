# frozen_string_literal: true
# ######################################################################## #
# File:     usb_cracker/call_trace.rb
#
# Purpose:  Opt-in function-entry tracing at Pantheios :info
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

require 'usb_cracker/diagnostics'


module UsbCracker

  # Opt-in function-entry tracing ( `--trace-calls` ). Off by default. When
  # enabled, {#enter} logs at Pantheios severity +:info+ to the console
  # sink. Callers must never pass PREFIX, suffix, or assembled passphrase
  # material in +detail+.
  module CallTrace

    class << self

      def enable!

        @enabled = true
      end

      def disable!

        @enabled = false
      end

      def enabled?

        !!@enabled
      end

      # Log a function-call entry when tracing is on. No-op when off (does
      # not load Pantheios).
      #
      # @param name [String] fully-qualified callable name
      # @param detail [String, nil] non-secret context (never secrets)
      def enter(name, detail = nil)

        return unless enabled?

        message = if detail.nil? || detail.empty?

          "enter #{name}"
        else

          "enter #{name} #{detail}"
        end

        Diagnostics.emit(:info, message)
      end
    end
  end # module CallTrace
end # module UsbCracker


# ############################## end of file ############################# #
