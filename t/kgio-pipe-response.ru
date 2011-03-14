# must be run without Rack::Lint since that clobbers to_path
use Rainbows::DevFdResponse
run(lambda { |env|
  io = case env["rainbows.model"].to_s
  when /Fiber/
    Rainbows::Fiber::IO::Pipe
  else
    Kgio::Pipe
  end.popen('cat random_blob', 'rb')

  [ 200,
    {
      'Content-Length' => ::File.stat('random_blob').size.to_s,
      'Content-Type' => 'application/octet-stream',
    },
    io
  ]
})
