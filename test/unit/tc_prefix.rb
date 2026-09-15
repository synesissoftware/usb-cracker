#! /usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), '../../lib')


require 'usb_cracker/cli'
require 'usb_cracker/prefix'

require 'stringio'
require 'test/unit'


class Test_prefix < Test::Unit::TestCase

  TOKEN = 'unit-test-prefix-token'

  def read_prefix(getpass:, **opts)

    UsbCracker::Prefix.read!(getpass: getpass, **opts)
  end

  def assert_usage(pattern)

    e = assert_raise(UsbCracker::Cli::UsageError) { yield }

    assert_match pattern, e.message
    refute_includes e.message, TOKEN
    e
  end


  def test_read_uses_injected_getpass_once

    calls = 0
    src = String.new(TOKEN)
    getpass = lambda { |prompt|

      calls += 1
      assert_equal UsbCracker::Prefix::DEFAULT_PROMPT, prompt
      src
    }

    buf = read_prefix(getpass: getpass)

    assert_equal 1, calls
    assert_equal TOKEN, buf.to_s
    assert_true src.empty?
  ensure

    buf.wipe if buf
  end

  def test_read_block_form_wipes_on_abort_path

    captured = nil
    stderr = StringIO.new

    assert_raise(SystemExit) do

      UsbCracker::Prefix.read!(getpass: lambda { |_| String.new(TOKEN) }) do |prefix|

        captured = prefix
        UsbCracker::Cli.abort 'search and unlock are not implemented in this scaffold release', stderr: stderr
      end
    end

    assert captured
    assert_true captured.wiped?
    assert_true captured.empty?
    refute_includes captured.to_s, TOKEN
    refute_includes stderr.string, TOKEN
    assert_match(/search and unlock are not implemented/, stderr.string)
  end

  def test_read_block_form_wipes_on_usage_error

    captured = nil

    assert_raise(UsbCracker::Cli::UsageError) do

      UsbCracker::Prefix.read!(getpass: lambda { |_| String.new(TOKEN) }) do |prefix|

        captured = prefix
        raise UsbCracker::Cli::UsageError, 'prefix must not be empty'
      end
    end

    assert_true captured.wiped?
    assert_true captured.empty?
  end

  def test_blank_prefix_rejected

    e = assert_usage(/prefix must not be empty/) do

      read_prefix(getpass: lambda { |_| String.new('') })
    end

    assert_equal 'prefix must not be empty', e.message
  end

  def test_whitespace_prefix_rejected

    e = assert_usage(/prefix must not be empty/) do

      read_prefix(getpass: lambda { |_| String.new(" \t\n") })
    end

    assert_equal 'prefix must not be empty', e.message
  end

  def test_nil_prefix_rejected

    e = assert_usage(/prefix must not be empty/) do

      read_prefix(getpass: lambda { |_| nil })
    end

    assert_equal 'prefix must not be empty', e.message
  end

  def test_non_tty_without_getpass_fails_closed

    input = StringIO.new(TOKEN)

    e = assert_usage(/prefix prompt requires a TTY/) do

      UsbCracker::Prefix.read!(input: input)
    end

    assert_match(/stdin is not a terminal/, e.message)
    refute_includes e.message, TOKEN
  end

  def test_injected_getpass_does_not_require_tty

    input = StringIO.new
    buf = UsbCracker::Prefix.read!(
      getpass: lambda { |_| String.new(TOKEN) },
      input: input,
    )

    assert_equal TOKEN, buf.to_s
  ensure

    buf.wipe if buf
  end

  def test_custom_prompt_passed_to_getpass

    seen = nil
    buf = read_prefix(
      getpass: lambda { |prompt|

        seen = prompt
        String.new(TOKEN)
      },
      prompt: 'Prefix:',
    )

    assert_equal 'Prefix:', seen
  ensure

    buf.wipe if buf
  end
end
