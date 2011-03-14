# -*- encoding: binary -*-
# :enddoc:
module Rainbows::Const

  RAINBOWS_VERSION = '3.1.0'

  include Unicorn::Const

  RACK_DEFAULTS = Unicorn::HttpRequest::DEFAULTS.update({
    "SERVER_SOFTWARE" => "Rainbows! #{RAINBOWS_VERSION}",

    # using the Rev model, we'll automatically chunk pipe and socket objects
    # if they're the response body.  Unset by default.
    # "rainbows.autochunk" => false,
  })

  RACK_INPUT = Unicorn::HttpRequest::RACK_INPUT
  REMOTE_ADDR = Unicorn::HttpRequest::REMOTE_ADDR
end
