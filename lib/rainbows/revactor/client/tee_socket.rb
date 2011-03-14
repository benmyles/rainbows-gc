# -*- encoding: binary -*-
# :enddoc:
#
# Revactor Sockets do not implement readpartial, so we emulate just
# enough to avoid mucking with TeeInput internals.  Fortunately
# this code is not heavily used so we can usually avoid the overhead
# of adding a userspace buffer.
class Rainbows::Revactor::Client::TeeSocket
  def initialize(socket)
    # IO::Buffer is used internally by Rev which Revactor is based on
    # so we'll always have it available
    @socket, @rbuf = socket, IO::Buffer.new
  end

  def leftover
    @rbuf.read
  end

  # Revactor socket reads always return an unspecified amount,
  # sometimes too much
  def kgio_read(length, dst = "")
    return dst.replace("") if length == 0

    # always check and return from the userspace buffer first
    @rbuf.size > 0 and return dst.replace(@rbuf.read(length))

    # read off the socket since there was nothing in rbuf
    tmp = @socket.read

    # we didn't read too much, good, just return it straight back
    # to avoid needlessly wasting memory bandwidth
    tmp.size <= length and return dst.replace(tmp)

    # ugh, read returned too much
    @rbuf << tmp[length, tmp.size]
    dst.replace(tmp[0, length])
    rescue EOFError
  end

  # just proxy any remaining methods TeeInput may use
  def close
    @socket.close
  end
end
