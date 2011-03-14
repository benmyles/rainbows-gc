# -*- encoding: binary -*-
# :enddoc:
#
# a self-sufficient Queue implementation for Fiber-based concurrency
# models.  This requires no external scheduler, so it may be used with
# Revactor as well as FiberSpawn and FiberPool.
class Rainbows::Fiber::Queue < Struct.new(:queue, :waiters)
  def initialize(queue = [], waiters = [])
    # move elements of the Queue into an Array
    if queue.class.name == "Queue"
      queue = queue.length.times.map { queue.pop }
    end
    super queue, waiters
  end

  def shift
    # ah the joys of not having to deal with race conditions
    if queue.empty?
      waiters << Fiber.current
      Fiber.yield
    end
    queue.shift
  end

  def <<(obj)
    queue << obj
    blocked = waiters.shift and blocked.resume
    queue # not quite 100% compatible but no-one's looking :>
  end
end
