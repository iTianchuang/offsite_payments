# -*- coding: utf-8 -*-
module OffsitePayments #:nodoc:
  module Integrations #:nodoc:
    module Upop
      mattr_accessor :service_url

      self.service_url = Setting.upop.pay_url
      class Helper < OffsitePayments::Helper

        # 互联网商户接入接口规范 表 4 消费交易请求消息
        mapping :version,                'version'            # 接口名称
        mapping :charset,                'charset'            # 合作者身份ID

        # signMethod
        # signature

        mapping :transType,              'transType'          # 交易类型
        mapping :merAbbr,                'merAbbr'            # 商户名称
        mapping :merId,                  'merId'              # 商户代码

        mapping :backEndUrl,             'backEndUrl'         # 通知 URL
        mapping :fronEndUrl,             'frontEndUrl'        # 返回 URL
        mapping :acqCode,                'acqCode'            # 收单机构代码
        mapping :orderTime,              'orderTime'          # 交易开始日期时间 
        mapping :orderNumber,            'orderNumber'        # 商户订单号
        mapping :commodityName,          'commodityName'      # 商品名称
        mapping :commodityUrl,           'commodityUrl'       # 商品URL
        mapping :commodityUnitPrice,     'commodityUnitPrice' # 商品单价
        mapping :commodityQuantity,      'commodityQuantity'  # 商品数量
        mapping :transferFee,            'transferFee'        # 运输费用
        mapping :commodityDiscount,      'commodityDiscount'  # 优惠信息
        mapping :orderAmount,            'orderAmount'        # 交易金额
        mapping :orderCurrency,          'orderCurrency'      # 交易币种
        mapping :customerName,           'cutomerName'        # 持卡人姓名
        mapping :defaultPayType,         'defaultpayType'     # 默认支付方式
        mapping :defaultBankNumber,      'defaultBankNumber'  # 默认银行编码
        mapping :transTimeout,           'transTimeout'       # 交易超时时间
        mapping :customerIp,             'customerIp'         # 持卡人IP
        mapping :origQid,                'origQid'            # 原始交易流水号
        mapping :merReserved,            'merReserved'        # 商户保留域

        include UnionpayCommon::BaseRequestResponse

        def sign
          @req_qstring = sign! @fields, KEY.to_s

          add_field('signature', @fields["signature"])

          add_field('signMethod', @fields["signMethod"])
          nil
        end
      end

      class Query
        include UnionpayCommon::BaseRequestResponse

        def initialize(orderNumber, orderTime, transType = '01', options = {})
          @key = KEY
          @uri = URI.parse QUERY_URL

          @req_params = {
            'version'          => options[:version] || '1.0.0',      # 版本号
            'charset'          => options[:charset] || 'UTF-8',      # 字符编码, GBK, UTF-8

            'transType'        => transType,                         # 消费类型 01: 消费

            'merId'            => ACCOUNT,                           # 商户代码 
            'orderNumber'      => orderNumber,                       # 商户订单号, 一天内不可以重复
            'orderTime'        => orderTime,                         # 交易开始日期时间, GMT+8
            
            'merReserved'      => options[:merReserved]              # 商户保留域
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
          respCode
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
         'respTime',            # 交易完成时间
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
          verify? params, KEY
        end
      end
    end
  end
end
