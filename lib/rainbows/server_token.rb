# -*- encoding: binary -*-
module Rainbows

# An optional middleware to proudly display your usage of \Rainbows! in
# the "Server:" response header.  This means you can help tell the world
# you're using \Rainbows! and spread fun and joy all over the Internet!
#
#    ------ in your config.ru ------
#    require 'rainbows/server_token'
#    require 'rack/lobster'
#    use Rainbows::ServerToken
#    run Rack::Lobster.new
#
# If you're nervous about the exact version of \Rainbows! you're running,
# then you can actually specify anything you want:
#
#    use Rainbows::ServerToken, "netcat 1.0"
#

class ServerToken < Struct.new(:app, :token)

  # :stopdoc:
  #
  # Freeze constants as they're slightly faster when setting hashes
  SERVER = "Server".freeze

  def initialize(app, token = Const::RACK_DEFAULTS['SERVER_SOFTWARE'])
    super
  end

  def call(env)
    status, headers, body = app.call(env)
    headers = Rack::Utils::HeaderHash.new(headers) unless Hash === headers
    headers[SERVER] = token
    [ status, headers, body ]
  end
  # :startdoc:
end
end
