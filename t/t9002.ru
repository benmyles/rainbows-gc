require 'rainbows/server_token'
require 'rack/lobster'
use Rainbows::ServerToken
run Rack::Lobster.new
