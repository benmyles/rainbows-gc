# SHA1 checksum generator
bs = ENV['bs'] ? ENV['bs'].to_i : 16384
require 'digest/sha1'
use Rack::ContentLength
app = lambda do |env|
  /\A100-continue\z/i =~ env['HTTP_EXPECT'] and
    return [ 100, {}, [] ]
  digest = Digest::SHA1.new
  input = env['rack.input']
  if buf = input.read(bs)
    begin
      digest.update(buf)
    end while input.read(bs, buf)
  end

  [ 200, {'Content-Type' => 'text/plain'}, [ digest.hexdigest << "\n" ] ]
end
run app
