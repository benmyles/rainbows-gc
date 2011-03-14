# -*- encoding: binary -*-
# :enddoc:
module Rainbows::EventMachine::ResponseChunkPipe
  include Rainbows::EventMachine::ResponsePipe

  def unbind
    @client.write("0\r\n\r\n")
    super
  end

  def notify_readable
    case data = Kgio.tryread(@io, 16384, RBUF)
    when String
      @client.write("#{data.size.to_s(16)}\r\n")
      @client.write(data)
      @client.write("\r\n")
    when :wait_readable
      return
    when nil
      return detach
    end while true
  end
end
