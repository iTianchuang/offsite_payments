# -*- coding: utf-8 -*-
module OffsitePayments #:nodoc:
  module Integrations #:nodoc:
    module Unionpay

      mattr_accessor :service_url
      self.service_url = 'https://www.example.com'

      def self.notification(post)
        Notification.new(post)
      end

      module Sign

        # 订单推送请求 签名 附录B报文签名
        def sign!(params)
          params.delete('signMethod')
          params.delete('signature')
          params.compact!                                                                             # 空值不参与签名计算

          query_string_not_sign = params.sort.collect{ |s|s[0].to_s + "=" + s[1].to_s }.join("&")  # 被签名字符串中的按照key值做升序排序

          query_string_for_sign = "#{query_string_not_sign}&#{Digest::MD5.hexdigest(KEY)}"
          signature = Digest::MD5.hexdigest query_string_for_sign                                          # MD5签名

          params['signMethod'] = 'MD5'
          params['signature'] = signature

          query_string = params.sort.collect{ |s|s[0].to_s + "=" + s[1].to_s }.join("&")
          query_string = "#{query_string}&#{Digest::MD5.hexdigest(KEY)}"

          query_string
        end

        # 通知返回时验证签名
        def verify_sign(params)
          p = params.dup
          sign_method = p.delete("signMethod")
          signature = p.delete("signature")

          query_string = p.sort.collect{ |s|s[0].to_s + "=" + s[1].to_s }.join("&")  

          Digest::MD5.hexdigest("#{query_string}&#{Digest::MD5.hexdigest(KEY)}") == signature.downcase
        end
      end

      module BaseRequestResponse
        include Sign

        attr_reader :uri
        attr_reader :req_params, :req_qstring, :res_params, :res

        def send
          @http = Net::HTTP.new(self.uri.host, self.uri.port)
          @res = @http.post self.uri.path, self.req_qstring
          @res_params = parse @res.body

          raise StandardError.new("Response: ILLEGAL_SIGN") unless verify_sign res_params
          @res
        end

        private

        # 订单推送应答 (同步)
        def parse(res)
          params = {}
          for line in res.to_s.split('&')
            key, value = *line.scan( %r{^([A-Za-z0-9_.-]+)\=(.*)$} ).flatten
            params[key] = CGI.unescape(value.to_s) if key.present?
          end

          params
        end

      end

      class Helper < OffsitePayments::Helper
        # Replace with the real mapping
        mapping :account, ''
        mapping :amount, ''

        mapping :order, ''

        mapping :customer, :first_name => '',
                           :last_name  => '',
                           :email      => '',
                           :phone      => ''

        mapping :billing_address, :city     => '',
                                  :address1 => '',
                                  :address2 => '',
                                  :state    => '',
                                  :zip      => '',
                                  :country  => ''

        mapping :notify_url, ''
        mapping :return_url, ''
        mapping :cancel_return_url, ''
        mapping :description, ''
        mapping :tax, ''
        mapping :shipping, ''
      end

      class Trade
        include BaseRequestResponse

        def initialize(orderNumber, orderAmount, options = {})

          @uri = URI.parse('http://202.101.25.178:8080/gateway/merchant/trade')

          @req_params = {
            'merId'            => ACCOUNT,                                                             # 商户代码 
            'orderNumber'      => orderNumber,                                                         # 商户订单号, 一天内不可以重复
            'orderAmount'      => orderAmount,                                                         # 交易金额, 本域中不带小数点 参阅 6.15

            'version'          => options[:version] || '1.0.0',                                        # 版本号
            'charset'          => options[:charset] || 'UTF-8',                                        # 字符编码, GBK, UTF-8
            'transType'        => options[:transType] || '01',                                         # 消费类型 01: 消费

            'backEndUrl'       => options[:backEndUrl],                                                # 通知 URL
            'frontEndUrl'      => options[:frontEndUrl] || options[:backEndUrl],                       # 前台通知 URL
            'acqCode'          => options[:acqCode],                                                   # 收单机构代码
            'orderTime'        => options[:orderTime] || Time.current.strftime('%Y%m%d%H%m%S'),        # 交易开始日期时间, GMT+8
            'orderTimeout'     => options[:orderTimeout] || 1.hour.from_now.strftime('%Y%m%d%H%m%S'),   # 订单超时时间
          
            'orderCurrency'    => options[:orderCurrency] || '156',                                    # 交易币种 156: 人民币
            'orderDescription' => options[:orderDescription],                                          # 订单描述

            'merReserved'      => options[:merReserved],                                               # 商户保留域
            'reqReserved'      => options[:reqReserved],                                               # 请求方保留域
            'sysReserved'      => options[:sysReserved],                                               # 系统保留域
          }

          @req_qstring = sign! @req_params
        end

      end

      class Query
        include BaseRequestResponse

        def initialize(orderNumber, orderTime, transType = '01', options = {})
          @uri = URI.parse('http://202.101.25.178:8080/gateway/merchant/query')

          @req_params = {
            'merId'            => ACCOUNT,                                                             # 商户代码 
            'orderNumber'      => orderNumber,                                                         # 商户订单号, 一天内不可以重复
            'orderTime'        => orderTime,                                                           # 交易开始日期时间, GMT+8
            'transType'        => transType,                                                           # 消费类型 01: 消费

            'version'          => options[:version] || '1.0.0',                                        # 版本号
            'charset'          => options[:charset] || 'UTF-8',                                        # 字符编码, GBK, UTF-8
          
            'merReserved'      => options[:merReserved],                                               # 商户保留域
            'sysReserved'      => options[:sysReserved],                                               # 系统保留域
          }

          @req_qstring = sign! @req_params
        end
        
      end

      class Notification < OffsitePayments::Notification
        def complete?
          params['']
        end

        def item_id
          params['']
        end

        def transaction_id
          params['']
        end

        # When was this payment received by the client.
        def received_at
          params['']
        end

        def payer_email
          params['']
        end

        def receiver_email
          params['']
        end

        def security_key
          params['']
        end

        # the money amount we received in X.2 decimal.
        def gross
          params['']
        end

        # Was this a test transaction?
        def test?
          params[''] == 'test'
        end

        def status
          params['']
        end

        # Acknowledge the transaction to Unionpay. This method has to be called after a new
        # apc arrives. Unionpay will verify that all the information we received are correct and will return a
        # ok or a fail.
        #
        # Example:
        #
        #   def ipn
        #     notify = UnionpayNotification.new(request.raw_post)
        #
        #     if notify.acknowledge
        #       ... process order ... if notify.complete?
        #     else
        #       ... log possible hacking attempt ...
        #     end
        def acknowledge(authcode = nil)
          payload = raw

          uri = URI.parse(Unionpay.notification_confirmation_url)

          request = Net::HTTP::Post.new(uri.path)

          request['Content-Length'] = "#{payload.size}"
          request['User-Agent'] = "Active Merchant -- http://activemerchant.org/"
          request['Content-Type'] = "application/x-www-form-urlencoded"

          http = Net::HTTP.new(uri.host, uri.port)
          http.verify_mode    = OpenSSL::SSL::VERIFY_NONE unless @ssl_strict
          http.use_ssl        = true

          response = http.request(request, payload)

          # Replace with the appropriate codes
          raise StandardError.new("Faulty Unionpay result: #{response.body}") unless ["AUTHORISED", "DECLINED"].include?(response.body)
          response.body == "AUTHORISED"
        end

        private

        # Take the posted data and move the relevant data into a hash
        def parse(post)
          @raw = post.to_s
          for line in @raw.split('&')
            key, value = *line.scan( %r{^([A-Za-z0-9_.-]+)\=(.*)$} ).flatten
            params[key] = CGI.unescape(value.to_s) if key.present?
          end
        end
      end
    end
  end
end
