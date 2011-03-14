# must be run without Rack::Lint since that clobbers to_path
class CloseWrapper < Struct.new(:to_io)
  def each(&block)
    to_io.each(&block)
  end

  def close
    ::File.open(ENV['fifo'], 'wb') do |fp|
      fp.syswrite("CLOSING #{to_io}\n")
      if to_io.respond_to?(:close) && ! to_io.closed?
        to_io.close
      end
    end
  end
end
use Rainbows::DevFdResponse
run(lambda { |env|
  io = IO.popen('cat random_blob', 'rb')
  [ 200,
    {
      'Content-Length' => ::File.stat('random_blob').size.to_s,
      'Content-Type' => 'application/octet-stream',
    },
    CloseWrapper[io] ]
})
