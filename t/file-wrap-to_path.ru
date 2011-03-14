# must be run without Rack::Lint since that clobbers to_path
class Wrapper < Struct.new(:app)
  def call(env)
    status, headers, body = app.call(env)
    body = Body.new(body) if body.respond_to?(:to_path)
    [ status, headers, body ]
  end

  class Body < Struct.new(:body)
    def to_path
      body.to_path
    end

    def each(&block)
      body.each(&block)
    end

    def close
      ::File.open(ENV['fifo'], 'wb') { |fp| fp.puts "CLOSING" }
    end
  end
end
use Wrapper
run Rack::File.new(Dir.pwd)
