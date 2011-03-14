# -*- encoding: binary -*-
# :enddoc:
require 'rainbows/coolio_support'
require 'rainbows/fiber'
require 'rainbows/fiber/io'

module Rainbows::Fiber::Coolio
  autoload :Heartbeat, 'rainbows/fiber/coolio/heartbeat'
  autoload :Server, 'rainbows/fiber/coolio/server'
  autoload :Sleeper, 'rainbows/fiber/coolio/sleeper'
end
require 'rainbows/fiber/coolio/methods'
