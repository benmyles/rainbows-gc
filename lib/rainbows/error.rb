# -*- encoding: binary -*-
# :enddoc:
module Rainbows::Error

  # if we get any error, try to write something back to the client
  # assuming we haven't closed the socket, but don't get hung up
  # if the socket is already closed or broken.  We'll always ensure
  # the socket is closed at the end of this function
  def self.write(io, e)
    msg = response(e) and Kgio.trywrite(io, msg)
    rescue
  end

  def self.app(e)
    Rainbows.server.logger.error "app error: #{e.inspect}"
    Rainbows.server.logger.error e.backtrace.join("\n")
    rescue
  end

  def self.listen_loop(e)
    Rainbows.alive or return
    Rainbows.server.logger.error "listen loop error: #{e.inspect}."
    Rainbows.server.logger.error e.backtrace.join("\n")
    rescue
  end

  def self.response(e)
    case e
    when EOFError, Errno::ECONNRESET, Errno::EPIPE, Errno::EINVAL,
         Errno::EBADF, Errno::ENOTCONN
      # swallow error if client shuts down one end or disconnects
    when Unicorn::HttpParserError
      Rainbows::Const::ERROR_400_RESPONSE # try to tell the client they're bad
    when IOError # HttpParserError is an IOError
    else
      app(e)
      Rainbows::Const::ERROR_500_RESPONSE
    end
  end
end
