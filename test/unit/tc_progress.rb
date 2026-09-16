#! /usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), '../../lib')


require 'usb_cracker/cli'
require 'usb_cracker/progress'

require 'stringio'
require 'test/unit'


class Test_progress < Test::Unit::TestCase

  def strip_ansi(text)

    text.gsub(/\e\[[0-9;]*m/, '')
  end

  def test_format_eta_omits_leading_zero_units

    assert_equal '5s', UsbCracker::Progress.format_eta(5)
    assert_equal '2m 3s', UsbCracker::Progress.format_eta(123)
    assert_equal '1h 2m 3s', UsbCracker::Progress.format_eta(3723)
    assert_equal '1h 0m 0s', UsbCracker::Progress.format_eta(3600)
    assert_equal '0s', UsbCracker::Progress.format_eta(0)
  end

  def test_meter_tick_rewrites_line_with_counts

    stderr = StringIO.new
    meter = UsbCracker::Progress::Meter.new(
      force: true,
      stderr: stderr,
      total: 10,
    )

    meter.tick(3, 'ba')
    plain = strip_ansi(stderr.string)

    assert_match(/Attempting /, plain)
    assert_match(/ 3\/10 /, plain)
    assert_match(/#/, plain)
    assert_match(/"ba"  /, plain)
    refute_match(/ETA /, plain)
    refute_includes plain, "\n"
  end

  def test_meter_tick_colours_label_bar_counts_and_suffix

    stderr = StringIO.new
    meter = UsbCracker::Progress::Meter.new(
      force: true,
      stderr: stderr,
      total: 10,
    )

    meter.tick(3, 'ba')
    raw = stderr.string

    blue = UsbCracker::Progress::CLR_BLUE
    cyan = UsbCracker::Progress::CLR_CYAN
    green = UsbCracker::Progress::CLR_GREEN
    reset = UsbCracker::Progress::CLR_RESET

    assert_includes raw, "#{blue}Attempting #{reset}"
    assert_includes raw, "#{cyan}#"
    assert_includes raw, "#{blue} 3/10 #{reset}"
    assert_includes raw, "\"#{green}ba#{reset}\"  "
  end

  def test_meter_eta_after_first_completed_attempt

    times = [ 100.0, 110.0, 120.0 ]
    clock = -> { times.shift || 120.0 }
    stderr = StringIO.new
    meter = UsbCracker::Progress::Meter.new(
      clock: clock,
      force: true,
      stderr: stderr,
      total: 10,
    )

    meter.tick(1, 'aa')
    assert_equal false, strip_ansi(stderr.string).include?('ETA ')

    stderr.truncate(0)
    stderr.rewind
    meter.tick(2, 'ab')
    plain = strip_ansi(stderr.string)

    # 10s for 1 completed → mean 10s; remaining 9 (incl. current) → 90s
    assert_match(/"ab"  ETA 1m 30s/, plain)
  end

  def test_meter_finish_omits_eta

    times = [ 100.0, 110.0, 120.0 ]
    clock = -> { times.shift || 120.0 }
    stderr = StringIO.new
    meter = UsbCracker::Progress::Meter.new(
      clock: clock,
      force: true,
      stderr: stderr,
      total: 4,
    )

    meter.tick(1)
    meter.tick(2)
    meter.finish(success: true)

    finished = strip_ansi(stderr.string.split("\r").last)
    assert_includes finished, '✔︎'
    refute_match(/ETA /, finished)
    assert_match(/\n\z/, stderr.string)
  end

  def test_meter_finish_success_advances_line

    stderr = StringIO.new
    meter = UsbCracker::Progress::Meter.new(
      force: true,
      stderr: stderr,
      total: 4,
    )

    meter.tick(2)
    meter.finish(success: true)

    assert_includes stderr.string, '✔︎'
    assert_match(/\n\z/, stderr.string)
  end

  def test_meter_for_nil_when_tracing_suffixes

    options = UsbCracker::Cli::Options.new(
      charset: nil,
      key_name: 'ab',
      max_suffix_len: nil,
      mid_section_literal: nil,
      min_suffix_len: nil,
      no_bruteforce: false,
      trace_calls: false,
      trace_suffixes: true,
      volume: 'disk2s1',
    )

    assert_nil UsbCracker::Progress.meter_for(options, force: true, total: 2)
  end

  def test_meter_disabled_without_tty_unless_forced

    stderr = StringIO.new
    meter = UsbCracker::Progress::Meter.new(
      stderr: stderr,
      total: 2,
    )

    assert_false meter.enabled?
    meter.tick(1)
    assert_equal '', stderr.string
  end
end
