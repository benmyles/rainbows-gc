# SHA1 checksum generator
bs = ENV['bs'] ? ENV['bs'].to_i : 4096
require 'digest/md5'
use Rack::ContentLength
app = lambda do |env|
  /\A100-continue\z/i =~ env['HTTP_EXPECT'] and
    return [ 100, {}, [] ]
  digest = Digest::MD5.new
  input = env['rack.input']
  if buf = input.read(bs)
    begin
      digest.update(buf)
    end while input.read(bs, buf)
  end

  expect = env['HTTP_CONTENT_MD5']
  readed = [ digest.digest ].pack('m').strip
  body = "expect=#{expect}\nreaded=#{readed}\n"
  status = expect == readed ? 200 : 500

  [ status, {'Content-Type' => 'text/plain'}, [ body ] ]
end
run app
