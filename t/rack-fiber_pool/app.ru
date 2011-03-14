require 'rack/fiber_pool'
use Rack::FiberPool
use Rack::ContentLength
use Rack::ContentType, 'text/plain'
run lambda { |env|
  f = Fiber.current
  EM.add_timer(3) { f.resume }
  Fiber.yield
  [ 200, {}, [ "#{f}\n" ] ]
}
