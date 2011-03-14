use Rack::ContentLength
use Rack::ContentType
use Rainbows::AppPool, :size => ENV['APP_POOL_SIZE'].to_i
class Sleeper
  def call(env)
    Rainbows.sleep(1)
    [ 200, {}, [ "#{object_id}\n" ] ]
  end
end
run Sleeper.new
