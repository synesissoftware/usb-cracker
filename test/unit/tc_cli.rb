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

  def test_missing_key_name

    assert_parse_fails([ 'disk2s1' ], /--key-name is required/)
  end

  def test_blank_key_name

    assert_parse_fails([ 'disk2s1', '--key-name', '   ' ], /--key-name is required/)
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
  end

  def test_trace_suffixes_alias

    options = cli_parse([
      'disk2s1',
      '-k', 'office',
      '-T',
    ])

    assert_true options.trace_suffixes?
  end

  def test_no_bruteforce_alias_with_incomplete_bounds_fails

    assert_parse_fails([
      'disk2s1',
      '-k', 'office',
      '-c', 'abc',
      '-n',
    ], /--charset and --max-suffix-len must be supplied together/)
  end
end
