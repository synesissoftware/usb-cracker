#! /usr/bin/env ruby

$:.unshift File.join(File.dirname(__FILE__), '../../lib')


require 'usb_cracker/version'

require 'test/unit'


class Test_version < Test::Unit::TestCase

  def test_has_VERSION

    assert defined? UsbCracker::VERSION
  end

  def test_has_VERSION_MAJOR

    assert defined? UsbCracker::VERSION_MAJOR
  end

  def test_has_VERSION_MINOR

    assert defined? UsbCracker::VERSION_MINOR
  end

  def test_has_VERSION_REVISION

    assert defined? UsbCracker::VERSION_REVISION
  end

  def test_VERSION_has_consistent_format

    assert_equal UsbCracker::VERSION.split('.')[0..2].join('.'), "#{UsbCracker::VERSION_MAJOR}.#{UsbCracker::VERSION_MINOR}.#{UsbCracker::VERSION_REVISION}"
  end
end
