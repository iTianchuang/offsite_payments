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
        attr_reader :req_params, :req_qstring, :resp_params, :resp

        def send
          @http = Net::HTTP.new(self.uri.host, self.uri.port)
          @resp = @http.post self.uri.path, self.req_qstring
          @resp_params = parse @resp.body

          raise StandardError.new("Response: ILLEGAL_SIGN") unless verify_sign resp_params
          @resp
        end

        private

        # 订单推送应答 (同步)
        def parse(resp)
          params = {}
          for line in resp.to_s.split('&')
            key, value = *line.scan( %r{^([A-Za-z0-9_.-]+)\=(.*)$} ).flatten
            params[key] = CGI.unescape(value.to_s) if key.present?
          end

          params
        end

      end

      class Helper < OffsitePayments::Helper
        # TODO
      end

      class Trade
        include BaseRequestResponse

        def initialize(orderNumber, orderAmount, backEndUrl, options = {})

          @uri = URI.parse('http://202.101.25.178:8080/gateway/merchant/trade')

          @req_params = {
            'merId'            => ACCOUNT,                                                             # 商户代码 
            'orderNumber'      => orderNumber,                                                         # 商户订单号, 一天内不可以重复
            'orderAmount'      => orderAmount,                                                         # 交易金额, 本域中不带小数点 参阅 6.15
            'backEndUrl'       => backEndUrl,                                                          # 通知 URL

            'acqCode'          => options[:acqCode],                                                   # 收单机构代码

            'version'          => options[:version] || '1.0.0',                                        # 版本号
            'charset'          => options[:charset] || 'UTF-8',                                        # 字符编码, GBK, UTF-8
            'transType'        => options[:transType] || '01',                                         # 消费类型 01: 消费
            'frontEndUrl'      => options[:frontEndUrl],                                               # 前台通知 URL

            'orderTime'        => options[:orderTime] || Time.current.strftime('%Y%m%d%H%m%S'),        # 交易开始日期时间, GMT+8
            'orderTimeout'     => options[:orderTimeout],                                              # 订单超时时间，默认1小时，若有设置, 则最大1小时
            
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
          '00' == self.status
        end

        def pending?
          '01' == self.status
        end

        def failed?
          '03' == self.status
        end

        def status              # 3. 商户后台接口 表6
          transStatus
        end

        # 字符串, number, 状态 型参数
        ['version', 'charset', 
         'transType', 'merId', 'transStatus', 'qn', 
         'respCode', 'respMsg',
         'orderNumber', 'exchangeRate',
         'settleAmount', 'settleCurency', 'settleDate',
         'merReserved', 'reqReserved', 'sysReserved'].each do |param|
          self.class_eval <<-EOF
              def #{param}
                params['#{param}']
              end
            EOF
        end

        # Date型参数
        ['exchangeDate', 'orderTime'].each do |param|
          self.class_eval <<-EOF
              def #{param}
                Time.parse params['#{param}']
              end
            EOF
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
        def acknowledge
          raise StandardError.new("Faulty unionpay result: ILLEGAL_SIGN") unless verify_sign params
          true
        end
      end
    end
  end
end
