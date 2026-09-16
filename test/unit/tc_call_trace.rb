#! /usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), '../../lib')


require 'usb_cracker/call_trace'
require 'usb_cracker/cli'
require 'usb_cracker/diagnostics'

require 'stringio'
require 'test/unit'


class Test_call_trace < Test::Unit::TestCase

  def setup

    UsbCracker::CallTrace.disable!
  end

  def teardown

    UsbCracker::CallTrace.disable!
  end


  def test_enter_is_noop_when_disabled

    UsbCracker::CallTrace.enter('UsbCracker::Never')

    assert_false UsbCracker::CallTrace.enabled?
  end

  def test_enter_logs_at_info_when_enabled

    logger = Object.new
    def logger.log(severity, message)

      @calls ||= []
      @calls << [ severity, message ]
    end
    def logger.calls

      @calls || []
    end

    prev_stderr = $stderr
    $stderr = StringIO.new
    UsbCracker::Diagnostics.instance_variable_set(:@console_logger, logger)
    begin

      UsbCracker::CallTrace.enable!
      UsbCracker::CallTrace.enter('UsbCracker::Example.method', 'volume=disk2s1')
    ensure

      UsbCracker::Diagnostics.instance_variable_set(:@console_logger, nil)
      $stderr = prev_stderr
    end

    assert_equal 1, logger.calls.size
    severity, message = logger.calls[0]
    assert_equal :info, severity
    assert_equal 'enter UsbCracker::Example.method volume=disk2s1', message
  end

  def test_parse_enables_trace_calls

    options = UsbCracker::Cli.parse(
      [ 'disk2s1', '--key-name', 'ab', '--trace-calls' ],
      abort_exit: nil,
      exit_on_missing: false,
      exit_on_unknown: false,
      exit_on_usage: false,
      stderr: StringIO.new,
      stdout: StringIO.new,
    )

    assert_true options.trace_calls?
    assert_true UsbCracker::CallTrace.enabled?
  ensure

    UsbCracker::CallTrace.disable!
  end
end
