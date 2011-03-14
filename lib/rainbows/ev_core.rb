# -*- encoding: binary -*-
# :enddoc:
# base module for evented models like Rev and EventMachine
module Rainbows::EvCore
  include Rainbows::Const
  include Rainbows::Response
  NULL_IO = Unicorn::HttpRequest::NULL_IO
  HttpParser = Rainbows::HttpParser
  autoload :CapInput, 'rainbows/ev_core/cap_input'
  RBUF = ""
  Z = "".freeze

  # Apps may return this Rack response: AsyncResponse = [ -1, {}, [] ]
  ASYNC_CALLBACK = "async.callback".freeze
  ASYNC_CLOSE = "async.close".freeze

  def write_async_response(response)
    status, headers, body = response
    if alive = @hp.next?
      # we can't do HTTP keepalive without Content-Length or
      # "Transfer-Encoding: chunked", and the async.callback stuff
      # isn't Rack::Lint-compatible, so we have to enforce it here.
      headers = Rack::Utils::HeaderHash.new(headers) unless Hash === headers
      alive = headers.include?(Content_Length) ||
              !!(%r{\Achunked\z}i =~ headers[Transfer_Encoding])
    end
    @deferred = nil
    ev_write_response(status, headers, body, alive)
  end

  def post_init
    @hp = HttpParser.new
    @env = @hp.env
    @buf = @hp.buf
    @state = :headers # [ :body [ :trailers ] ] :app_call :close
  end

  # graceful exit, like SIGQUIT
  def quit
    @state = :close
  end

  def want_more
  end

  def handle_error(e)
    msg = Rainbows::Error.response(e) and write(msg)
    ensure
      quit
  end

  # returns whether to enable response chunking for autochunk models
  def stream_response_headers(status, headers, alive)
    headers = Rack::Utils::HeaderHash.new(headers) unless Hash === headers
    if headers.include?(Content_Length)
      rv = false
    else
      rv = !!(headers[Transfer_Encoding] =~ %r{\Achunked\z}i)
      rv = false unless @env["rainbows.autochunk"]
    end
    write_headers(status, headers, alive)
    rv
  end

  def prepare_request_body
    # since we don't do streaming input, we have no choice but
    # to take over 100-continue handling from the Rack application
    if @env[HTTP_EXPECT] =~ /\A100-continue\z/i
      write(EXPECT_100_RESPONSE)
      @env.delete(HTTP_EXPECT)
    end
    @input = mkinput
    @hp.filter_body(@buf2 = "", @buf)
    @input << @buf2
    on_read(Z)
  end

  # TeeInput doesn't map too well to this right now...
  def on_read(data)
    case @state
    when :headers
      @buf << data
      @hp.parse or return want_more
      @state = :body
      if 0 == @hp.content_length
        app_call NULL_IO # common case
      else # nil or len > 0
        prepare_request_body
      end
    when :body
      if @hp.body_eof?
        if @hp.content_length
          @input.rewind
          app_call @input
        else
          @state = :trailers
          on_read(data)
        end
      elsif data.size > 0
        @hp.filter_body(@buf2, @buf << data)
        @input << @buf2
        on_read(Z)
      else
        want_more
      end
    when :trailers
      if @hp.trailers(@env, @buf << data)
        @input.rewind
        app_call @input
      else
        want_more
      end
    end
    rescue => e
      handle_error(e)
  end

  ERROR_413_RESPONSE = "HTTP/1.1 413 Request Entity Too Large\r\n\r\n"

  def err_413(msg)
    write(ERROR_413_RESPONSE)
    quit
    # zip back up the stack
    raise IOError, msg, []
  end

  TmpIO = Unicorn::TmpIO
  CBB = Unicorn::TeeInput.client_body_buffer_size

  def io_for(bytes)
    bytes <= CBB ? StringIO.new("") : TmpIO.new
  end

  def mkinput
    max = Rainbows.max_bytes
    len = @hp.content_length
    if len
      if max && (len > max)
        err_413("Content-Length too big: #{len} > #{max}")
      end
      io_for(len)
    else
      max ? CapInput.new(io_for(max), self, max) : TmpIO.new
    end
  end
end
