# -*- encoding: binary -*-
# :enddoc:
module Rainbows::ReverseProxy::Synchronous
  UpstreamSocket = Rainbows::ReverseProxy::UpstreamSocket

  def each_block(input)
    buf = ""
    while input.read(16384, buf)
      yield buf
    end
  end

  def call(env)
    input = prepare_input!(env)
    req = build_headers(env, input)
    sock = UpstreamSocket.new(pick_upstream(env))
    sock.write(req)
    each_block(input) { |buf| sock.kgio_write(buf) } if input
    Kcar::Response.new(sock).rack
  end
end
