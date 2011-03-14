# -*- encoding: binary -*-

# This concurrency model implements a single-threaded app dispatch
# with a separate thread pool for writing responses.
#
# Unlike most \Rainbows! concurrency models, WriterThreadPool is
# designed to run behind nginx just like Unicorn is.  This concurrency
# model may be useful for existing Unicorn users looking for more
# output concurrency than socket buffers can provide while still
# maintaining a single-threaded application dispatch (though if the
# response body is dynamically generated, it must be thread safe).
#
# For serving large or streaming responses, using more threads (via
# the +worker_connections+ setting) and setting "proxy_buffering off"
# in nginx is recommended.  If your application does not handle
# uploads, then using any HTTP-aware proxy like haproxy is fine.
# Using a non-HTTP-aware proxy will leave you vulnerable to
# slow client denial-of-service attacks.
module Rainbows::WriterThreadPool
  # :stopdoc:
  include Rainbows::Base
  autoload :Client, 'rainbows/writer_thread_pool/client'

  @@nr = 0
  @@q = nil

  def process_client(client) # :nodoc:
    @@nr += 1
    Client.new(client, @@q[@@nr %= @@q.size]).process_loop
  end

  def worker_loop(worker) # :nodoc:
    # we have multiple, single-thread queues since we don't want to
    # interleave writes from the same client
    qp = (1..worker_connections).map do |n|
      Rainbows::QueuePool.new(1) do |response|
        begin
          io, arg, *rest = response
          case arg
          when String
            io.kgio_write(arg)
          when :close
            io.close unless io.closed?
          else
            io.__send__(arg, *rest)
          end
        rescue => err
          Rainbows::Error.write(io, err)
        end
      end
    end

    @@q = qp.map { |q| q.queue }
    super(worker) # accept loop from Unicorn
    qp.each { |q| q.quit! }
  end
  # :startdoc:
end
