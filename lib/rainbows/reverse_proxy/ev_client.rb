# -*- encoding: binary -*-
# :enddoc:
require 'tempfile'
module Rainbows::ReverseProxy::EvClient
  include Rainbows::ReverseProxy::Synchronous
  AsyncCallback = "async.callback"
  CBB = Unicorn::TeeInput.client_body_buffer_size
  Content_Length = "Content-Length"
  Transfer_Encoding = "Transfer-Encoding"

  def receive_data(buf)
    if @body
      @body << buf
    else
      response = @parser.headers(@headers, @rbuf << buf) or return
      if (cl = @headers[Content_Length] && cl.to_i > CBB) ||
         (%r{\bchunked\b} =~ @headers[Transfer_Encoding])
        @body = LargeBody.new("")
        @body << @rbuf
        @response = response << @body
      else
        @body = @rbuf.dup
        @response = response << [ @body ]
      end
    end
  end

  class LargeBody < Tempfile
    def each
      buf = ""
      rewind
      while read(16384, buf)
        yield buf
      end
    end

    alias close close!
  end
end
