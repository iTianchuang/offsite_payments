# -*- coding: utf-8 -*-
module OffsitePayments #:nodoc:
  module Integrations #:nodoc:
    module Upop

      mattr_accessor :service_url
      self.service_url = 'https://www.example.com'

      class Helper < OffsitePayments::Helper
        # TODO
      end

      class Query
        include UnionpayCommon::BaseRequestResponse

        def initialize(orderNumber, orderTime, transType = '01', options = {})
          @key = KEY
          @uri = URI.parse QUERY_URL

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

          @req_qstring = sign! @req_params, @key
        end
        
      end

      class Notification < OffsitePayments::Notification
        include UnionpayCommon::Sign

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

        # Acknowledge the transaction to UPMP. This method has to be called after a new
        # apc arrives. UPMP will verify that all the information we received are correct and will return a
        # ok or a fail.
        #
        # Example:
        #
        #   def ipn
        #     notify = Notification.new(request.raw_post)
        #
        #     if notify.acknowledge
        #       ... process order ... if notify.complete?
        #     else
        #       ... log possible hacking attempt ...
        #     end
        def acknowledge
          verify_sign! params, KEY
        end
      end
    end
  end
end
