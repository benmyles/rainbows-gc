# -*- encoding: binary -*-
# A Fiber-aware Socket class, gives users the illusion of a synchronous
# interface that yields away from the current Fiber whenever
# the underlying descriptor is blocked on reads or write
class Rainbows::Fiber::IO::Socket < Kgio::Socket
  include Rainbows::Fiber::IO::Methods
end
