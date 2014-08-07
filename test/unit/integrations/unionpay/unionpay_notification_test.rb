require 'test_helper'

class UnionpayNotificationTest < Test::Unit::TestCase
  include OffsitePayments::Integrations

  def setup
    @unionpay = Unionpay::Notification.new(http_raw_data)
  end

  def test_accessors
    assert @unionpay.complete?
    assert_equal "", @unionpay.status
    assert_equal "", @unionpay.transaction_id
    assert_equal "", @unionpay.item_id
    assert_equal "", @unionpay.gross
    assert_equal "", @unionpay.currency
    assert_equal "", @unionpay.received_at
    assert @unionpay.test?
  end

  def test_compositions
    assert_equal Money.new(3166, 'USD'), @unionpay.amount
  end

  # Replace with real successful acknowledgement code
  def test_acknowledgement

  end

  def test_send_acknowledgement
  end

  def test_respond_to_acknowledge
    assert @unionpay.respond_to?(:acknowledge)
  end

  private
  def http_raw_data
    ""
  end
end
