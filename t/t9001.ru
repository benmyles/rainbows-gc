use Rainbows::Sendfile
run lambda { |env|
  path = "#{Dir.pwd}/random_blob"
  [ 200,
    {
      'X-Sendfile' => path,
      'Content-Type' => 'application/octet-stream'
    },
    []
  ]
}
