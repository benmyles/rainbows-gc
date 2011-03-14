#\-E none
# can't use non-compatible middleware that doesn't pass "deferered?" calls
#
# used for testing deferred actions for Merb and possibly other frameworks
# ref: http://brainspl.at/articles/2008/04/18/deferred-requests-with-merb-ebb-and-thin

class DeferredApp < Struct.new(:app)
  def deferred?(env)
    env["PATH_INFO"] == "/deferred"
  end

  def call(env)
    env["rack.multithread"] or raise RuntimeError, "rack.multithread not true"
    body = "#{Thread.current.inspect}\n"
    headers = {
      "Content-Type" => "text/plain",
      "Content-Length" => body.size.to_s,
    }
    [ 200, headers, [ body ] ]
  end
end

run DeferredApp.new
