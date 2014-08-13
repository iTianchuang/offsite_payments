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
            'version'          => options[:version] || '1.0.0',                                        # 版本号
            'charset'          => options[:charset] || 'UTF-8',                                        # 字符编码, GBK, UTF-8

            'transType'        => transType,                                                           # 消费类型 01: 消费

            'merId'            => ACCOUNT,                                                             # 商户代码 
            'orderNumber'      => orderNumber,                                                         # 商户订单号, 一天内不可以重复
            'orderTime'        => orderTime,                                                           # 交易开始日期时间, GMT+8
            
            'merReserved'      => options[:merReserved],                                               # 商户保留域
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

        # 互联网商户接入接口规范 表5 消费交易应答消息
        # 字符串, number, 状态 型参数
        [
         'version',             # 版本号
         'charset',             # 字符编码
         'transType',           # 交易类型
         'respCode',            # 响应码
         'respMsg',             # 响应信息
         'merAbbr',             # 商户名称
         'merId',               # 商户代码
         'orderNumber',         # 商户订单号
         'traceNumber',         # 系统跟踪号
         'qid',                 # 交易流水号
         'orderAmount',         # 交易金额
         'orderCurrency',       # 交易币种
         'settleAmount',        # 清算金额
         'settleCurency',       # 清算币种
         'exchangeRate',        # 清算汇率
         'cupReserved'          # 系统保留域
        ].each do |param|
          self.class_eval <<-EOF
              def #{param}
                params['#{param}']
              end
            EOF
        end

        # Date型参数
        [
         'traceTime',           # 系统跟踪时间
         'respTime'             # 交易完成时间
         'settleDate',          # 清算日期
         'exchangeDate'         # 兑换日期
        ].each do |param|
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
