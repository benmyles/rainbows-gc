# -*- encoding: binary -*-
# :enddoc:
class Rainbows::EvCore::CapInput

  def initialize(io, client, max)
    @io, @client, @bytes_left = io, client, max
  end

  def <<(buf)
    if (@bytes_left -= buf.size) < 0
      @io.close
      @client.err_413("chunked request body too big")
    end
    @io << buf
  end

  def gets; @io.gets; end
  def each; @io.each { |x| yield x }; end
  def size; @io.size; end
  def rewind; @io.rewind; end
  def read(*args); @io.read(*args); end
end
