# -*- encoding: binary -*-
# :enddoc:
# TODO: handle large responses without having it all in memory
module Rainbows::ReverseProxy::EventMachine
  class Backend < EM::Connection
    include Rainbows::ReverseProxy::EvClient # provides receive_data

    # +addr+ is a packed sockaddr, so it can be either a UNIX or TCP socket
    def initialize(env)
      @env = env
      @rbuf = ""
      @parser = Kcar::Parser.new
      @response = @body = nil
      @headers = Rack::Utils::HeaderHash.new
    end

    # prevents us from sending too much at once and OOM-ing on large uploads
    def stream_input(input)
      if buf = input.read(16384)
        send_data buf
        EM.next_tick { stream_input(input) }
      end
    end

    def on_write_complete
      if @input
        buf = @input.read(16384, @junk) and return write(buf)
        @input = nil
      end
    end

    def unbind
      @env[AsyncCallback].call(@response || Rainbows::ReverseProxy::E502)
    end
  end

  UpstreamSocket = Rainbows::ReverseProxy::UpstreamSocket
  def call(env)
    input = prepare_input!(env)
    io = UpstreamSocket.start(pick_upstream(env))
    sock = EM.attach(io, Backend, env)
    sock.send_data(build_headers(env, input))
    sock.stream_input(input) if input
    throw :async
  end
end
