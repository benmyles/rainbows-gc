use Rack::ContentLength
use Rack::ContentType
run lambda { |env| [ 200, {}, [ env.inspect << "\n" ] ] }
