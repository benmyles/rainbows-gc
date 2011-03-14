use Rack::ContentLength
use Rack::ContentType, "text/plain"
run lambda { |env|
  t = Process.times
  [ 200, {}, [ "utime=#{t.utime} stime=#{t.stime}" ] ]
}
