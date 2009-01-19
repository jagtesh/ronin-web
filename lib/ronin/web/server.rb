#
#--
# Ronin Web - A Ruby library for Ronin that provides support for web
# scraping and spidering functionality.
#
# Copyright (c) 2006-2009 Hal Brodigan (postmodern.mod3 at gmail.com)
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
#++
#

require 'rack'

module Ronin
  module Web
    class Server

      # Default interface to run the Web Server on
      HOST = '0.0.0.0'

      # Default port to run the Web Server on
      PORT = 8080

      #
      # Creates a new Web Server using the given configuration _block_.
      #
      def initialize(&block)
        @default = method(:not_found)

        @host_patterns = {}
        @path_patterns = {}

        @hosts = {}
        @paths = {}
        @directories = {}

        instance_eval(&block) if block
      end

      #
      # Returns the default host that the Web Server will be run on.
      #
      def Server.default_host
        @@default_host ||= HOST
      end

      #
      # Sets the default host that the Web Server will run on to the
      # specified _host_.
      #
      def Server.default_host=(host)
        @@default_host = host
      end

      #
      # Returns the default port that the Web Server will run on.
      #
      def Server.default_port
        @@default_port ||= PORT
      end

      #
      # Sets the default port the Web Server will run on to the specified
      # _port_.
      #
      def Server.default_port=(port)
        @@default_port = port
      end

      #
      # The Hash of the servers supported file extensions and their HTTP
      # Content-Types.
      #
      def Server.content_types
        @@content_types ||= {}
      end

      #
      # Registers a new content _type_ for the specified file _extensions_.
      #
      #   Server.content_type 'text/xml', ['xml', 'xsl']
      #
      def self.content_type(type,extensions)
        extensions.each { |ext| Server.content_types[ext] = type }

        return self
      end

      #
      # Creates a new Web Server object with the given _block_ and starts it
      # using the given _options_.
      #
      def self.start(options={},&block)
        self.new(&block).start(options)
      end

      #
      # Use the specified _block_ as the default route for all other
      # requests.
      #
      #   default do |env|
      #     [200, {'Content-Type' => 'text/html'}, 'lol train']
      #   end
      #
      def default(&block)
        @default = block
        return self
      end

      def hosts_like(pattern,&block)
        @host_patterns[pattern] = self.class.new(&block)
        return self
      end

      def paths_like(pattern,&block)
        @path_patterns[pattern] = block
        return self
      end

      def host(name,&block)
        @hosts[name] = self.class.new(&block)
        return self
      end

      #
      # Binds the specified URL _path_ to the given _block_.
      #
      #   bind '/secrets.xml' do |env|
      #     [200, {'Content-Type' => 'text/xml'}, "<secrets>Made you look.</secrets>"]
      #   end
      #
      def bind(path,&block)
        @paths[path] = block
        return self
      end

      #
      # Binds the specified URL directory _path_ to the given _block_.
      #
      #   dir '/downloads' do |env|
      #     [200, {'Content-Type' => 'text/xml'}, "Your somewhere inside the downloads directory"]
      #   end
      #
      def dir(path,&block)
        path += '/' unless path[-1..-1] == '/'

        @directories[path] = block
        return self
      end

      #
      # Binds the contents of the specified _file_ to the specified URL
      # _path_, using the given _options_.
      #
      #   file '/robots.txt', '/path/to/my_robots.txt'
      #
      def file(path,file,options={})
        file = File.expand_path(file)
        content_type = (options[:content_type] || content_type_for(file))

        bind(path) do |env|
          if File.file?(file)
            [200, {'Content-Type' => content_type_for(file)}, File.new(file)]
          else
            not_found(env)
          end
        end
      end

      #
      # Mounts the contents of the specified _directory_ to the given
      # prefix _path_.
      #
      #   mount '/download/', '/tmp/files/'
      #
      def mount(path,dir)
        dir = File.expand_path(dir)

        dir(path) do |env|
          http_path = File.expand_path(env['PATH_INFO'])
          sub_path = http_path.sub(path,'')
          absolute_path = File.join(dir,sub_path)

          return_file(absolute_path,env)
        end
      end

      #
      # Starts the server.
      #
      def start(options={})
        host = (options[:host] || Server.default_host)
        port = (options[:port] || Server.default_port)

        Rack::Handler::WEBrick.run(self, :Host => host, :Port => port)
        return self
      end

      #
      # The method which receives all requests.
      #
      def call(env)
        http_host = env['HTTP_HOST']
        http_path = env['PATH_INFO']

        if http_host
          @host_patterns.each do |pattern,server|
            if http_host.match(pattern)
              return server.call(env)
            end
          end

          if (server = @hosts[http_host])
            return server.call(env)
          end
        end

        if http_path
          @path_patterns.each do |pattern,block|
            if http_path.match(pattern)
              return block.call(env)
            end
          end

          @directories.each do |path,block|
            if http_path[0...path.length] == path
              return block.call(env)
            end
          end

          if (block = @paths[http_path])
            return block.call(env)
          end
        end

        return @default.call(env)
      end

      #
      # Returns the HTTP Content-Type for the specified file _extension_.
      #
      #   content_type('html')
      #   # => "text/html"
      #
      def content_type(extension)
        Server.content_types[extension] || 'application/x-unknown-content-type'
      end

      #
      # Returns the HTTP Content-Type for the specified _file_.
      #
      #   srv.content_type_for('file.html')
      #   # => "text/html"
      #
      def content_type_for(file)
        ext = File.extname(file).downcase

        return content_type(ext[1..-1])
      end

      protected

      content_type 'text/html', ['html', 'htm', 'xhtml']
      content_type 'text/css', ['css']
      content_type 'text/gif', ['gif']
      content_type 'text/jpeg', ['jpeg', 'jpg']
      content_type 'text/png', ['png']
      content_type 'image/x-icon', ['ico']
      content_type 'text/javascript', ['js']
      content_type 'text/xml', ['xml', 'xsl']
      content_type 'application/rss+xml', ['rss']
      content_type 'application/rdf+xml', ['rdf']
      content_type 'application/pdf', ['pdf']
      content_type 'application/doc', ['doc']
      content_type 'application/zip', ['zip']
      content_type 'text/plain', ['txt', 'conf', 'rb', 'py', 'h', 'c', 'hh', 'cc', 'hpp', 'cpp']

      #
      # Returns the HTTP 404 Not Found message for the requested path.
      #
      def not_found(env)
        path = env['PATH_INFO']

        return [404, {'Content-Type' => 'text/html'}, %{
<!DOCTYPE HTML PUBLIC "-//IETF//DTD HTML 2.0//EN">
<html>
  <head>
    <title>404 Not Found</title>
  <body>
    <h1>Not Found</h1>
    <p>The requested URL #{path.html_encode} was not found on this server.</p>
    <hr>
  </body>
</html>}]
      end

    end
  end
end