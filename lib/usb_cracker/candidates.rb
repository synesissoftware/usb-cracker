# frozen_string_literal: true
# ######################################################################## #
# File:     usb_cracker/candidates.rb
#
# Purpose:  Suffix candidate generation for usb-cracker
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

  # Suffix candidate generation. Yields suffix strings only; callers
  # assemble PREFIX+suffix later. This module never sees PREFIX, never logs
  # a passphrase, and never writes candidates to disk.
  #
  # Search order:
  # 1. unique permutations of +options.key_name+ (lexicographic);
  # 2. iff +options.bruteforce?+, bounded brute-force suffixes of length
  # 1..+options.max_suffix_len+ over +options.charset+, skipping strings
  # already produced in (1).
  #
  # +options+ is a {Cli::Options}-like object (+key_name+, +bruteforce?+,
  # +charset+, +max_suffix_len+).
  #
  # Unique-permutation cost is n! in the length of +key_name+; names are
  # expected to be short. Brute-force is capped by charset and max length —
  # never open-ended. The empty suffix is not generated (PREFIX alone is out
  # of scope).
  module Candidates

    class << self

      # Yields each unique suffix in search order. With no block, returns an
      # Enumerator.
      def each(options)

        return enum_for(:each, options) unless block_given?

        seen = {}

        unique_permutations_(options.key_name).each do |suffix|

          next if suffix.empty?
          next if seen.key?(suffix)

          seen[suffix] = true
          yield suffix
        end

        if options.bruteforce?

          each_bruteforce_(options) do |suffix|

            next if suffix.empty?
            next if seen.key?(suffix)

            seen[suffix] = true
            yield suffix
          end
        end

        self
      end

      # All unique suffixes in search order, as an Array.
      def enumerate(options)

        each(options).to_a
      end

      private
      # Unique permutations of +key_name+ in lexicographic order. Empty /
      # nil +key_name+ yields no permutations (Cli rejects blanks; this is a
      # direct-call guard).
      def unique_permutations_(key_name)

        return [] if key_name.nil? || key_name.empty?

        key_name.chars.permutation.map(&:join).sort.uniq
      end

      # Bounded brute-force over +options.charset+. Character order in the
      # charset defines generation order (first occurrence wins if the
      # charset repeats a character). Lengths are 1..max_suffix_len
      # inclusive. Empty charset or non-positive max length produce no
      # brute-force suffixes (fail closed).
      def each_bruteforce_(options)

        charset = options.charset
        max_len = options.max_suffix_len

        return if charset.nil? || charset.empty?
        return if max_len.nil? || max_len <= 0

        chars = charset.chars.uniq
        return if chars.empty?

        (1..max_len).each do |len|

          chars.repeated_permutation(len) do |combo|

            yield combo.join
          end
        end
      end
    end
  end # module Candidates
end # module UsbCracker


# ############################## end of file ############################# #
