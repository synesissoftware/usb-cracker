# frozen_string_literal: true
# ######################################################################## #
# File:     usb_cracker/secret_buffer.rb
#
# Purpose:  Mutable in-memory holder for PREFIX (best-effort wipe)
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

module UsbCracker

  # Mutable holder for PREFIX bytes. Copies +content+ into an unfrozen
  # buffer and best-effort wipes the source string when it is mutable.
  #
  # {#to_s} returns the live unfrozen buffer (not a frozen/interned copy).
  # Callers must not freeze that string. {#dup} / {#clone} copy into a new
  # holder. {#inspect} never includes the secret.
  #
  # This is best-effort hygiene, not a guarantee against swapping, core
  # dumps, or copies the runtime already made.
  class SecretBuffer

    class << self

      # Overwrite +string+ with NULs and {String#clear}. Frozen or +nil+
      # strings are left unchanged (interned literals cannot be wiped).
      def wipe_string!(string)

        return string if string.nil? || string.frozen?

        begin

          n = string.bytesize
          string.force_encoding Encoding::BINARY
          i = 0
          while i < n

            string.setbyte(i, 0)
            i += 1
          end
          string.clear
        rescue StandardError

          begin

            string.clear
          rescue StandardError

            nil
          end
        end

        string
      end
    end

    def initialize(content)

      unless content.is_a?(String)

        raise ArgumentError, 'content must be a String'
      end

      @buffer = String.new(content)
      @wiped = false
      self.class.wipe_string!(content)
    end

    # Live unfrozen buffer, or an empty unfrozen string after {#wipe}.
    def to_s

      return String.new if @wiped || @buffer.nil?

      @buffer
    end

    def empty?

      @wiped || @buffer.nil? || @buffer.empty?
    end

    def wiped?

      @wiped
    end

    # Overwrite then release. Idempotent. Returns +self+.
    def wipe

      self.class.wipe_string!(@buffer)
      @buffer = String.new
      @wiped = true

      self
    end

    alias_method :clear!, :wipe

    def inspect

      if @wiped || @buffer.nil?

        '#<UsbCracker::SecretBuffer wiped>'
      else

        "#<UsbCracker::SecretBuffer bytesize=#{@buffer.bytesize}>"
      end
    end

    def pretty_inspect

      inspect
    end

    def pretty_print(q)

      q.text inspect
    end

    def marshal_dump

      raise TypeError, 'UsbCracker::SecretBuffer cannot be dumped'
    end

    def marshal_load(_data)

      raise TypeError, 'UsbCracker::SecretBuffer cannot be dumped'
    end

    private
    def initialize_copy(other)

      @wiped = other.wiped?
      @buffer = other.send(:copy_contents_)
    end

    def copy_contents_

      return String.new if @wiped || @buffer.nil?

      String.new(@buffer)
    end
  end # class SecretBuffer
end # module UsbCracker


# ############################## end of file ############################# #
