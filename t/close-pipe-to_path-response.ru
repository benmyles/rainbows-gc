# must be run without Rack::Lint since that clobbers to_path
class MyMiddleware < Struct.new(:app)
  class Body < Struct.new(:body, :to_path)
    def each(&block); body.each(&block); end
    def close
      c = body.respond_to?(:close)
      ::File.open(ENV['fifo'], 'wb') do |fp|
        fp.syswrite("CLOSING #{body.inspect} #{to_path} (#{c})\n")
      end
      body.close if c
    end
  end

  def call(env)
    status, headers, body = app.call(env)
    body.respond_to?(:to_path) and body = Body.new(body, body.to_path)
    [ status, headers, body ]
  end
end
use MyMiddleware
use Rainbows::DevFdResponse
run(lambda { |env|
  io = IO.popen('cat random_blob', 'rb')
  [ 200,
    {
      'Content-Length' => ::File.stat('random_blob').size.to_s,
      'Content-Type' => 'application/octet-stream',
    },
    io ]
})
