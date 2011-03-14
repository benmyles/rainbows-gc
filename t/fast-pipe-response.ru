# must be run without Rack::Lint since that clobbers to_path
use Rainbows::DevFdResponse
run(lambda { |env|
  [ 200,
    {
      'Content-Length' => ::File.stat('random_blob').size.to_s,
      'Content-Type' => 'application/octet-stream',
    },
    IO.popen('cat random_blob', 'rb') ]
})
