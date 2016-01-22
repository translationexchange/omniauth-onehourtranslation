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

      attr_accessor :user_uuid

      option :client_options, {
        :site           => 'https://sandbox6.onehourtranslation.com/api',
        :authorize_url  => 'https://sandbox6.onehourtranslation.com/oauth/authorize',
        :token_url      => 'https://sandbox6.onehourtranslation.com/oauth/access'
      }

      option :name, 'onehourtranslation'

      option :access_token_options, {
        :header_format => 'OAuth %s',
        :param_name => 'access_token'
      }

      def request_phase
        redirect client.auth_code.authorize_url({:return_endpoint => callback_url}.merge(authorize_params))
      end

      def authorize_params
        super.tap do |params|
          params.merge!(:partner_uuid => options.client_id)
        end
      end

      def build_access_token
        verifier = request.params['authorization_token']
        self.user_uuid = request.params['user_uuid']
        client.auth_code.get_token(verifier, {:return_endpoint => callback_url}.merge(token_params.to_hash(:symbolize_keys => true)), deep_symbolize(options.auth_token_params))
      end

      uid { raw_info['id'] }
      
      info do
        prune!({
          'id'             => raw_info['id'],
          'display_name'   => raw_info['display_name'],
          'first_name'     => raw_info['first_name'],
          'last_name'      => raw_info['last_name'],
          'email'          => raw_info['email'],
          'gender'         => raw_info['gender'],
          'mugshot'        => raw_info['mugshot']
        })
      end
      
      extra do 
        { 'user' =>  prune!(raw_info) }
      end
      
      def raw_info
        @raw_info ||= access_token.get("/v2/account?user_uuid=#{user_uuid}").parsed
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
