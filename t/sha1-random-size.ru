# SHA1 checksum generator
require 'digest/sha1'
use Rack::ContentLength
cap = 16384
app = lambda do |env|
  /\A100-continue\z/i =~ env['HTTP_EXPECT'] and
    return [ 100, {}, [] ]
  digest = Digest::SHA1.new
  input = env['rack.input']
  case env["PATH_INFO"]
  when "/gets_read_mix"
    warn "GETS_READ_MIX #{env['HTTP_TRANSFER_ENCODING'].inspect}"
    if buf = input.gets
      warn "input.rbuf: #{input.instance_variable_get(:@rbuf).inspect}"
      begin
        digest.update(buf)
        warn "buf.size : #{buf.size}"
      end while input.read(rand(cap), buf)
    end
  when "/each"
    input.each { |buf| digest.update(buf) }
  else
    if buf = input.read(rand(cap))
      begin
        raise "#{buf.size} > #{cap}" if buf.size > cap
        digest.update(buf)
      end while input.read(rand(cap), buf)
    end
  end

  [ 200, {'Content-Type' => 'text/plain'}, [ digest.hexdigest << "\n" ] ]
end
run app
