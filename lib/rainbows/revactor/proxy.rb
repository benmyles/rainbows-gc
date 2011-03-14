# -*- encoding: binary -*-
# :enddoc:
# Generic IO wrapper for proxying pipe and socket objects
# this behaves more like Rainbows::Fiber::IO than anything,
# making it highly suitable for proxying data from pipes/sockets
class Rainbows::Revactor::Proxy < Rev::IO
  def initialize(io)
    @receiver = Actor.current
    super(io)
    attach(Rev::Loop.default)
  end

  def close
    if @_io
      super
      @_io = nil
    end
  end

  def each
    # when yield-ing, Revactor::TCP#write may raise EOFError
    # (instead of Errno::EPIPE), so we need to limit the rescue
    # to just readpartial and let EOFErrors during yield bubble up
    begin
      buf = readpartial(INPUT_SIZE)
    rescue EOFError
      break
    end while yield(buf) || true
  end

  # this may return more than the specified length, Rainbows! won't care...
  def readpartial(length)
    @receiver = Actor.current
    enable if attached? && ! enabled?

    Actor.receive do |filter|
      filter.when(T[:rainbows_io_input, self]) do |_, _, data|
        return data
      end

      filter.when(T[:rainbows_io_closed, self]) do
        raise EOFError, "connection closed"
      end
    end
  end

  def on_close
    @receiver << T[:rainbows_io_closed, self]
  end

  def on_read(data)
    @receiver << T[:rainbows_io_input, self, data ]
    disable
  end
end
