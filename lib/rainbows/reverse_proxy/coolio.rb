# -*- encoding: binary -*-
# :enddoc:
# TODO: handle large responses without having it all in memory
module Rainbows::ReverseProxy::Coolio
  LOOP = Cool.io::Loop.default

  class Backend < Cool.io::IO
    include Rainbows::ReverseProxy::EvClient

    def initialize(env, addr, input)
      @env = env
      @input = input
      @junk, @rbuf = "", ""
      @parser = Kcar::Parser.new
      @response = @body = nil
      @headers = Rack::Utils::HeaderHash.new
      super(UpstreamSocket.start(addr)) # kgio-enabled socket
    end

    def on_write_complete
      if @input
        buf = @input.read(16384, @junk) and return write(buf)
        @input = nil
      end
    end

    def on_readable
      # avoiding IO#read_nonblock since that's expensive in 1.9.2
      case buf = @_io.kgio_tryread(16384, @junk)
      when String
        receive_data(buf)
      when :wait_readable
        return
      when nil
        @env[AsyncCallback].call(@response)
        return close
      end while true # we always read until EAGAIN or EOF

      rescue => e
        case e
        when Errno::ECONNRESET
          @env[AsyncCallback].call(@response)
          return close
        when SystemCallError
        else
          logger = @env["rack.logger"]
          logger.error "#{e} #{e.message}"
          e.backtrace.each { |m| logger.error m }
        end
        @env[AsyncCallback].call(Rainbows::ReverseProxy::E502)
        close
    end
  end

  def call(env)
    input = prepare_input!(env)
    sock = Backend.new(env, pick_upstream(env), input).attach(LOOP)
    sock.write(build_headers(env, input))
    throw :async
  end
end
