use Rack::Chunked
use Rainbows::DevFdResponse
run lambda { |env|
  io = IO.popen('for i in 0 1 2 3 4 5 6 7 8 9; do date; sleep 1; done', 'rb')
  [
    200,
    {
      'Content-Type' => 'text/plain',
    },
    io
  ].freeze
}
