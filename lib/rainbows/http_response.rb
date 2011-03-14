# -*- encoding: binary -*-
# :enddoc:
# deprecated, use Rainbows::Response instead
# Cramp 0.11 relies on this, and is only activated by Cramp
if defined?(Cramp) && defined?(Rainbows::EventMachine::Client)
  class Rainbows::HttpResponse
    # dummy method for Cramp to alias_method_chain
    def self.write(client, response, out)
    end
  end

  module Rainbows::EventMachine::CrampSocket
    def em_write_response(response, alive = false)
      if websocket?
        write web_socket_upgrade_data
        web_socket_handshake!
        response[1] = nil # disable response headers
      end
      super
    end
  end

  class Rainbows::EventMachine::Client
    include Rainbows::EventMachine::CrampSocket
  end
end
