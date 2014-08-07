require 'test_helper'

class UnionpayTest < Test::Unit::TestCase
  include OffsitePayments::Integrations

  def test_notification_method
    assert_instance_of Unionpay::Notification, Unionpay.notification('name=cody')
  end
end
