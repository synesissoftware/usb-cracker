# frozen_string_literal: true
# ######################################################################## #
# File:     usb_cracker/version.rb
#
# Purpose:  Version for usb-cracker
#
# Created:  9th September 2026
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

module UsbCracker

  # Current version of the usb-cracker gem
  VERSION           = '0.0.9'

  private
  # @!visibility private
  VERSION_PARTS_    = VERSION.split(/[.]/).collect { |n| n.to_i } # :nodoc:
  public
  # Major version of the usb-cracker gem
  VERSION_MAJOR     = VERSION_PARTS_[0] # :nodoc:
  # Minor version of the usb-cracker gem
  VERSION_MINOR     = VERSION_PARTS_[1] # :nodoc:
  # Revision version of the usb-cracker gem
  VERSION_REVISION  = VERSION_PARTS_[2] # :nodoc:
end # module UsbCracker


# ############################## end of file ############################# #
