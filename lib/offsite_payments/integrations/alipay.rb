# -*- coding: utf-8 -*-
require 'cgi'
require 'digest/md5'
require 'net/http'

module OffsitePayments #:nodoc:
  module Integrations #:nodoc:
    module Alipay

      mattr_accessor :service_url

      # 标准双接口 版本: 1.9 P15
      self.service_url = 'https://mapi.alipay.com/gateway.do?_input_charset=utf-8'

      def self.notification(post)
        Notification.new(post)
      end

      def self.return(query_string)
        Return.new(query_string)
      end

      # defines form fields and field mappings between ActiveMerchant and alipay
      class Helper < OffsitePayments::Helper
        TRADE_CREATE_BY_BUYER         = 'trade_create_by_buyer'         # 标准双接口 1.9
        CREATE_DIRECT_PAY_BY_USER     = 'create_direct_pay_by_user'     # 即时到账交易接口 4.7 
        CREATE_PARTNER_TRADE_BY_BUYER = 'create_partner_trade_by_buyer' # 纯担保交易接口 1.8

        # 标准双接口 表 4-1; 即时到账交易接口 表 4.1
        # 基本参数
        mapping :service,      'service'                              # 接口名称
        mapping :account,      'partner'                              # 合作者身份ID
        mapping :charset,      '_input_charset'                       # 参数编码字符集
        # sign_type 签名方式 见: method sign
        # sign 密钥 见: method sign
        mapping :notify_url,   'notify_url'                           # 服务器异步通知页面路径
        mapping :return_url,   'return_url'                           # 页面跳转同步通知页面路径
        mapping :show_url,     'show_url'                             # 

        # 业务参数
        mapping :order,        'out_trade_no'                         # 商户网站唯一订单号
        mapping :subject,      'subject'                              # 商品名称
        mapping :payment_type, 'payment_type'                         # 支付类型

        mapping :seller, :email => 'seller_email', :id => 'seller_id' # 卖家支付宝账号
        mapping :buyer,  :email => 'buyer_email',  :id => 'buyer_id'  # 买家支付宝账号 

        # seller_account_name 卖家别名支付宝账号
        # buyer_account_name  买家别名支付宝账号
        mapping :price,     'price'                                   # 商品单价
        mapping :quantity,  'quantity'                                # 商品数量
        mapping :body,      'body'                                    # 商品详情, 商品描述
        mapping :discount,  'discount'                                # 折扣
        mapping :total_fee, 'total_fee'                               # 总金额, 交易金额

        mapping :it_b_pay,          'it_b_pay'                        # 买家逾期不付款, 自动关闭交易
        mapping :anti_phishing_key, 'anti_phishing_key'               # 防钓鱼时间戳
        mapping :token,             'token'                           # 快捷登陆授权令牌

        ##################################### 接口特有 ########################################
        # 标准双接口
        mapping :receive, :name =>    'receive_name',                 # 收货人姓名 
                          :address => 'receive_address',              # 收货人地址
                          :zip =>     'receive_zip',                  # 收货人邮编
                          :phone =>   'receive_phone',                # 收货人电话
                          :mobile =>  'receive_mobile'                # 收货人手机

        mapping :t_s_send_1,        't_s_send_1'                      # 买家逾期不发货, 允许买家退款
        mapping :t_s_send_2,        't_s_send_2'                      # 卖家逾期不发货, 建议买家退款
        mapping :t_b_rec_post,      't_b_rec_post'                    # 买家逾期不确认收货, 自动完成交易

        # 即时到账
        mapping :error_notify_url,   'error_notify_url'               # 请求出错时的通知页面路径
        mapping :paymethod,          'paymethod'                      # 默认支付方式
        mapping :enable_paymethod,   'enable_paymethod'               # 支付渠道
        mapping :need_ctu_check,     'need_ctu_check'                 # 网银支付时是否做CTU校验
        mapping :royalty_type,       'royalty_type'                   # 提成类型
        mapping :royalty_parameters, 'royalty_parameters'             # 分润账号集
        mapping :exter_invoke_ip,    'exter_invoke_ip'                # 客户端 IP
        mapping :extra_common_param, 'extra_common_param'             # 公用回传参数
        mapping :extend_param,       'extend_param'                   # 公用业务扩展参数
        mapping :default_login,      'default_login'                  # 自动登录标识
        mapping :product_type,       'product_type'                   # 商户申请的产品类型
        mapping :item_orders_info,   'item_orders_info'               # 商户回传业务参数
        mapping :sign_id_ext,        'sign_id_ext'                    # 商户买家签约号
        mapping :sign_name_ext,      'sign_name_ext'                  # 商户买家签约名
        mapping :qr_pay_mode,        'qr_pay_mode'                    # 扫码支付方式

        # 纯担保交易接口

        # 物流类型, 物流费用, 物流支付类型
        ['', '_1', '_2', '_3'].each do |postfix|
          self.class_eval <<-EOF
            mapping :logistics#{postfix}, :type => 'logistics_type#{postfix}',
                                          :fee => 'logistics_fee#{postfix}',
                                          :payment => 'logistics_payment#{postfix}'
            EOF
        end

        # initialize the form, insert hidden fields, fetch the md5secret
        def initialize(order, account, options = {})
          super
        end

        # form_fields: actions after form is generatied, such as calculate checksums
        # 标准双接口 8.2签名 8.2.1 MD5 签名
        # 请求时签名
        def sign
          query_string = @fields.sort.collect{ |s|s[0] + "=" + CGI.unescape(s[1]) }.join("&")
          add_field('sign', Digest::MD5.hexdigest(query_string + KEY))

          add_field('sign_type', 'MD5')
          nil
        end

      end

      module Sign
        # 标准双接口 8.2签名 8.2.1 MD5 签名
        # 通知返回时验证签名
        def verify?
          sign_type = @params.delete("sign_type")
          sign = @params.delete("sign")

          md5_string = @params.sort.collect do |s|
            unless s[0] == "notify_id"
              s[0] + "=" + CGI.unescape(s[1])
            else
              s[0] + "=" + s[1]
            end
          end

          Digest::MD5.hexdigest(md5_string.join("&")+KEY) == sign.downcase
        end
      end

      class Return < OffsitePayments::Return
        include Sign

        def order
          @params["out_trade_no"]
        end

        def amount
          @params["total_fee"]
        end

        def initialize(query_string)
          super
        end

        def success?
          unless verify?
            @message = "Alipay Error: ILLEGAL_SIGN"
            return false
          end

          true
        end

        def message
          @message
        end

      end

      # alipay 通知解析
      # 解析多种支付接口的回调, 
      class Notification < OffsitePayments::Notification
        include Sign

        MOBILE_SECURITYPAY_PAY = 'mobile.securitypay.pay' # 移动快捷支付应用集成接入包支付接口 1.2
        TRADE_CREATE_BY_BUYER  = 'trade_create_by_buyer'  # 标准双接口 1.9 表6-1

        def complete?
          trade_status == "TRADE_FINISHED"
        end

        def pending?
          trade_status == 'WAIT_BUYER_PAY'
        end

        def status
          trade_status
        end

        # Acknowledge the transaction to Alipay. This method has to be called after a new
        # apc arrives. Alipay will verify that all the information we received are correct
        # and will return ok or a fail.
        #
        # Example:
        #
        #   def ipn
        #     notify = AlipayNotification.new(request.raw_post)
        #
        #     if notify.acknowledge
        #       ... process order ... if notify.complete?
        #     else
        #       ... log possible hacking attempt ...
        #     end
        def acknowledge
          raise StandardError.new("Faulty alipay result: ILLEGAL_SIGN") unless verify?
          true
        end

        # string 型参数
        ['notify_id', 'notify_type', 'trade_no', 'subject', 
         'body', 'out_trade_no', 'payment_type', 'extra_common_param',
         'seller_email', 'seller_id', 'buyer_email', 'buyer_id', 
         'logistics_type', 'logistics_payment',
         'buyer_actions', 'seller_actions',
         'out_channel_type', 'out_channel_amount', 'out_channel_inst', 'business_scene',
         'receive_name', 'receive_address', 'receive_zip', 'receive_phone', 'receive_mobile'].each do |param|
          self.class_eval <<-EOF
              def #{param}
                params['#{param}']
              end
            EOF
        end

        # Number 型参数
        ['price', 'quantity', 'discount', 'total_fee', 'coupon_discount', 'logistics_fee'].each do |param|
          self.class_eval <<-EOF
              def #{param}
                params['#{param}']
              end
            EOF
        end

        # String 型 状态参数
        ['trade_status', 'refund_status', 'logistics_status'].each do |param|
          self.class_eval <<-EOF
              def #{param}
                params['#{param}']
              end
            EOF
        end

        # Date 型参数
        ['notify_time', 'gmt_create', 'gmt_payment', 'gmt_refund', 'gmt_logistics_modify',
        'gmt_close', 'gmt_send_goods'].each do |param|
          self.class_eval <<-EOF
              def #{param}
                Time.parse params['#{param}']
              end
            EOF
        end

        ['is_total_fee_adjust', 'use_coupon'].each do |param|
          self.class_eval <<-EOF
              def #{param}?
                'T' == params['#{param}']
              end
            EOF
        end
      end
    end
  end
end
