# frozen_string_literal: true
# ######################################################################## #
# File:     usb_cracker/diagnostics.rb
#
# Purpose:  Shared Pantheios coloured-console diagnostic sink for
# usb-cracker
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


module UsbCracker

  # Shared console-only Pantheios wiring via
  # {Pantheios::Services::ColouredConsoleLogService}. Used by {CallTrace}
  # and {Search::SuffixTrace}. Never enables a file sink (file sinks would
  # persist partial secrets).
  module Diagnostics

    class << self

      # Lazy Pantheios API object bound to
      # {Pantheios::Services::ColouredConsoleLogService}. Always forces
      # {Pantheios::Core.set_service} so an earlier plain pantheios require
      # cannot leave the default sink in place.
      def console_logger

        return @console_logger if @console_logger

        require 'pantheios/globals'
        require 'pantheios/services/coloured_console_log_service'

        Pantheios::Globals.INITIAL_SERVICE_CLASSES = [
          Pantheios::Services::ColouredConsoleLogService,
        ]

        require 'pantheios'

        Pantheios::Core.set_service(
          Pantheios::Services::ColouredConsoleLogService.new,
        )
        Pantheios::Core.process_name = 'usb-cracker'

        @console_logger = Object.new
        @console_logger.extend ::Pantheios::API
        @console_logger
      end

      # Emit +message+ at +severity+ via the coloured console sink and flush
      # +$stderr+ so a buffered TTY cannot hide operator traces.
      def emit(severity, message, stderr: $stderr)

        console_logger.log(severity, message)
        stderr.flush
      end

      # Always-visible stderr write for operator smoke traces. Pantheios is
      # warmed (coloured console) but not used for the line itself, so a
      # miswired sink cannot hide or double the message.
      def emit_stderr!(message, stderr: $stderr)

        console_logger
        stderr.puts message
        stderr.flush
      end
    end
  end # module Diagnostics
end # module UsbCracker


# ############################## end of file ############################# #
