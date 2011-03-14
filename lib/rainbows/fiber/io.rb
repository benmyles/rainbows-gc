# -*- encoding: binary -*-

# A Fiber-aware IO class, gives users the illusion of a synchronous
# interface that yields away from the current Fiber whenever
# the underlying descriptor is blocked on reads or write
#
# This is a stable, legacy interface and should be preserved for all
# future versions of Rainbows!  However, new apps should use
# Rainbows::Fiber::IO::Socket or Rainbows::Fiber::IO::Pipe instead.

class Rainbows::Fiber::IO
  attr_accessor :to_io

  # :stopdoc:
  # see Rainbows::Fiber::IO::Compat for initialize implementation
  class << self
    alias :[] :new
  end
  # :startdoc:

  # no longer used internally within Rainbows!, only for compatibility
  def write_nonblock(buf)
    @to_io.write_nonblock(buf)
  end

  def kgio_addr
    @to_io.kgio_addr
  end

  # for wrapping output response bodies
  def each
    buf = readpartial(16384)
    yield buf
    yield buf while readpartial(16384, buf)
    rescue EOFError
      self
  end

  def closed?
    @to_io.closed?
  end

  def fileno
    @to_io.fileno
  end

  def write(buf)
    case rv = Kgio.trywrite(buf)
    when String
      buf = rv
    when :wait_writable
      kgio_wait_writable
    end until nil == rv
  end

  # used for reading headers (respecting keepalive_timeout)
  def timed_read(buf)
    expire = nil
    case rv = Kgio.tryread(@to_io, 16384, buf)
    when :wait_readable
      return if expire && expire < Time.now
      expire ||= read_expire
      kgio_wait_readable
    else
      return rv
    end while true
  end

  def readpartial(length, buf = "")
    case rv = Kgio.tryread(@to_io, length, buf)
    when nil
      raise EOFError, "end of file reached", []
    when :wait_readable
      kgio_wait_readable
    else
      return rv
    end while true
  end

  def kgio_read(*args)
    @to_io.kgio_read(*args)
  end

  def kgio_read!(*args)
    @to_io.kgio_read!(*args)
  end

  def kgio_trywrite(*args)
    @to_io.kgio_trywrite(*args)
  end

  autoload :Socket, 'rainbows/fiber/io/socket'
  autoload :Pipe, 'rainbows/fiber/io/pipe'
end

# :stopdoc:
require 'rainbows/fiber/io/methods'
require 'rainbows/fiber/io/compat'
Rainbows::Client.__send__(:include, Rainbows::Fiber::IO::Methods)
class Rainbows::Fiber::IO
  include Rainbows::Fiber::IO::Compat
  include Rainbows::Fiber::IO::Methods
  alias_method :wait_readable, :kgio_wait_readable
  alias_method :wait_writable, :kgio_wait_writable
end
