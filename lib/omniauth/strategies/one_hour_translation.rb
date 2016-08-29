#--
# Permission is hereby granted, free of charge, to any person obtaining
# a copy of this software and associated documentation files (the
# "Software"), to deal in the Software without restriction, including
# without limitation the rights to use, copy, modify, merge, publish,
# distribute, sublicense, and/or sell copies of the Software, and to
# permit persons to whom the Software is furnished to do so, subject to
# the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
# NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
# LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
# OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
# WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
#++

require 'omniauth-oauth2'

module OmniAuth
  module Strategies
    class OneHourTranslation < OmniAuth::Strategies::OAuth2

      attr_accessor :account_uuid

      # TODO: remove this check once the servers are switched
      if defined?(Rails) and %w(test sandbox development dev).include?(Rails.env.to_s)
        option :client_options, {
          :site           => 'https://sandbox.onehourtranslation.com/api/2/',
          :authorize_url  => 'https://sandbox.onehourtranslation.com/oauth/authorize',
          :token_url      => 'https://sandbox.onehourtranslation.com/api/2/oauth/token'
        }
      else
        option :client_options, {
          :site           => 'https://www.onehourtranslation.com/api/2/',
          :authorize_url  => 'https://www.onehourtranslation.com/oauth/authorize',
          :token_url      => 'https://www.onehourtranslation.com/api/2/oauth/token'
        }
      end

      option :name, 'onehourtranslation'

      option :access_token_options, {
        :mode => :query,
        :param_name => 'access_token'
      }


      # TODO: deal with situations when client declines the authorization

      # All this because OHT does not return token in a standard form
      def build_access_token
        self.account_uuid = request.params['user_uuid']

        params = {
          :client_id => options.client_id,
          :user_uuid => account_uuid,
          :public_key => options['public_key'],
          :secret_key => options['secret_key']
        }.merge(token_params.to_hash(:symbolize_keys => true))

        params = {'grant_type' => 'authorization_code', 'code' => request.params['code']}.merge(params)
        access_token_opts = deep_symbolize(options.auth_token_params)

        opts = {:raise_errors => false, :parse => params.delete(:parse)}
        if client.options[:token_method] == :post
          headers = params.delete(:headers)
          opts[:body] = params
          opts[:headers] =  {'Content-Type' => 'application/x-www-form-urlencoded'}
          opts[:headers].merge!(headers) if headers
        else
          opts[:params] = params
        end

        response = client.request(client.options[:token_method], client.token_url, opts)
        data = {
            'access_token' => response.parsed['results']['access_token'],
            'expires_in' => response.parsed['results']['expires'],
        }

        ::OAuth2::AccessToken.from_hash(client, data.merge(access_token_opts))
      end

      uid { raw_info['uuid'] }
      
      info do
        prune!(raw_info)
      end
      
      extra do 
        { 'user' =>  prune!(raw_info) }
      end
      
      def raw_info
        @raw_info ||= begin
          access_token.options[:mode] = :query
          access_token.options[:param_name] = :access_token
          data = access_token.get('account/contact', {:parse => :json}).parsed
          data['results'].merge({
              'uuid' => account_uuid
          })
        end
      end

      private

      def prune!(hash)
        hash.delete_if do |_, value|
          prune!(value) if value.is_a?(Hash)
          value.nil? || (value.respond_to?(:empty?) && value.empty?)
        end
      end

    end
  end
end

OmniAuth.config.add_camelization 'onehourtranslation', 'OneHourTranslation'
