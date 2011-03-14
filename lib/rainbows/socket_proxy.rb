# -*- encoding: binary -*-
# :enddoc:
#
module Rainbows::SocketProxy
  def kgio_addr
    to_io.kgio_addr
  end

  def kgio_read(size, buf = "")
    to_io.kgio_read(size, buf)
  end

  def kgio_read!(size, buf = "")
    to_io.kgio_read!(size, buf)
  end

  def kgio_trywrite(buf)
    to_io.kgio_trywrite(buf)
  end

  def timed_read(buf)
    to_io.timed_read(buf)
  end
end
