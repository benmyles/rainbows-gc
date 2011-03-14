# -*- encoding: binary -*-
# :enddoc:
#
class Rainbows::Epoll::ResponsePipe
  attr_reader :io
  alias to_io io
  RBUF = Rainbows::EvCore::RBUF
  EP = Rainbows::Epoll::EP

  def initialize(io, client, body)
    @io, @client, @body = io, client, body
  end

  def epoll_run
    return close if @client.closed?
    @client.stream_pipe(self) or @client.on_deferred_write_complete
    rescue => e
      close
      @client.handle_error(e)
  end

  def close
    @io or return
    EP.delete self
    @body.respond_to?(:close) and @body.close
    @io = @body = nil
  end

  def tryread
    Kgio.tryread(@io, 16384, RBUF)
  end
end
