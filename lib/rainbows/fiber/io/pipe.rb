# -*- encoding: binary -*-
# A Fiber-aware Pipe class, gives users the illusion of a synchronous
# interface that yields away from the current Fiber whenever
# the underlying descriptor is blocked on reads or write
class Rainbows::Fiber::IO::Pipe < Kgio::Pipe
  include Rainbows::Fiber::IO::Methods
end
