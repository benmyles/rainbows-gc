use Rack::ContentLength
use Rack::ContentType, 'text/plain'
use Rainbows::ThreadTimeout, :timeout => 1, :threshold => -1
run lambda { |env|
  if env["PATH_INFO"] =~ %r{/([\d\.]+)\z}
    Rainbows.sleep($1.to_f)
  end
  [ 200, [], [ "HI\n" ] ]
}
