# -*- encoding: binary -*-
# :enddoc:

module Rainbows::Epoll::Client

  include Rainbows::EvCore
  APP = Rainbows.server.app
  Server = Rainbows::Epoll::Server
  IN = SleepyPenguin::Epoll::IN | SleepyPenguin::Epoll::ET
  OUT = SleepyPenguin::Epoll::OUT | SleepyPenguin::Epoll::ET
  KATO = {}
  KATO.compare_by_identity if KATO.respond_to?(:compare_by_identity)
  KEEPALIVE_TIMEOUT = Rainbows.keepalive_timeout
  EP = Rainbows::Epoll::EP
  @@last_expire = Time.now

  def self.expire
    return if ((now = Time.now) - @@last_expire) < 1.0
    if (ot = KEEPALIVE_TIMEOUT) >= 0
      ot = now - ot
      KATO.delete_if { |client, time| time < ot and client.timeout! }
    end
    @@last_expire = now
  end

  # only call this once
  def epoll_once
    @wr_queue = [] # may contain String, ResponsePipe, and StreamFile objects
    post_init
    on_readable
    rescue => e
      handle_error(e)
  end

  def on_readable
    case rv = kgio_tryread(16384, RBUF)
    when String
      on_read(rv)
      return if @wr_queue[0] || closed?
    when :wait_readable
      KATO[self] = @@last_expire if :headers == @state
      return EP.set(self, IN)
    else
      break
    end until :close == @state
    close unless closed?
    rescue Errno::ECONNRESET
      close
    rescue IOError
  end

  def app_call input # called by on_read()
    @env[RACK_INPUT] = input
    @env[REMOTE_ADDR] = kgio_addr
    status, headers, body = APP.call(@env.merge!(RACK_DEFAULTS))
    ev_write_response(status, headers, body, @hp.next?)
  end

  def write_response_path(status, headers, body, alive)
    io = body_to_io(body)
    st = io.stat

    if st.file?
      defer_file(status, headers, body, alive, io, st)
    elsif st.socket? || st.pipe?
      chunk = stream_response_headers(status, headers, alive)
      stream_response_body(body, io, chunk)
    else
      # char or block device... WTF?
      write_response(status, headers, body, alive)
    end
  end

  # used for streaming sockets and pipes
  def stream_response_body(body, io, chunk)
    pipe = (chunk ? Rainbows::Epoll::ResponseChunkPipe :
                    Rainbows::Epoll::ResponsePipe).new(io, self, body)
    return @wr_queue << pipe if @wr_queue[0]
    stream_pipe(pipe) or return
    @wr_queue[0] or @wr_queue << Z
  end

  def ev_write_response(status, headers, body, alive)
    if body.respond_to?(:to_path)
      write_response_path(status, headers, body, alive)
    else
      write_response(status, headers, body, alive)
    end
    @state = alive ? :headers : :close
    on_read(Z) if alive && 0 == @wr_queue.size && 0 != @buf.size
  end

  def epoll_run
    if @wr_queue[0]
      on_writable
    else
      KATO.delete self
      on_readable
    end
  end

  def want_more
    Rainbows::Epoll::ReRun << self
  end

  def on_deferred_write_complete
    :close == @state and return close
    0 == @buf.size ? on_readable : on_read(Z)
  end

  def handle_error(e)
    msg = Rainbows::Error.response(e) and kgio_trywrite(msg) rescue nil
    ensure
      close
  end

  def write_deferred(obj)
    Rainbows::StreamFile === obj ? stream_file(obj) : stream_pipe(obj)
  end

  # writes until our write buffer is empty or we block
  # returns true if we're done writing everything
  def on_writable
    obj = @wr_queue.shift

    case rv = String === obj ? kgio_trywrite(obj) : write_deferred(obj)
    when nil
      obj = @wr_queue.shift or return on_deferred_write_complete
    when String
      obj = rv # retry
    when :wait_writable # Strings and StreamFiles only
      @wr_queue.unshift(obj)
      EP.set(self, OUT)
      return
    when :deferred
      return
    end while true
    rescue => e
      handle_error(e)
  end

  def write(buf)
    unless @wr_queue[0]
      case rv = kgio_trywrite(buf)
      when nil
        return # all written
      when String
        buf = rv # retry
      when :wait_writable
        @wr_queue << buf.dup # >3-word 1.9 strings are copy-on-write
        return EP.set(self, OUT)
      end while true
    end
    @wr_queue << buf.dup # >3-word 1.9 strings are copy-on-write
  end

  def close
    @wr_queue.each { |x| x.respond_to?(:close) and x.close rescue nil }
    super
    on_close
  end

  def on_close
    KATO.delete(self)
    Server.decr
  end

  def timeout!
    close
    true
  end

  def defer_file(status, headers, body, alive, io, st)
    if r = sendfile_range(status, headers)
      status, headers, range = r
      write_headers(status, headers, alive)
      range and defer_file_stream(range[0], range[1], io, body)
    else
      write_headers(status, headers, alive)
      defer_file_stream(0, st.size, io, body)
    end
  end

  # returns +nil+ on EOF, :wait_writable if the client blocks
  def stream_file(sf) # +sf+ is a Rainbows::StreamFile object
    case n = trysendfile(sf, sf.offset, sf.count)
    when Integer
      sf.offset += n
      0 == (sf.count -= n) and return sf.close
    else
      return n # :wait_writable or nil
    end while true
    rescue
      sf.close
      raise
  end

  def defer_file_stream(offset, count, io, body)
    sf = Rainbows::StreamFile.new(offset, count, io, body)
    unless @wr_queue[0]
      stream_file(sf) or return
    end
    @wr_queue << sf
    EP.set(self, OUT)
  end

  # this alternates between a push and pull model from the pipe -> client
  # to avoid having too much data in userspace on either end.
  def stream_pipe(pipe)
    case buf = pipe.tryread
    when String
      write(buf)
      if @wr_queue[0]
        # client is blocked on write, client will pull from pipe later
        EP.delete pipe
        @wr_queue << pipe
        EP.set(self, OUT)
        return :deferred
      end
      # continue looping...
    when :wait_readable
      # pipe blocked on read, let the pipe push to the client in the future
      EP.delete self
      EP.set(pipe, IN)
      return :deferred
    else # nil => EOF
      return pipe.close # nil
    end while true
    rescue => e
      pipe.close
      raise
  end
end
