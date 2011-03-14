# -*- encoding: binary -*-
# :enddoc:
#
# Used to make Rainbows::Fiber::IO behave like 0.97.0 and earlier
module Rainbows::Fiber::IO::Compat
  def initialize(io, fiber = Fiber.current)
    @to_io, @f = io, fiber
  end

  def close
    @to_io.close
  end
end
