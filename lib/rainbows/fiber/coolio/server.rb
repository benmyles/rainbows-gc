# -*- encoding: binary -*-
# :enddoc:
class Rainbows::Fiber::Coolio::Server < Coolio::IOWatcher
  def to_io
    @io
  end

  def initialize(io)
    @io = io
    super(self, :r)
  end

  def close
    detach if attached?
    @io.close
  end

  def on_readable
    return if Rainbows.cur >= MAX
    c = @io.kgio_tryaccept and Fiber.new { process(c) }.resume
  end

  def process(io)
    Rainbows.cur += 1
    io.process_loop
  ensure
    Rainbows.cur -= 1
  end
end
