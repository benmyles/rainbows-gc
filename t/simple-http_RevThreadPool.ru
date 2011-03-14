use Rack::ContentLength
use Rack::ContentType
run lambda { |env|
  if env['rack.multithread'] && env['rainbows.model'] == :RevThreadPool
    [ 200, {}, [ env.inspect << "\n" ] ]
  else
    raise "rack.multithread is false"
  end
}
