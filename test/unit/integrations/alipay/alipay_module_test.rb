require 'test_helper'

class AlipayTest < Test::Unit::TestCase
  include OffsitePayments::Integrations

  def test_notification_method
    assert_instance_of Alipay::Notification, Alipay.notification('name=cody')
  end
end
