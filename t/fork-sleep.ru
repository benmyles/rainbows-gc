# we do not want Rack::Lint or anything to protect us
use Rack::ContentLength
use Rack::ContentType, "text/plain"
trap(:CHLD) { $stderr.puts Process.waitpid2(-1).inspect }
map "/" do
  time = ENV["nr"] || '15'
  pid = fork { exec('sleep', time) }
  run lambda { |env| [ 200, {}, [ "#{pid}\n" ] ] }
end
