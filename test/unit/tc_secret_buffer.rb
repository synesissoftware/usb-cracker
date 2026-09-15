#! /usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), '../../lib')


require 'usb_cracker/secret_buffer'

require 'test/unit'


class Test_secret_buffer < Test::Unit::TestCase

  TOKEN = 'unit-test-prefix-token'

  def test_copies_mutable_source_then_wipes_source

    src = String.new(TOKEN)
    buf = UsbCracker::SecretBuffer.new(src)

    assert_equal TOKEN, buf.to_s
    assert_true src.empty?
    assert_false buf.to_s.frozen?
  ensure

    buf.wipe if buf
  end

  def test_accepts_frozen_source_without_raising

    frozen = TOKEN.dup.freeze
    buf = UsbCracker::SecretBuffer.new(frozen)

    assert_equal TOKEN, buf.to_s
    assert_equal TOKEN, frozen
  ensure

    buf.wipe if buf
  end

  def test_wipe_clears_content_and_is_idempotent

    buf = UsbCracker::SecretBuffer.new(String.new(TOKEN))

    assert_same buf, buf.wipe
    assert_true buf.wiped?
    assert_true buf.empty?
    assert_equal '', buf.to_s
    refute_includes buf.to_s, TOKEN

    buf.wipe
    assert_true buf.empty?
  end

  def test_clear_bang_aliases_wipe

    buf = UsbCracker::SecretBuffer.new(String.new(TOKEN))

    buf.clear!
    assert_true buf.wiped?
    assert_equal '', buf.to_s
  end

  def test_inspect_omits_secret

    buf = UsbCracker::SecretBuffer.new(String.new(TOKEN))

    refute_includes buf.inspect, TOKEN
    refute_includes buf.pretty_inspect, TOKEN
    assert_match(/SecretBuffer/, buf.inspect)
  ensure

    buf.wipe if buf
  end

  def test_inspect_after_wipe

    buf = UsbCracker::SecretBuffer.new(String.new(TOKEN))
    buf.wipe

    assert_equal '#<UsbCracker::SecretBuffer wiped>', buf.inspect
    refute_includes buf.inspect, TOKEN
  end

  def test_dup_is_independent

    a = UsbCracker::SecretBuffer.new(String.new(TOKEN))
    b = a.dup

    a.wipe
    assert_equal TOKEN, b.to_s
    assert_false b.wiped?

    b.wipe
    assert_true b.empty?
  end

  def test_wipe_string_bang_clears_mutable_string

    s = String.new(TOKEN)

    UsbCracker::SecretBuffer.wipe_string!(s)

    assert_true s.empty?
    refute_includes s, TOKEN
  end

  def test_wipe_string_bang_leaves_frozen_string

    frozen = TOKEN.dup.freeze

    UsbCracker::SecretBuffer.wipe_string!(frozen)

    assert_equal TOKEN, frozen
  end

  def test_rejects_non_string_content

    e = assert_raise(ArgumentError) { UsbCracker::SecretBuffer.new(nil) }

    assert_equal 'content must be a String', e.message
  end

  def test_cannot_be_marshaled

    buf = UsbCracker::SecretBuffer.new(String.new(TOKEN))

    assert_raise(TypeError) { Marshal.dump(buf) }
  ensure

    buf.wipe if buf
  end
end
