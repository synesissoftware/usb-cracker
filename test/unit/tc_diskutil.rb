#! /usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), '../../lib')


require 'usb_cracker/diskutil'

require 'test/unit'


class Test_diskutil < Test::Unit::TestCase

  VOLUME = 'disk2s1'
  UUID = 'AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE'

  def test_apfs_argv_uses_stdinpassphrase_not_passphrase

    argv = UsbCracker::Diskutil.unlock_argv(:apfs, VOLUME)

    assert_equal [
      'diskutil',
      'apfs',
      'unlockVolume',
      VOLUME,
      '-stdinpassphrase',
    ], argv
    refute_includes argv, '-passphrase'
  end

  def test_core_storage_argv_uses_stdinpassphrase_not_passphrase

    argv = UsbCracker::Diskutil.unlock_argv(:core_storage, UUID)

    assert_equal [
      'diskutil',
      'coreStorage',
      'unlockVolume',
      UUID,
      '-stdinpassphrase',
    ], argv
    refute_includes argv, '-passphrase'
  end

  def test_unlock_argv_rejects_empty_volume

    e = assert_raise(ArgumentError) { UsbCracker::Diskutil.unlock_argv(:apfs, '') }

    assert_match(/volume/, e.message)
  end

  def test_unlock_argv_rejects_flag_like_volume

    e = assert_raise(ArgumentError) { UsbCracker::Diskutil.unlock_argv(:apfs, '-passphrase') }

    assert_match(/device id or UUID/, e.message)
  end

  def test_unlock_argv_rejects_unknown_engine

    e = assert_raise(ArgumentError) { UsbCracker::Diskutil.unlock_argv(:filevault, VOLUME) }

    assert_match(/unknown engine/, e.message)
  end

  def test_classify_success_on_zero_exit

    status = UsbCracker::Diskutil.classify_status(
      exitstatus: 0,
      stderr: '',
      stdout: 'Unlocked and mounted APFS Volume',
    )

    assert_equal :success, status
  end

  def test_classify_auth_failed

    status = UsbCracker::Diskutil.classify_status(
      exitstatus: 1,
      stderr: 'Error unlocking APFS Volume: The given passphrase is incorrect (-69557)',
      stdout: '',
    )

    assert_equal :auth_failed, status
  end

  def test_classify_auth_failed_user_does_not_exist

    status = UsbCracker::Diskutil.classify_status(
      exitstatus: 1,
      stderr: 'Passphrase incorrect or user does not exist',
      stdout: '',
    )

    assert_equal :auth_failed, status
  end

  def test_classify_already_unlocked_nonzero_exit

    status = UsbCracker::Diskutil.classify_status(
      exitstatus: 1,
      stderr: 'Error unlocking APFS Volume: The given APFS Volume is not locked (-69589)',
      stdout: '',
    )

    assert_equal :already_unlocked, status
  end

  def test_classify_busy

    status = UsbCracker::Diskutil.classify_status(
      exitstatus: 1,
      stderr: 'Error: -69808: Resource busy',
      stdout: '',
    )

    assert_equal :busy, status
  end

  def test_classify_wrong_target_not_apfs

    status = UsbCracker::Diskutil.classify_status(
      exitstatus: 1,
      stderr: "#{VOLUME} is not an APFS Volume",
      stdout: '',
    )

    assert_equal :wrong_target, status
  end

  def test_classify_wrong_target_could_not_find_disk

    status = UsbCracker::Diskutil.classify_status(
      exitstatus: 1,
      stderr: 'Could not find disk: disk99s9',
      stdout: '',
    )

    assert_equal :wrong_target, status
  end

  def test_classify_unexpected_nonzero

    status = UsbCracker::Diskutil.classify_status(
      exitstatus: 1,
      stderr: 'Error: -69842: A problem occurred',
      stdout: '',
    )

    assert_equal :error, status
  end

  def test_invocation_from_array

    inv = UsbCracker::Diskutil.invocation_from([ 'out', 'err', 7 ])

    assert_equal 'out', inv.stdout
    assert_equal 'err', inv.stderr
    assert_equal 7, inv.exitstatus
  end
end
