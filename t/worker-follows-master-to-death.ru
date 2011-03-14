use Rack::ContentLength
headers = { 'Content-Type' => 'text/plain' }
run lambda { |env|
  /\A100-continue\z/i =~ env['HTTP_EXPECT'] and return [ 100, {}, [] ]
  env['rack.input'].read

  case env["PATH_INFO"]
  when %r{/sleep/(\d+)}
    Rainbows.sleep($1.to_i)
  end
  [ 200, headers, [ "#$$\n" ] ]
}
