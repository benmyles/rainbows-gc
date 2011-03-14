use Rack::ContentLength
use Rack::ContentType
run lambda { |env|
  if env['rack.multithread'] == false &&
    env['rainbows.model'] == :CoolioFiberSpawn
    [ 200, {}, [ Thread.current.inspect << "\n" ] ]
  else
    raise env.inspect
  end
}
