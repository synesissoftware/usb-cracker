#! /usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), '../../lib')


require 'usb_cracker/secret_buffer'
require 'usb_cracker/unlock'

require 'test/unit'


class Test_unlock < Test::Unit::TestCase

  PREFIX = 'unit-test-prefix-token'
  SUFFIX = 'sfx'
  FULL = PREFIX + SUFFIX
  VOLUME = 'disk2s1'

  def attempt(**opts)

    defaults = {
      engine: :apfs,
      prefix: PREFIX,
      runner: @runner,
      suffix: SUFFIX,
      volume: VOLUME,
    }

    UsbCracker::Unlock.attempt(**defaults.merge(opts))
  end

  def recording_runner(responses)

    calls = []
    idx = 0
    runner = lambda { |argv, stdin_data:|

      calls << {
        argv: argv.dup,
        stdin_data: stdin_data.dup,
        stdin_object: stdin_data,
      }
      raw = responses[idx]
      idx += 1
      raw
    }

    [ runner, calls ]
  end

  def invocation(exitstatus:, stderr: '', stdout: '')

    UsbCracker::Diskutil::Invocation.new(
      exitstatus: exitstatus,
      stderr: stderr,
      stdout: stdout,
    )
  end

  def assert_argv_hides_secrets(argv)

    argv.each do |el|

      refute_includes el, PREFIX
      refute_includes el, SUFFIX
      refute_includes el, FULL
    end
    refute_includes argv, '-passphrase'
    assert_includes argv, '-stdinpassphrase'
    refute_includes argv, FULL
  end

  def assert_result_hides_secrets(result)

    refute_includes result.detail, PREFIX
    refute_includes result.detail, SUFFIX
    refute_includes result.detail, FULL
    refute_includes result.inspect, PREFIX
    refute_includes result.inspect, SUFFIX
    refute_includes result.inspect, FULL
    refute_includes result.status.to_s, PREFIX
  end


  def test_success_apfs

    @runner, calls = recording_runner([
      invocation(exitstatus: 0, stdout: 'Unlocked and mounted APFS Volume'),
    ])

    result = attempt

    assert_equal :success, result.status
    assert_true result.success?
    assert_equal :apfs, result.engine
    assert_equal 0, result.exitstatus
    assert_equal 'unlocked', result.detail
    assert_equal 1, calls.size
    assert_equal [
      'diskutil',
      'apfs',
      'unlockVolume',
      VOLUME,
      '-stdinpassphrase',
    ], calls[0][:argv]
    assert_argv_hides_secrets(calls[0][:argv])
    assert_equal "#{FULL}\n", calls[0][:stdin_data]
    assert_result_hides_secrets(result)
  end

  def test_auth_failed

    @runner, calls = recording_runner([
      invocation(
        exitstatus: 1,
        stderr: 'Error unlocking APFS Volume: The given passphrase is incorrect (-69557)',
      ),
    ])

    result = attempt

    assert_equal :auth_failed, result.status
    assert_false result.success?
    assert_equal 'authentication failed', result.detail
    assert_equal 1, calls.size
    assert_argv_hides_secrets(calls[0][:argv])
    assert_result_hides_secrets(result)
  end

  def test_already_unlocked

    @runner, _calls = recording_runner([
      invocation(
        exitstatus: 1,
        stderr: 'Error unlocking APFS Volume: The given APFS Volume is not locked (-69589)',
      ),
    ])

    result = attempt

    assert_equal :already_unlocked, result.status
    assert_false result.success?
    assert_equal 'already unlocked', result.detail
    assert_result_hides_secrets(result)
  end

  def test_busy

    @runner, _calls = recording_runner([
      invocation(
        exitstatus: 1,
        stderr: 'Error: -69808: Resource busy',
      ),
    ])

    result = attempt

    assert_equal :busy, result.status
    assert_equal 'volume busy', result.detail
    assert_result_hides_secrets(result)
  end

  def test_unexpected_nonzero

    @runner, _calls = recording_runner([
      invocation(
        exitstatus: 1,
        stderr: 'Error: -69842: A problem occurred',
      ),
    ])

    result = attempt

    assert_equal :error, result.status
    assert_equal 'diskutil failed', result.detail
    assert_equal 1, result.exitstatus
    assert_result_hides_secrets(result)
  end

  def test_auto_falls_back_to_core_storage_on_wrong_target

    @runner, calls = recording_runner([
      invocation(
        exitstatus: 1,
        stderr: "#{VOLUME} is not an APFS Volume",
      ),
      invocation(
        exitstatus: 0,
        stdout: 'Unlocked CoreStorage logical volume',
      ),
    ])

    result = attempt(engine: :auto)

    assert_equal :success, result.status
    assert_equal :core_storage, result.engine
    assert_equal 2, calls.size
    assert_includes calls[0][:argv], 'apfs'
    assert_includes calls[1][:argv], 'coreStorage'
    assert_argv_hides_secrets(calls[0][:argv])
    assert_argv_hides_secrets(calls[1][:argv])
    assert_equal "#{FULL}\n", calls[1][:stdin_data]
    assert_result_hides_secrets(result)
  end

  def test_auto_does_not_fall_back_on_auth_failed

    @runner, calls = recording_runner([
      invocation(
        exitstatus: 1,
        stderr: 'The given passphrase is incorrect',
      ),
      invocation(exitstatus: 0, stdout: 'should not run'),
    ])

    result = attempt(engine: :auto)

    assert_equal :auth_failed, result.status
    assert_equal :apfs, result.engine
    assert_equal 1, calls.size
  end

  def test_core_storage_engine_only

    @runner, calls = recording_runner([
      invocation(exitstatus: 0, stdout: 'Unlocked CoreStorage logical volume'),
    ])

    result = attempt(engine: :core_storage)

    assert_equal :success, result.status
    assert_equal :core_storage, result.engine
    assert_equal 1, calls.size
    assert_equal [
      'diskutil',
      'coreStorage',
      'unlockVolume',
      VOLUME,
      '-stdinpassphrase',
    ], calls[0][:argv]
    assert_argv_hides_secrets(calls[0][:argv])
  end

  def test_wipes_ephemeral_passphrase_after_attempt

    @runner, calls = recording_runner([
      invocation(exitstatus: 0, stdout: 'Unlocked and mounted APFS Volume'),
    ])

    result = attempt

    assert_equal :success, result.status
    held = calls[0][:stdin_object]
    assert_true held.empty?
    refute_includes held, PREFIX
    refute_includes held, FULL
  end

  def test_wipes_ephemeral_passphrase_when_runner_raises

    held = nil
    runner = lambda { |argv, stdin_data:|

      held = stdin_data
      raise 'mock runner exploded'
    }

    e = assert_raise(RuntimeError) { attempt(runner: runner) }

    assert_equal 'mock runner exploded', e.message
    refute_includes e.message, PREFIX
    refute_includes e.message, FULL
    assert_true held.empty?
    refute_includes held, PREFIX
  end

  def test_does_not_wipe_caller_secret_buffer

    buf = UsbCracker::SecretBuffer.new(String.new(PREFIX))
    @runner, _calls = recording_runner([
      invocation(exitstatus: 0, stdout: 'Unlocked and mounted APFS Volume'),
    ])

    result = attempt(prefix: buf)

    assert_equal :success, result.status
    assert_equal PREFIX, buf.to_s
    assert_false buf.wiped?
  ensure

    buf.wipe if buf
  end

  def test_does_not_wipe_caller_prefix_string

    src = String.new(PREFIX)
    @runner, _calls = recording_runner([
      invocation(exitstatus: 0, stdout: 'Unlocked and mounted APFS Volume'),
    ])

    result = attempt(prefix: src)

    assert_equal :success, result.status
    assert_equal PREFIX, src
  end

  def test_default_runner_is_macos_only

    omit 'default runner would invoke diskutil' if RUBY_PLATFORM.include?('darwin')

    result = UsbCracker::Unlock.attempt(
      prefix: PREFIX,
      suffix: SUFFIX,
      volume: VOLUME,
    )

    assert_equal :error, result.status
    assert_equal 'diskutil unlock is macOS-only', result.detail
    assert_result_hides_secrets(result)
  end

  def test_rejects_unknown_engine

    @runner, _calls = recording_runner([])

    e = assert_raise(ArgumentError) { attempt(engine: :filevault) }

    assert_match(/unknown engine/, e.message)
  end
end
