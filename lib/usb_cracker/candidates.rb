# frozen_string_literal: true
# ######################################################################## #
# File:     usb_cracker/candidates.rb
#
# Purpose:  Suffix candidate generation for usb-cracker
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


module UsbCracker

  # Suffix candidate generation. Yields suffix strings only; callers
  # assemble PREFIX+suffix later. This module never sees PREFIX, never logs
  # a passphrase, and never writes candidates to disk.
  #
  # Search order:
  # 1. unique permutations of +options.key_name+ (lexicographic), streamed
  #   one at a time — never materialised as a full array;
  # 2. iff +options.bruteforce?+, bounded brute-force suffixes of length
  #   min..+options.max_suffix_len+ over +options.charset+ (min defaults to
  #   1), skipping strings already produced in (1).
  #
  # +options+ is a {Cli::Options}-like object (+key_name+, +bruteforce?+,
  # +charset+, +min_suffix_len_or_default+, +max_suffix_len+). +key_name+
  # may be +nil+ / empty when only brute-force is enabled.
  #
  # Unique-permutation cost is n! in the length of +key_name+; names are
  # expected to be short. Brute-force is capped by charset and min/max
  # length — never open-ended. The empty suffix is not generated (PREFIX
  # alone is out of scope).
  module Candidates

    class << self

      # Yields each unique suffix in search order. With no block, returns an
      # Enumerator.
      def each(options)

        CallTrace.enter('UsbCracker::Candidates.each')

        return enum_for(:each, options) unless block_given?

        seen = {}

        each_unique_permutation_(options.key_name) do |suffix|

          next if suffix.empty?
          next if seen.key?(suffix)

          seen[suffix] = true
          CallTrace.enter(
            'UsbCracker::Candidates.each/yield',
            "suffix=#{suffix}",
          )
          yield suffix
        end

        if options.bruteforce?

          each_bruteforce_(options) do |suffix|

            next if suffix.empty?
            next if seen.key?(suffix)

            seen[suffix] = true
            CallTrace.enter(
              'UsbCracker::Candidates.each/yield',
              "suffix=#{suffix}",
            )
            yield suffix
          end
        end

        self
      end

      # All unique suffixes in search order, as an Array.
      def enumerate(options)

        CallTrace.enter('UsbCracker::Candidates.enumerate')

        each(options).to_a
      end

      # Exact candidate count without materialising the full list. Informed
      # unique permutations are counted while collecting a small seen-set;
      # brute-force lengths use charset^len minus overlaps.
      def count(options)

        CallTrace.enter('UsbCracker::Candidates.count')

        informed = {}
        total = 0

        each_unique_permutation_(options.key_name) do |suffix|

          next if suffix.empty?
          next if informed.key?(suffix)

          informed[suffix] = true
          total += 1
        end

        if options.bruteforce?

          total += count_bruteforce_(options, informed)
        end

        total
      end

      private
      # Stream unique permutations of +key_name+ in lexicographic order.
      # Empty / nil +key_name+ yields nothing. Does not build an
      # intermediate array of all permutations.
      def each_unique_permutation_(key_name)

        return if key_name.nil? || key_name.empty?

        seen = {}
        key_name.chars.sort.permutation.each do |parts|

          suffix = parts.join
          next if suffix.empty? || seen.key?(suffix)

          seen[suffix] = true
          yield suffix
        end
      end

      # Bounded brute-force over +options.charset+. Character order in the
      # charset defines generation order (first occurrence wins if the
      # charset repeats a character). Lengths are min..max inclusive (min
      # defaults to 1). Empty charset or non-positive max length produce no
      # brute-force suffixes (fail closed).
      def each_bruteforce_(options)

        charset = options.charset
        max_len = options.max_suffix_len
        min_len = bruteforce_min_(options)

        return if charset.nil? || charset.empty?
        return if max_len.nil? || max_len <= 0
        return if min_len.nil? || min_len <= 0
        return if min_len > max_len

        chars = charset.chars.uniq
        return if chars.empty?

        (min_len..max_len).each do |len|

          chars.repeated_permutation(len) do |combo|

            yield combo.join
          end
        end
      end

      def count_bruteforce_(options, informed)

        charset = options.charset
        max_len = options.max_suffix_len
        min_len = bruteforce_min_(options)

        return 0 if charset.nil? || charset.empty?
        return 0 if max_len.nil? || max_len <= 0
        return 0 if min_len.nil? || min_len <= 0
        return 0 if min_len > max_len

        chars = charset.chars.uniq
        return 0 if chars.empty?

        char_set = {}
        chars.each { |c| char_set[c] = true }

        total = 0
        (min_len..max_len).each do |len|

          raw = chars.size ** len
          overlap = informed.keys.count do |suffix|

            suffix.length == len && suffix.each_char.all? { |c| char_set.key?(c) }
          end
          total += raw - overlap
        end

        total
      end

      def bruteforce_min_(options)

        if options.respond_to?(:min_suffix_len_or_default)

          options.min_suffix_len_or_default
        else

          1
        end
      end
    end
  end # module Candidates
end # module UsbCracker


# ############################## end of file ############################# #
