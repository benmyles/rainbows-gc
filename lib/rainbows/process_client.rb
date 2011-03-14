# -*- encoding: binary -*-
# :enddoc:
module Rainbows::ProcessClient
  include Rainbows::Response
  include Rainbows::Const

  NULL_IO = Unicorn::HttpRequest::NULL_IO
  RACK_INPUT = Unicorn::HttpRequest::RACK_INPUT
  IC = Unicorn::HttpRequest.input_class

  def process_loop
    @hp = hp = Rainbows::HttpParser.new
    kgio_read!(16384, buf = hp.buf) or return

    begin # loop
      until env = hp.parse
        timed_read(buf2 ||= "") or return
        buf << buf2
      end

      set_input(env, hp)
      env[REMOTE_ADDR] = kgio_addr
      status, headers, body = APP.call(env.merge!(RACK_DEFAULTS))

      if 100 == status.to_i
        write(EXPECT_100_RESPONSE)
        env.delete(HTTP_EXPECT)
        status, headers, body = APP.call(env)
      end
      write_response(status, headers, body, alive = @hp.next?)
    end while alive
  # if we get any error, try to write something back to the client
  # assuming we haven't closed the socket, but don't get hung up
  # if the socket is already closed or broken.  We'll always ensure
  # the socket is closed at the end of this function
  rescue => e
    handle_error(e)
  ensure
    close unless closed?
  end

  def handle_error(e)
    Rainbows::Error.write(self, e)
  end

  def set_input(env, hp)
    env[RACK_INPUT] = 0 == hp.content_length ? NULL_IO : IC.new(self, hp)
  end
end
