#! /usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), '../../lib')


require 'usb_cracker/cli'
require 'usb_cracker/diskutil'
require 'usb_cracker/search'
require 'usb_cracker/secret_buffer'
require 'usb_cracker/unlock'

require 'stringio'
require 'test/unit'


class Test_search < Test::Unit::TestCase

  PREFIX = 'unit-test-prefix-token'
  VOLUME = 'disk2s1'

  def options(**kwargs)

    UsbCracker::Cli::Options.new(
      charset: nil,
      key_name: 'ab',
      max_suffix_len: nil,
      no_bruteforce: false,
      trace_calls: false,
      trace_suffixes: false,
      volume: VOLUME,
      **kwargs,
    )
  end

  def prefix_buffer

    UsbCracker::SecretBuffer.new(String.new(PREFIX))
  end

  def unlock_result(status, detail: nil, engine: :apfs, exitstatus: 1)

    UsbCracker::Unlock::Result.new(
      detail: detail || UsbCracker::Unlock::DETAIL.fetch(status),
      engine: engine,
      exitstatus: exitstatus,
      status: status,
    )
  end

  def scripted_unlock(statuses)

    calls = []
    idx = 0
    unlock = lambda { |**kwargs|

      calls << kwargs
      status = statuses[idx] || :auth_failed
      idx += 1
      unlock_result(status)
    }

    [ unlock, calls ]
  end

  def recording_log

    entries = []
    log = lambda { |index, suffix, result|

      entries << {
        index: index,
        result: result,
        suffix: suffix,
      }
    }

    [ log, entries ]
  end

  def run_search(opts, prefix, **kwargs)

    kwargs[:progress] = nil unless kwargs.key?(:progress)

    UsbCracker::Search.run(opts, prefix, **kwargs)
  end

  def assert_hides_prefix(*texts)

    texts.each do |text|

      next if text.nil?

      refute_includes text.to_s, PREFIX
    end
  end

  def assert_failure(outcome, kind, pattern)

    refute_predicate outcome, :success?
    assert_equal kind, outcome.kind
    assert_equal 1, outcome.exit_status
    assert_nil outcome.suffix
    assert_match pattern, outcome.message
  end

  def assert_failure_context(outcome, index:, suffix:)

    assert_match(/attempt=#{index}/, outcome.message)
    assert_match(/volume=#{VOLUME}/, outcome.message)
    assert_match(/engine=/, outcome.message)
    assert_match(
      /passphrase=#{Regexp.escape(UsbCracker::Search::PREFIX_MASK)}#{Regexp.escape(suffix)}/,
      outcome.message,
    )
    refute_includes outcome.message, PREFIX
    assert_hides_prefix outcome.message, outcome.inspect
  end


  def test_success_on_first_suffix

    prefix = prefix_buffer
    unlock, calls = scripted_unlock([ :success ])

    outcome = run_search(options, prefix, unlock: unlock)

    assert_predicate outcome, :success?
    assert_equal :success, outcome.kind
    assert_equal 0, outcome.exit_status
    assert_equal 'ab', outcome.suffix
    assert_nil outcome.message
    assert_equal 1, calls.size
    assert_equal 'ab', calls[0][:suffix]
    assert_same prefix, calls[0][:prefix]
    assert_equal VOLUME, calls[0][:volume]
    assert_hides_prefix outcome.inspect
  ensure

    prefix.wipe if prefix
  end

  def test_success_on_nth_suffix_after_auth_failed

    prefix = prefix_buffer
    unlock, calls = scripted_unlock([ :auth_failed, :success ])

    outcome = run_search(options, prefix, unlock: unlock)

    assert_predicate outcome, :success?
    assert_equal 'ba', outcome.suffix
    assert_equal 2, calls.size
    assert_equal [ 'ab', 'ba' ], calls.map { |c| c[:suffix] }
  ensure

    prefix.wipe if prefix
  end

  def test_exhaustion_when_all_auth_failed

    prefix = prefix_buffer
    unlock, calls = scripted_unlock([ :auth_failed, :auth_failed ])

    outcome = run_search(options, prefix, unlock: unlock)

    assert_failure outcome, :exhausted, /no matching suffix/
    assert_equal 2, calls.size
  ensure

    prefix.wipe if prefix
  end

  def test_busy_short_circuits

    prefix = prefix_buffer
    unlock, calls = scripted_unlock([ :busy, :success ])

    outcome = run_search(options, prefix, unlock: unlock)

    assert_failure outcome, :busy, /volume busy/
    assert_failure_context outcome, index: 1, suffix: 'ab'
    assert_equal 1, calls.size
  ensure

    prefix.wipe if prefix
  end

  def test_wrong_target_short_circuits

    prefix = prefix_buffer
    unlock, calls = scripted_unlock([ :wrong_target ])

    outcome = run_search(options, prefix, unlock: unlock)

    assert_failure outcome, :wrong_target, /not an applicable volume/
    assert_failure_context outcome, index: 1, suffix: 'ab'
    assert_equal 1, calls.size
  ensure

    prefix.wipe if prefix
  end

  def test_error_message_masks_prefix_and_keeps_suffix

    prefix = prefix_buffer
    unlock = lambda { |**_kwargs|

      unlock_result(
        :error,
        detail: 'diskutil failed',
        exitstatus: 1,
      )
    }

    outcome = run_search(options, prefix, unlock: unlock)

    assert_failure outcome, :error, /\Adiskutil failed;/
    assert_failure_context outcome, index: 1, suffix: 'ab'
    assert_match(/passphrase=\*{8}ab/, outcome.message)
    assert_match(/exitstatus=1/, outcome.message)
  ensure

    prefix.wipe if prefix
  end

  def test_error_short_circuits_with_detail

    prefix = prefix_buffer
    idx = 0
    unlock = lambda { |**_kwargs|

      idx += 1
      unlock_result(:error, detail: 'diskutil unlock is macOS-only')
    }

    outcome = run_search(options, prefix, unlock: unlock)

    assert_failure outcome, :error, /diskutil unlock is macOS-only/
    assert_failure_context outcome, index: 1, suffix: 'ab'
    assert_equal 1, idx
  ensure

    prefix.wipe if prefix
  end

  def test_already_unlocked_does_not_invent_suffix

    prefix = prefix_buffer
    unlock, calls = scripted_unlock([ :already_unlocked ])

    outcome = run_search(options, prefix, unlock: unlock)

    assert_failure outcome, :already_unlocked, /volume already unlocked/
    assert_failure_context outcome, index: 1, suffix: 'ab'
    assert_equal 1, calls.size
  ensure

    prefix.wipe if prefix
  end

  def test_auth_failed_then_busy_stops_without_later_candidates

    prefix = prefix_buffer
    unlock, calls = scripted_unlock([ :auth_failed, :busy ])

    outcome = run_search(options, prefix, unlock: unlock)

    assert_failure outcome, :busy, /volume busy/
    assert_failure_context outcome, index: 2, suffix: 'ba'
    assert_equal 2, calls.size
  ensure

    prefix.wipe if prefix
  end

  def test_passes_engine_and_runner_through

    prefix = prefix_buffer
    runner = lambda { |*| }
    unlock, calls = scripted_unlock([ :success ])

    run_search(
      options,
      prefix,
      engine: :apfs,
      runner: runner,
      unlock: unlock,
    )

    assert_equal :apfs, calls[0][:engine]
    assert_same runner, calls[0][:runner]
  ensure

    prefix.wipe if prefix
  end

  def test_default_unlock_uses_injected_runner_without_real_diskutil

    prefix = prefix_buffer
    seen_argv = nil
    runner = lambda { |argv, stdin_data:|

      seen_argv = argv.dup
      refute_includes argv.join("\0"), PREFIX
      refute_includes argv, '-passphrase'
      assert_includes argv, '-stdinpassphrase'
      UsbCracker::Diskutil::Invocation.new(
        exitstatus: 0,
        stderr: '',
        stdout: '',
      )
    }

    outcome = run_search(options, prefix, engine: :apfs, runner: runner)

    assert_predicate outcome, :success?
    assert_equal 'ab', outcome.suffix
    refute_nil seen_argv
    refute_includes seen_argv.join("\0"), PREFIX
  ensure

    prefix.wipe if prefix
  end

  def test_report_success_piped_stdout_is_exactly_suffix

    stdout = StringIO.new
    stderr = StringIO.new
    outcome = UsbCracker::Search::Outcome.new(
      exit_status: 0,
      kind: :success,
      message: nil,
      suffix: 'ba',
    )

    returned = UsbCracker::Search.report(
      outcome,
      abort_exit: nil,
      stderr: stderr,
      stdout: stdout,
    )

    assert_same outcome, returned
    assert_equal "ba\n", stdout.string
    assert_equal '', stderr.string
    refute_includes stdout.string, PREFIX
  end

  def test_report_success_tty_stdout_uses_winning_report

    stdout = StringIO.new
    stderr = StringIO.new
    stdout.define_singleton_method(:tty?) { true }
    outcome = UsbCracker::Search::Outcome.new(
      exit_status: 0,
      kind: :success,
      message: nil,
      suffix: 'ba',
    )

    UsbCracker::Search.report(
      outcome,
      abort_exit: nil,
      stderr: stderr,
      stdout: stdout,
    )

    green = UsbCracker::Progress::CLR_GREEN
    reset = UsbCracker::Progress::CLR_RESET
    assert_equal(
      "usb-cracker: winning suffix=\"#{green}ba#{reset}\"\n",
      stdout.string,
    )
    assert_equal '', stderr.string
  end

  def test_report_failure_aborts_without_secrets

    stdout = StringIO.new
    stderr = StringIO.new
    outcome = UsbCracker::Search::Outcome.new(
      exit_status: 1,
      kind: :exhausted,
      message: 'no matching suffix',
      suffix: nil,
    )

    UsbCracker::Search.report(
      outcome,
      abort_exit: nil,
      stderr: stderr,
      stdout: stdout,
    )

    assert_equal '', stdout.string
    assert_match(/^usb-cracker: no matching suffix\n/, stderr.string)
    refute_includes stderr.string, PREFIX
  end

  def test_always_logs_candidate_before_attempt

    prefix = prefix_buffer
    unlock, _calls = scripted_unlock([ :auth_failed, :success ])
    log, entries = recording_log

    run_search(options, prefix, log: log, unlock: unlock)

    assert_equal 2, entries.size
    assert_equal [ 1, 2 ], entries.map { |e| e[:index] }
    assert_equal [ 'ab', 'ba' ], entries.map { |e| e[:suffix] }
    assert_nil entries[0][:result]
    assert_nil entries[1][:result]
  ensure

    prefix.wipe if prefix
  end

  def test_stderr_logs_each_candidate_before_unlock_when_tracing

    prefix = prefix_buffer
    unlock, _calls = scripted_unlock([ :auth_failed, :success ])
    prev_stderr = $stderr
    $stderr = StringIO.new

    begin

      outcome = run_search(
        options(trace_suffixes: true),
        prefix,
        unlock: unlock,
      )
      sink = $stderr.string
    ensure

      $stderr = prev_stderr
    end

    assert_predicate outcome, :success?
    assert_match(/^attempt 1 suffix=ab\n/, sink)
    assert_match(/attempt 2 suffix=ba/, sink)
    assert_includes sink, 'status='
    refute_includes sink, PREFIX
  ensure

    prefix.wipe if prefix
  end

  def test_progress_ticks_when_not_tracing_suffixes

    prefix = prefix_buffer
    unlock, _calls = scripted_unlock([ :auth_failed, :success ])
    ticks = []
    meter = Object.new
    meter.define_singleton_method(:tick) { |index, suffix = nil|

      ticks << [ index, suffix ]
      meter
    }
    meter.define_singleton_method(:clear!) { meter }
    meter.define_singleton_method(:finish) { |success:| @finished = success; meter }
    meter.define_singleton_method(:finished) { @finished }

    outcome = run_search(
      options,
      prefix,
      progress: meter,
      unlock: unlock,
    )

    assert_predicate outcome, :success?
    assert_equal [ [ 1, 'ab' ], [ 2, 'ba' ] ], ticks
    assert_equal true, meter.finished
  ensure

    prefix.wipe if prefix
  end

  def test_tracing_on_logs_suffix_index_and_status_never_prefix

    prefix = prefix_buffer
    unlock, _calls = scripted_unlock([ :auth_failed, :success ])
    log, entries = recording_log

    run_search(
      options(trace_suffixes: true),
      prefix,
      log: log,
      unlock: unlock,
    )

    # Before + after unlock for each of two candidates.
    assert_equal 4, entries.size
    assert_equal [ 1, 1, 2, 2 ], entries.map { |e| e[:index] }
    assert_equal [ 'ab', 'ab', 'ba', 'ba' ], entries.map { |e| e[:suffix] }
    assert_nil entries[0][:result]
    assert_equal :auth_failed, entries[1][:result].status
    assert_nil entries[2][:result]
    assert_equal :success, entries[3][:result].status

    entries.each do |entry|

      assert_hides_prefix(
        entry[:suffix],
        entry[:index].to_s,
        entry[:result] && entry[:result].detail,
        entry[:result] && entry[:result].inspect,
        entry.inspect,
      )
      refute_includes entry[:suffix], PREFIX
    end
  ensure

    prefix.wipe if prefix
  end

  def test_tracing_on_default_sink_gets_suffix_not_prefix

    prefix = prefix_buffer
    unlock, _calls = scripted_unlock([ :auth_failed, :success ])
    prev_stderr = $stderr
    $stderr = StringIO.new

    begin

      outcome = run_search(
        options(trace_suffixes: true),
        prefix,
        unlock: unlock,
      )
      sink = $stderr.string
    ensure

      $stderr = prev_stderr
    end

    assert_predicate outcome, :success?
    assert_includes sink, 'suffix=ab'
    assert_includes sink, 'suffix=ba'
    assert_includes sink, 'status=auth_failed'
    assert_includes sink, 'status=success'
    refute_includes sink, PREFIX
    refute_includes sink, PREFIX + 'ab'
    refute_includes sink, PREFIX + 'ba'
  ensure

    prefix.wipe if prefix
  end
end
