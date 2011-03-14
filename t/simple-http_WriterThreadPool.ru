use Rack::ContentLength
use Rack::ContentType
run lambda { |env|
  if env['rack.multithread'] && env['rainbows.model'] == :WriterThreadPool
    [ 200, {}, [ Thread.current.inspect << "\n" ] ]
  else
    raise "rack.multithread is false"
  end
}
