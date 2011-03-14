# -*- encoding: binary -*-
# :enddoc:
module Rainbows::EventMachine::ResponsePipe
  # garbage avoidance, EM always uses this in a single thread,
  # so a single buffer for all clients will work safely
  RBUF = Rainbows::EvCore::RBUF

  def initialize(client)
    @client = client
  end

  def notify_readable
    case data = Kgio.tryread(@io, 16384, RBUF)
    when String
      @client.write(data)
    when :wait_readable
      return
    when nil
      return detach
    end while true
  end

  def unbind
    @client.next!
    @io.close unless @io.closed?
  end
end
