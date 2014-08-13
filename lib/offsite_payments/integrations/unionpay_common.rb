# -*- coding: utf-8 -*-
module OffsitePayments #:nodoc:
  module Integrations #:nodoc:
    module UnionpayCommon

      def self.notification(post)
        Notification.new(post)
      end

      module Sign

        # 订单推送请求 签名 附录B报文签名
        def sign!(params, key)
          params.delete('signMethod')
          params.delete('signature')
          params.compact!                                                                             # 空值不参与签名计算

          query_string_not_sign = params.sort.collect{ |s|s[0].to_s + "=" + s[1].to_s }.join("&")  # 被签名字符串中的按照key值做升序排序

          query_string_for_sign = "#{query_string_not_sign}&#{Digest::MD5.hexdigest(key)}"
          signature = Digest::MD5.hexdigest query_string_for_sign                                          # MD5签名

          params['signMethod'] = 'MD5'
          params['signature'] = signature

          query_string = params.sort.collect{ |s|s[0].to_s + "=" + s[1].to_s }.join("&")
          query_string = "#{query_string}&#{Digest::MD5.hexdigest(key)}"

          query_string
        end

        # 通知返回时验证签名
        def verify_sign(params, key)
          p = params.dup
          sign_method = p.delete("signMethod")
          signature = p.delete("signature")

          query_string = p.sort.collect{ |s|s[0].to_s + "=" + s[1].to_s }.join("&")  

          Digest::MD5.hexdigest("#{query_string}&#{Digest::MD5.hexdigest(key)}") == signature.downcase
        end

        def verify_sign!(params, key)
          raise StandardError.new("Faulty unionpay result: ILLEGAL_SIGN") unless verify_sign resp_params, key
        end
      end

      module BaseRequestResponse
        include Sign

        attr_accessor :key
        attr_reader :uri
        attr_reader :req_params, :req_qstring, :resp_params, :resp

        def send
          @http = Net::HTTP.new(self.uri.host, self.uri.port)
          @resp = @http.post self.uri.path, self.req_qstring
          @resp_params = parse @resp.body

          verify_sign! @resp_params, @key
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
    end
  end
end
