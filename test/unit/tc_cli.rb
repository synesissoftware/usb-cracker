#! /usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), '../../lib')


require 'usb_cracker/cli'

require 'stringio'
require 'test/unit'


class Test_cli < Test::Unit::TestCase

  def cli_parse(argv)

    @stdout = StringIO.new
    @stderr = StringIO.new

    UsbCracker::Cli.parse(
      argv,
      abort_exit: nil,
      exit_on_missing: false,
      exit_on_unknown: false,
      exit_on_usage: false,
      program_name: 'usb-cracker',
      stderr: @stderr,
      stdout: @stdout,
    )
  end

  def assert_parse_fails(argv, pattern)

    e = assert_raise(UsbCracker::Cli::UsageError) { cli_parse(argv) }

    assert_match pattern, e.message
    assert_match pattern, @stderr.string
  end


  def test_happy_path_volume_and_key_name

    options = cli_parse([ 'disk2s1', '--key-name', 'office' ])

    assert_equal 'disk2s1', options.volume
    assert_equal 'office', options.key_name
    assert_nil options.charset
    assert_nil options.max_suffix_len
    assert_false options.no_bruteforce?
    assert_false options.bruteforce?
    assert_false options.trace_calls?
    assert_false options.trace_suffixes?
  end

  def test_happy_path_key_name_alias

    options = cli_parse([ 'disk2s1', '-k', 'office' ])

    assert_equal 'disk2s1', options.volume
    assert_equal 'office', options.key_name
    assert_false options.bruteforce?
  end

  def test_happy_path_strips_volume_and_key_name

    options = cli_parse([ '  disk2s1  ', '--key-name', '  office  ' ])

    assert_equal 'disk2s1', options.volume
    assert_equal 'office', options.key_name
  end

  def test_happy_path_bounded_bruteforce

    options = cli_parse([
      'disk2s1',
      '--key-name', 'office',
      '--charset', 'abc',
      '--max-suffix-len', '2',
    ])

    assert_equal 'abc', options.charset
    assert_equal 2, options.max_suffix_len
    assert_false options.no_bruteforce?
    assert_true options.bruteforce?
  end

  def test_missing_key_name_and_bruteforce_fails

    assert_parse_fails(
      [ 'disk2s1' ],
      /provide --key-name and\/or --charset with --max-suffix-len/,
    )
  end

  def test_blank_key_name

    assert_parse_fails(
      [ 'disk2s1', '--key-name', '   ' ],
      /--key-name must be a non-empty string when supplied/,
    )
  end

  def test_bruteforce_only_without_key_name

    options = cli_parse([
      'disk2s1',
      '--charset', 'abc',
      '--max-suffix-len', '2',
    ])

    assert_nil options.key_name
    assert_false options.informed?
    assert_true options.bruteforce?
    assert_equal 'abc', options.charset
    assert_equal 2, options.max_suffix_len
  end

  def test_no_bruteforce_without_key_name_fails

    assert_parse_fails([
      'disk2s1',
      '--charset', 'abc',
      '--max-suffix-len', '2',
      '--no-bruteforce',
    ], /provide --key-name and\/or --charset with --max-suffix-len/)
  end

  def test_confirm_key_name_skips_short_names

    options = cli_parse([ 'disk2s1', '--key-name', 'abcde' ])

    UsbCracker::Cli.confirm_key_name!(
      options,
      abort_exit: nil,
      confirm: -> { flunk 'should not prompt for short key-name' },
      stderr: @stderr,
    )
  end

  def test_confirm_key_name_warns_and_accepts

    options = cli_parse([ 'disk2s1', '--key-name', 'abcdefg' ])
    stderr = StringIO.new

    result = UsbCracker::Cli.confirm_key_name!(
      options,
      abort_exit: nil,
      confirm: -> { 'y' },
      stderr: stderr,
    )

    assert_equal options, result
    assert_match(/warning: --key-name is 7 characters/, stderr.string)
    assert_match(/continue\? \[y\/N\]/, stderr.string)
  end

  def test_confirm_key_name_rejects_non_yes

    options = cli_parse([ 'disk2s1', '--key-name', 'abcdefg' ])
    stderr = StringIO.new

    e = assert_raise(UsbCracker::Cli::UsageError) do

      UsbCracker::Cli.confirm_key_name!(
        options,
        abort_exit: nil,
        confirm: -> { 'n' },
        stderr: stderr,
      )
    end

    assert_match(/cancelled: long --key-name not confirmed/, e.message)
    assert_match(/cancelled: long --key-name not confirmed/, stderr.string)
  end

  def test_missing_volume

    e = assert_raise(UsbCracker::Cli::UsageError) { cli_parse([ '--key-name', 'office' ]) }

    assert_match(/volume must be a non-empty value/, e.message)
    assert_match(/volume (must be a non-empty value|not specified)/, @stderr.string)
  end

  def test_missing_volume_climate_abort

    stdout = StringIO.new
    stderr = StringIO.new

    assert_raise(SystemExit) do

      UsbCracker::Cli.parse(
        [ '--key-name', 'office' ],
        program_name: 'usb-cracker',
        stderr: stderr,
        stdout: stdout,
      )
    end

    assert_match(/volume not specified/, stderr.string)
  end

  def test_blank_volume

    assert_parse_fails([ '   ', '--key-name', 'office' ], /volume must be a non-empty value/)
  end

  def test_invalid_max_suffix_len_zero

    assert_parse_fails([
      'disk2s1',
      '--key-name', 'office',
      '--charset', 'abc',
      '--max-suffix-len', '0',
    ], /--max-suffix-len must be an integer greater than 0/)
  end

  def test_invalid_max_suffix_len_negative

    assert_parse_fails([
      'disk2s1',
      '--key-name', 'office',
      '--charset', 'abc',
      '--max-suffix-len=-1',
    ], /--max-suffix-len must be an integer greater than 0/)
  end

  def test_invalid_max_suffix_len_non_integer

    assert_parse_fails([
      'disk2s1',
      '--key-name', 'office',
      '--charset', 'abc',
      '--max-suffix-len', 'two',
    ], /--max-suffix-len must be an integer greater than 0/)
  end

  def test_empty_charset

    assert_parse_fails([
      'disk2s1',
      '--key-name', 'office',
      '--charset', '',
      '--max-suffix-len', '2',
    ], /--charset must be a non-empty string/)
  end

  def test_charset_without_max_suffix_len

    assert_parse_fails([
      'disk2s1',
      '--key-name', 'office',
      '--charset', 'abc',
    ], /--charset and --max-suffix-len must be supplied together/)
  end

  def test_max_suffix_len_without_charset

    assert_parse_fails([
      'disk2s1',
      '--key-name', 'office',
      '--max-suffix-len', '2',
    ], /--charset and --max-suffix-len must be supplied together/)
  end

  def test_no_bruteforce_without_bounds

    options = cli_parse([
      'disk2s1',
      '--key-name', 'office',
      '--no-bruteforce',
    ])

    assert_true options.no_bruteforce?
    assert_false options.bruteforce?
    assert_nil options.charset
    assert_nil options.max_suffix_len
  end

  def test_no_bruteforce_with_both_bounds

    options = cli_parse([
      'disk2s1',
      '--key-name', 'office',
      '--charset', 'abc',
      '--max-suffix-len', '2',
      '--no-bruteforce',
    ])

    assert_true options.no_bruteforce?
    assert_false options.bruteforce?
    assert_equal 'abc', options.charset
    assert_equal 2, options.max_suffix_len
  end

  def test_trace_suffixes_flag

    options = cli_parse([
      'disk2s1',
      '--key-name', 'office',
      '--trace-suffixes',
    ])

    assert_true options.trace_suffixes?
    assert_false options.trace_calls?
  end

  def test_trace_suffixes_alias

    options = cli_parse([
      'disk2s1',
      '-k', 'office',
      '--T',
    ])

    assert_true options.trace_suffixes?
  end

  def test_trace_calls_flag

    begin

      UsbCracker::CallTrace.disable!

      options = cli_parse([
        'disk2s1',
        '--key-name', 'office',
        '--trace-calls',
      ])

      assert_true options.trace_calls?
      assert_true UsbCracker::CallTrace.enabled?
      assert_false options.trace_suffixes?
    ensure

      UsbCracker::CallTrace.disable!
    end
  end

  def test_no_bruteforce_alias_with_incomplete_bounds_fails

    assert_parse_fails([
      'disk2s1',
      '-k', 'office',
      '-c', 'abc',
      '-B',
    ], /--charset and --max-suffix-len must be supplied together/)
  end

  def test_min_suffix_len_with_charset_bounds

    options = cli_parse([
      'disk2s1',
      '--charset', 'abc',
      '--min-suffix-len', '2',
      '--max-suffix-len', '3',
    ])

    assert_equal 2, options.min_suffix_len
    assert_equal 3, options.max_suffix_len
    assert_equal 2, options.min_suffix_len_or_default
    assert_true options.bruteforce?
  end

  def test_min_suffix_len_without_bounds_fails

    assert_parse_fails([
      'disk2s1',
      '--key-name', 'office',
      '--min-suffix-len', '2',
    ], /--min-suffix-len requires --charset and --max-suffix-len/)
  end

  def test_min_suffix_len_greater_than_max_fails

    assert_parse_fails([
      'disk2s1',
      '--charset', 'abc',
      '--min-suffix-len', '3',
      '--max-suffix-len', '2',
    ], /--min-suffix-len must be less than or equal to --max-suffix-len/)
  end

  def test_mid_section_literal

    options = cli_parse([
      'disk2s1',
      '--key-name', 'office',
      '--mid-section-literal=-x-',
    ])

    assert_equal '-x-', options.mid_section_literal
    assert_equal '-x-', options.mid
    assert_equal '-x-ab', options.display_suffix('ab')
  end

  def test_mid_section_literal_separate_value

    options = cli_parse([
      'disk2s1',
      '--key-name', 'office',
      '--mid-section-literal', '::',
    ])

    assert_equal '::', options.mid_section_literal
    assert_equal '::ab', options.display_suffix('ab')
  end
end
