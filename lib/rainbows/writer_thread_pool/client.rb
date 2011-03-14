# -*- encoding: binary -*-
# :enddoc:
# used to wrap a BasicSocket to use with +q+ for all writes
# this is compatible with IO.select
class Rainbows::WriterThreadPool::Client < Struct.new(:to_io, :q)
  include Rainbows::SocketProxy
  include Rainbows::ProcessClient

  module Methods
    def write_body_each(body)
      q << [ to_io, :write_body_each, body ]
    end

    def write_response_close(status, headers, body, alive)
      to_io.instance_variable_set(:@hp, @hp) # XXX ugh
      Rainbows::SyncClose.new(body) { |sync_body|
        q << [ to_io, :write_response, status, headers, sync_body, alive ]
      }
    end

    if IO.respond_to?(:copy_stream) || IO.method_defined?(:trysendfile)
      def write_response(status, headers, body, alive)
        if body.respond_to?(:close)
          write_response_close(status, headers, body, alive)
        elsif body.respond_to?(:to_path)
          write_response_path(status, headers, body, alive)
        else
          super
        end
      end

      def write_body_file(body, range)
        q << [ to_io, :write_body_file, body, range ]
      end

      def write_body_stream(body)
        q << [ to_io, :write_body_stream, body ]
      end
    else # each-only body response
      def write_response(status, headers, body, alive)
        if body.respond_to?(:close)
          write_response_close(status, headers, body, alive)
        else
          super
        end
      end
    end # each-only body response
  end # module Methods
  include Methods

  def write(buf)
    q << [ to_io, buf ]
  end

  def close
    q << [ to_io, :close ]
  end

  def closed?
    to_io.closed?
  end
end
