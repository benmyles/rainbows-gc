# -*- encoding: utf-8 -*-
module T0016
  CHUNK = '©' * 1024 * 1024
  BODY = (1..50).map { CHUNK }
  HEADER = {
    # BODY.inject(0) { |m,c| m += c.bytesize }.to_s,
    'Content-Length' => '104857600',
    'Content-Type' => 'text/plain',
  }

  def self.call(env)
    [ 200, HEADER, BODY ]
  end
end
$0 == __FILE__ and T0016::BODY.each { |x| $stdout.syswrite(x) }
