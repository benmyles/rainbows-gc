# -*- encoding: binary -*-
# :enddoc:
#
class Rainbows::Epoll::ResponseChunkPipe < Rainbows::Epoll::ResponsePipe
  def tryread
    @io or return

    case rv = super
    when String
      "#{rv.size.to_s(16)}\r\n#{rv}\r\n"
    when nil
      close
      "0\r\n\r\n"
    else
      rv
    end
  end
end
