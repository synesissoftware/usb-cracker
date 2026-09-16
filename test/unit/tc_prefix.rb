#! /usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), '../../lib')


require 'usb_cracker/cli'
require 'usb_cracker/prefix'

require 'stringio'
require 'test/unit'


class Test_prefix < Test::Unit::TestCase

  TOKEN = 'unit-test-prefix-token'
  TOKEN_OTHER = 'unit-test-prefix-other'

  def getpass_queue(*values)

    queue = values.map { |v| v.nil? ? nil : String.new(v) }
    @prompts_seen = []

    lambda { |prompt|

      @prompts_seen << prompt
      queue.shift
    }
  end

  def read_prefix(getpass:, **opts)

    @stderr = StringIO.new

    UsbCracker::Prefix.read!(
      abort_exit: nil,
      getpass: getpass,
      stderr: @stderr,
      **opts,
    )
  end

  def assert_usage(pattern)

    e = assert_raise(UsbCracker::Cli::UsageError) { yield }

    assert_match pattern, e.message
    assert_match pattern, @stderr.string
    assert_match(/^usb-cracker: /, @stderr.string)
    refute_includes e.message, TOKEN
    refute_includes e.message, TOKEN_OTHER
    refute_includes @stderr.string, TOKEN
    refute_includes @stderr.string, TOKEN_OTHER
    e
  end


  def test_read_prompts_twice_and_accepts_match

    getpass = getpass_queue(TOKEN, TOKEN)
    buf = read_prefix(getpass: getpass)

    assert_equal [
      UsbCracker::Prefix::DEFAULT_PROMPT,
      UsbCracker::Prefix::DEFAULT_CONFIRM_PROMPT,
    ], @prompts_seen
    assert_equal TOKEN, buf.to_s
  ensure

    buf.wipe if buf
  end

  def test_read_block_form_wipes_on_abort_path

    captured = nil
    stderr = StringIO.new

    assert_raise(SystemExit) do

      UsbCracker::Prefix.read!(getpass: getpass_queue(TOKEN, TOKEN)) do |prefix|

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

      UsbCracker::Prefix.read!(
        abort_exit: nil,
        getpass: getpass_queue(TOKEN, TOKEN),
        stderr: StringIO.new,
      ) do |prefix|

        captured = prefix
        raise UsbCracker::Cli::UsageError, 'prefix must not be empty'
      end
    end

    assert_true captured.wiped?
    assert_true captured.empty?
  end

  def test_mismatch_rejected_without_echoing_secrets

    e = assert_usage(/prefixes do not match/) do

      read_prefix(getpass: getpass_queue(TOKEN, TOKEN_OTHER))
    end

    assert_equal 'prefixes do not match', e.message
    assert_equal 2, @prompts_seen.length
  end

  def test_mismatch_default_abort_exits_without_ruby_backtrace

    stderr = StringIO.new

    assert_raise(SystemExit) do

      UsbCracker::Prefix.read!(
        getpass: getpass_queue(TOKEN, TOKEN_OTHER),
        stderr: stderr,
      )
    end

    assert_equal "usb-cracker: prefixes do not match\n", stderr.string
    refute_includes stderr.string, TOKEN
  end

  def test_blank_confirmation_rejected_as_mismatch

    e = assert_usage(/prefixes do not match/) do

      read_prefix(getpass: getpass_queue(TOKEN, ''))
    end

    assert_equal 'prefixes do not match', e.message
  end

  def test_blank_prefix_rejected_without_confirm_prompt

    e = assert_usage(/prefix must not be empty/) do

      read_prefix(getpass: getpass_queue(''))
    end

    assert_equal 'prefix must not be empty', e.message
    assert_equal [ UsbCracker::Prefix::DEFAULT_PROMPT ], @prompts_seen
  end

  def test_whitespace_prefix_rejected

    e = assert_usage(/prefix must not be empty/) do

      read_prefix(getpass: getpass_queue(" \t\n"))
    end

    assert_equal 'prefix must not be empty', e.message
  end

  def test_nil_prefix_rejected

    e = assert_usage(/prefix must not be empty/) do

      read_prefix(getpass: getpass_queue(nil))
    end

    assert_equal 'prefix must not be empty', e.message
  end

  def test_non_tty_without_getpass_fails_closed

    input = StringIO.new(TOKEN)

    e = assert_usage(/prefix prompt requires a TTY/) do

      UsbCracker::Prefix.read!(
        abort_exit: nil,
        input: input,
        stderr: (@stderr = StringIO.new),
      )
    end

    assert_match(/stdin is not a terminal/, e.message)
    refute_includes e.message, TOKEN
  end

  def test_injected_getpass_does_not_require_tty

    input = StringIO.new
    buf = UsbCracker::Prefix.read!(
      abort_exit: nil,
      getpass: getpass_queue(TOKEN, TOKEN),
      input: input,
      stderr: StringIO.new,
    )

    assert_equal TOKEN, buf.to_s
  ensure

    buf.wipe if buf
  end

  def test_custom_prompts_passed_to_getpass

    buf = read_prefix(
      getpass: getpass_queue(TOKEN, TOKEN),
      prompt: 'Prefix:',
      confirm_prompt: 'Again:',
    )

    assert_equal [ 'Prefix:', 'Again:' ], @prompts_seen
  ensure

    buf.wipe if buf
  end


  def test_match_state_matching_partial

    state = UsbCracker::Prefix.match_state('abcdef', 'abc')

    assert_equal 3, state.matched
    assert_equal 6, state.total
    assert_equal 3, state.typed
    assert_false state.diverged
    assert_true state.matching?
  end

  def test_match_state_full_match

    state = UsbCracker::Prefix.match_state('ab', 'ab')

    assert_equal 2, state.matched
    assert_false state.diverged
  end

  def test_match_state_diverged

    state = UsbCracker::Prefix.match_state('abcdef', 'abX')

    assert_equal 2, state.matched
    assert_true state.diverged
  end

  def test_match_state_too_long_diverges

    state = UsbCracker::Prefix.match_state('ab', 'abc')

    assert_true state.diverged
  end

  def test_format_match_indicator_never_embeds_secret

    first = 'secret-token'
    state = UsbCracker::Prefix.match_state(first, 'secr')
    text = UsbCracker::Prefix.format_match_indicator(state)

    assert_equal '[####--------] 4/12 matching', text
    refute_includes text, 'secret'
    refute_includes text, 'token'
  end

  def test_format_match_indicator_diverge

    text = UsbCracker::Prefix.format_match_indicator(
      UsbCracker::Prefix.match_state('abcd', 'abX'),
    )

    assert_equal '[##!-] 2/4 diverge', text
  end
end
