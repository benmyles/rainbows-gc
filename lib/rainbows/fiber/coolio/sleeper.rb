# -*- encoding: binary -*-
# :enddoc:
class Rainbows::Fiber::Coolio::Sleeper < Coolio::TimerWatcher

  def initialize(seconds)
    @f = Fiber.current
    super(seconds, false)
    attach(Coolio::Loop.default)
    Fiber.yield
  end

  def on_timer
    @f.resume
  end
end
