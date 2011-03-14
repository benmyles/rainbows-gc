use Rack::Chunked
use Rainbows::DevFdResponse
script = <<-EOF
for i in 0 1 2 3 4 5 6 7 8 9
do
	printf '1\r\n%s\r\n' $i
	sleep 1
done
printf '0\r\n\r\n'
EOF

run lambda { |env|
  env['rainbows.autochunk'] = false
  io = IO.popen(script, 'rb')
  [
    200,
    {
      'Content-Type' => 'text/plain',
      'Transfer-Encoding' => 'chunked',
    },
    io
  ].freeze
}
