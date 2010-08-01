#
# Ronin Web - A Ruby library for Ronin that provides support for web
# scraping and spidering functionality.
#
# Copyright (c) 2006-2010 Hal Brodigan (postmodern.mod3 at gmail.com)
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#

require 'ronin/web/middleware/base'

require 'ipaddr'

module Ronin
  module Web
    module Middleware
      #
      # A Rack middleware for filtering requests based on what IP address
      # the request was sent from.
      #
      #     use Ronin::Web::Middleware::IPFilter do |filter|
      #       filter.map '212.18.45.0/24', BannedApp
      #       filter.map '192.168.0.0/16' do |request|
      #         response ['Nothing here'], 404
      #       end
      #     end
      #
      class IPFilter < Base

        # The rules of the IP filter
        attr_reader :rules

        #
        # Creates a new IP Filter middleware.
        #
        # @param [#call] app
        #   The application that the ip filter sits in front of.
        #
        # @param [Hash] options
        #   Additional options.
        #
        # @option options [Hash{IPAddr => #call}] :ips
        #   The IP addresses and applications.
        #
        # @yield [ip_filter]
        #   If a block is given, it will be passed the newly created IP
        #   filter middleware.
        #
        # @yieldparam [IPFilter] ip_filter
        #   The new IP filter middleware object.
        #
        # @since 0.2.2
        #
        def initialize(app,options={},&block)
          @rules = {}

          if options[:ips]
            options[:ips].each { |ip,app| map(ip,app) }
          end

          super(app,options,&block)
        end

        #
        # Routes requests coming from a given IP address.
        #
        # @param [IPAddr] ip
        #   The IP address or IP range.
        #
        # @param [#call] app
        #   The application that will receive requests from the specified
        #   IP addresses.
        #
        # @yield [request]
        #   If a block is given, it will receive requests for the specified
        #   IP addresses.
        #
        # @yieldparam [Rack::Request] request
        #   A request coming from the specified IP addresses.
        #
        # @return [IPFilter]
        #   The IP filter middleware.
        #
        # @example
        #   filter.map '210.18.0.0/16', BannedApp
        #
        # @example
        #   filter.map '210.18.0.0/16' do |request|
        #     response ['Banned!']
        #   end
        #
        # @since 0.2.2
        #
        def map(ip,app=nil,&block)
          ip = IPAddr.new(ip) unless ip.kind_of?(IPAddr)

          @rules[ip] = (app || block)
          return self
        end

        #
        # Filters requests based on what IP address they are sent from.
        #
        # @param [Hash, Rack::Request] env
        #   An incoming request.
        #
        # @return [Rack::Response]
        #   A response.
        #
        # @since 0.2.2
        #
        def call(env)
          remote_ip = env['REMOTE_ADDR']

          @rules.each do |ip,app|
            return app.call(env) if ip.include?(remote_ip)
          end

          super(env)
        end

      end
    end
  end
end
