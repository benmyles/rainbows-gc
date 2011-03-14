# -*- encoding: binary -*-
# :enddoc:
module Rainbows::Revactor::Client::Methods
  if IO.method_defined?(:trysendfile)
    def write_body_file(body, range)
      body, client = body_to_io(body), @client
      sock = @client.instance_variable_get(:@_io)
      pfx = Revactor::TCP::Socket === client ? :tcp : :unix
      write_complete = T[:"#{pfx}_write_complete", client]
      closed = T[:"#{pfx}_closed", client]
      offset, count = range ? range : [ 0, body.stat.size ]
      case n = sock.trysendfile(body, offset, count)
      when Integer
        offset += n
        return if 0 == (count -= n)
      when :wait_writable
        # The @_write_buffer is empty at this point, trigger the
        # on_readable method which in turn triggers on_write_complete
        # even though nothing was written
        client.controller = Actor.current
        client.__send__(:enable_write_watcher)
        Actor.receive do |filter|
          filter.when(write_complete) {}
          filter.when(closed) { raise Errno::EPIPE }
        end
      else # nil
        return
      end while true
      ensure
        close_if_private(body)
    end
  end

  def handle_error(e)
    Revactor::TCP::ReadError === e or super
  end

  def write_response(status, headers, body, alive)
    super(status, headers, body, alive)
    alive && @ts and @hp.buf << @ts.leftover
  end

  def self.included(klass)
    klass.__send__ :alias_method, :write_body_stream, :write_body_each
  end
end
