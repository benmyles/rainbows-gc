# -*- encoding: binary -*-
# :enddoc:
# used to wrap a BasicSocket to use with +q+ for all writes
# this is compatible with IO.select
class Rainbows::WriterThreadSpawn::Client < Struct.new(:to_io, :q, :thr)
  include Rainbows::SocketProxy
  include Rainbows::ProcessClient
  include Rainbows::WorkerYield

  CUR = {} # :nodoc:

  module Methods
    def write_body_each(body)
      q << [ :write_body_each, body ]
    end

    def write_response_close(status, headers, body, alive)
      to_io.instance_variable_set(:@hp, @hp) # XXX ugh
      Rainbows::SyncClose.new(body) { |sync_body|
        q << [ :write_response, status, headers, sync_body, alive ]
      }
    end

    if IO.respond_to?(:copy_stream) || IO.method_defined?(:trysendfile)
      def write_response(status, headers, body, alive)
        self.q ||= queue_writer
        if body.respond_to?(:close)
          write_response_close(status, headers, body, alive)
        elsif body.respond_to?(:to_path)
          write_response_path(status, headers, body, alive)
        else
          super
        end
      end

      def write_body_file(body, range)
        q << [ :write_body_file, body, range ]
      end

      def write_body_stream(body)
        q << [ :write_body_stream, body ]
      end
    else # each-only body response
      def write_response(status, headers, body, alive)
        self.q ||= queue_writer
        if body.respond_to?(:close)
          write_response_close(status, headers, body, alive)
        else
          super
        end
      end
    end # each-only body response
  end # module Methods
  include Methods

  def self.quit
    CUR.delete_if do |t,q|
      q << nil
      Rainbows.tick
      t.alive? ? t.join(0.01) : true
    end until CUR.empty?
  end

  def queue_writer
    until CUR.size < MAX
      CUR.delete_if { |t,_|
        t.alive? ? t.join(0) : true
      }.size >= MAX and worker_yield
    end

    q = Queue.new
    self.thr = Thread.new(to_io, q) do |io, q|
      while op = q.shift
        begin
          op, *rest = op
          case op
          when String
            io.kgio_write(op)
          when :close
            io.close unless io.closed?
            break
          else
            io.__send__ op, *rest
          end
        rescue => e
          Rainbows::Error.write(io, e)
        end
      end
      CUR.delete(Thread.current)
    end
    CUR[thr] = q
  end

  def write(buf)
    (self.q ||= queue_writer) << buf
  end

  def close
    if q
      q << :close
    else
      to_io.close
    end
  end

  def closed?
    to_io.closed?
  end
end
