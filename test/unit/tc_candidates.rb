#! /usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), '../../lib')


require 'usb_cracker/candidates'
require 'usb_cracker/cli'

require 'test/unit'


class Test_candidates < Test::Unit::TestCase

  def options(**kwargs)

    UsbCracker::Cli::Options.new(
      charset: nil,
      key_name: 'ab',
      max_suffix_len: nil,
      no_bruteforce: false,
      volume: 'disk2s1',
      **kwargs,
    )
  end


  def test_permutations_of_two_distinct_letters

    suffixes = UsbCracker::Candidates.enumerate(options(key_name: 'ab'))

    assert_equal [ 'ab', 'ba' ], suffixes
  end

  def test_permutations_are_lexicographic

    suffixes = UsbCracker::Candidates.enumerate(options(key_name: 'ba'))

    assert_equal [ 'ab', 'ba' ], suffixes
  end

  def test_permutations_unique_for_repeated_letters

    suffixes = UsbCracker::Candidates.enumerate(options(key_name: 'aab'))

    assert_equal [ 'aab', 'aba', 'baa' ], suffixes
  end

  def test_single_character_key_name

    suffixes = UsbCracker::Candidates.enumerate(options(key_name: 'x'))

    assert_equal [ 'x' ], suffixes
  end

  def test_empty_key_name_yields_no_informed_suffixes

    suffixes = UsbCracker::Candidates.enumerate(options(key_name: ''))

    assert_equal [], suffixes
  end

  def test_nil_key_name_yields_no_informed_suffixes

    suffixes = UsbCracker::Candidates.enumerate(options(key_name: nil))

    assert_equal [], suffixes
  end

  def test_bruteforce_false_yields_permutations_only

    suffixes = UsbCracker::Candidates.enumerate(options(
      charset: 'ab',
      key_name: 'ab',
      max_suffix_len: 2,
      no_bruteforce: true,
    ))

    assert_equal [ 'ab', 'ba' ], suffixes
  end

  def test_bruteforce_false_when_bounds_omitted

    suffixes = UsbCracker::Candidates.enumerate(options(key_name: 'ab'))

    assert_equal [ 'ab', 'ba' ], suffixes
  end

  def test_bruteforce_appended_after_all_permutations

    suffixes = UsbCracker::Candidates.enumerate(options(
      charset: 'ab',
      key_name: 'ab',
      max_suffix_len: 2,
    ))

    assert_equal [ 'ab', 'ba', 'a', 'b', 'aa', 'bb' ], suffixes
  end

  def test_bruteforce_excludes_permutation_duplicates

    suffixes = UsbCracker::Candidates.enumerate(options(
      charset: 'ab',
      key_name: 'a',
      max_suffix_len: 1,
    ))

    assert_equal [ 'a', 'b' ], suffixes
  end

  def test_bruteforce_charset_order_not_lexicographic

    suffixes = UsbCracker::Candidates.enumerate(options(
      charset: 'ba',
      key_name: 'z',
      max_suffix_len: 2,
    ))

    assert_equal [ 'z', 'b', 'a', 'bb', 'ba', 'ab', 'aa' ], suffixes
  end

  def test_bruteforce_does_not_yield_empty_suffix

    suffixes = UsbCracker::Candidates.enumerate(options(
      charset: 'a',
      key_name: 'x',
      max_suffix_len: 1,
    ))

    assert_equal [ 'x', 'a' ], suffixes
    assert_false suffixes.include?('')
  end

  def test_bruteforce_duplicate_charset_characters_skipped

    suffixes = UsbCracker::Candidates.enumerate(options(
      charset: 'aab',
      key_name: 'x',
      max_suffix_len: 1,
    ))

    assert_equal [ 'x', 'a', 'b' ], suffixes
  end

  def test_bruteforce_empty_charset_yields_no_brute_suffixes

    suffixes = UsbCracker::Candidates.enumerate(options(
      charset: '',
      key_name: 'ab',
      max_suffix_len: 2,
    ))

    assert_equal [ 'ab', 'ba' ], suffixes
  end

  def test_bruteforce_non_positive_max_suffix_len_yields_no_brute_suffixes

    suffixes = UsbCracker::Candidates.enumerate(options(
      charset: 'xy',
      key_name: 'ab',
      max_suffix_len: 0,
    ))

    assert_equal [ 'ab', 'ba' ], suffixes
  end

  def test_bruteforce_negative_max_suffix_len_yields_no_brute_suffixes

    suffixes = UsbCracker::Candidates.enumerate(options(
      charset: 'xy',
      key_name: 'ab',
      max_suffix_len: -1,
    ))

    assert_equal [ 'ab', 'ba' ], suffixes
  end

  def test_empty_key_name_with_bruteforce_yields_brute_only

    suffixes = UsbCracker::Candidates.enumerate(options(
      charset: 'ab',
      key_name: '',
      max_suffix_len: 1,
    ))

    assert_equal [ 'a', 'b' ], suffixes
  end

  def test_nil_key_name_with_bruteforce_yields_brute_only

    suffixes = UsbCracker::Candidates.enumerate(options(
      charset: 'ab',
      key_name: nil,
      max_suffix_len: 1,
    ))

    assert_equal [ 'a', 'b' ], suffixes
  end

  def test_permutations_stream_first_before_exhausting

    yielded = []

    UsbCracker::Candidates.each(options(key_name: 'abc')) do |suffix|

      yielded << suffix
      break if yielded.size == 1
    end

    assert_equal [ 'abc' ], yielded
  end

  def test_each_without_block_returns_enumerator

    enum = UsbCracker::Candidates.each(options(key_name: 'ab'))

    assert_kind_of Enumerator, enum
    assert_equal [ 'ab', 'ba' ], enum.to_a
  end

  def test_each_with_block_yields_in_order

    yielded = []

    result = UsbCracker::Candidates.each(options(key_name: 'ab')) do |suffix|

      yielded << suffix
    end

    assert_equal [ 'ab', 'ba' ], yielded
    assert_equal UsbCracker::Candidates, result
  end

  def test_enumerate_matches_each_to_a

    opts = options(
      charset: 'ab',
      key_name: 'ab',
      max_suffix_len: 2,
    )

    assert_equal UsbCracker::Candidates.each(opts).to_a, UsbCracker::Candidates.enumerate(opts)
  end

  def test_count_matches_enumerate_size

    opts = options(
      charset: 'ab',
      key_name: 'ab',
      max_suffix_len: 2,
    )

    assert_equal UsbCracker::Candidates.enumerate(opts).size, UsbCracker::Candidates.count(opts)
  end

  def test_count_respects_min_suffix_len

    opts = options(
      charset: 'ab',
      key_name: nil,
      max_suffix_len: 2,
      min_suffix_len: 2,
    )

    assert_equal [ 'aa', 'ab', 'ba', 'bb' ], UsbCracker::Candidates.enumerate(opts)
    assert_equal 4, UsbCracker::Candidates.count(opts)
  end
end
