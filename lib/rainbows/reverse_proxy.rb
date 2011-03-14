# -*- encoding: binary -*-
# :enddoc:
require 'socket'
require 'thread'
require 'uri'
require 'kcar' # http://bogomips.org/kcar/ -- gem install kcar

# This is lightly tested and has an unstable configuration interface.
# ***** Do not rely on anything under the ReverseProxy namespace! *****
#
# A reverse proxy implementation for \Rainbows!  It is a Rack application
# compatible and optimized for most \Rainbows! concurrency models.
#
# It makes HTTP/1.0 connections without keepalive to backends, so
# it is only recommended for proxying to upstreams on the same LAN
# or machine.  It can proxy to TCP hosts as well as UNIX domain sockets.
#
# Currently it only does simple round-robin balancing and does not
# know to retry connections from failed backends.
#
# Buffering-behavior is currently dependent on the concurrency model selected:
#
# Fully-buffered (uploads and response bodies):
#    Coolio, EventMachine, NeverBlock, CoolioThreadSpawn, CoolioThreadPool
# If you're proxying to Unicorn, fully-buffered is the way to go.
#
# Buffered input only (uploads, but not response bodies):
#    ThreadSpawn, ThreadPool, FiberSpawn, FiberPool, CoolioFiberSpawn
#
# It is not recommended to use Base, WriterThreadSpawn or WriterThreadPool
# to host this application.  However, you may proxy to a backend running
# one of these concurrency models with a fully-buffering concurrency model.
#
# See the {example config}[link:examples/reverse_proxy.ru] for a sample
# configuration
#
# TODO: Revactor support
# TODO: Support HTTP trailers
# TODO: optional streaming input for synchronous
# TODO: error handling
#
# WARNING! this is only lightly tested and has no automated tests, yet!
class Rainbows::ReverseProxy
  autoload :MultiThread, 'rainbows/reverse_proxy/multi_thread'
  autoload :Synchronous, 'rainbows/reverse_proxy/synchronous'
  autoload :Coolio, 'rainbows/reverse_proxy/coolio'
  autoload :EventMachine, 'rainbows/reverse_proxy/event_machine'
  autoload :EvClient, 'rainbows/reverse_proxy/ev_client'

  HTTP_X_FORWARDED_FOR = "HTTP_X_FORWARDED_FOR"
  REMOTE_ADDR = "REMOTE_ADDR"
  REQUEST_METHOD = "REQUEST_METHOD"
  REQUEST_URI = "REQUEST_URI"
  CRLF = "\r\n"
  TR = %w(_ -)
  CONTENT_LENGTH = "CONTENT_LENGTH"
  HTTP_TRANSFER_ENCODING = "HTTP_TRANSFER_ENCODING"
  RackInput = "rack.input"
  E502 = [ 502, [ %w(Content-Length 0), %w(Content-Type text/plain) ], [] ]

  def initialize(opts)
    @lock = Mutex.new
    upstreams = opts[:upstreams]
    @upstreams = []
    upstreams.each do |url|
      url, cfg = *url if Array === url
      if url =~ %r{\Ahttp://}
        uri = URI.parse(url)
        host = uri.host =~ %r{\A\[([a-fA-F0-9:]+)\]\z} ? $1 : uri.host
        sockaddr = Socket.sockaddr_in(uri.port, host)
      else
        path = url.gsub(%r{\Aunix:}, "") # nginx compat
        %r{\A~} =~ path and path = File.expand_path(path)
        sockaddr = Socket.sockaddr_un(path)
      end
      ((cfg && cfg[:weight]) || 1).times { @upstreams << sockaddr }
    end
    @nr = 0
  end

  # detects the concurrency model at first run and replaces itself
  def call(env)
    if @lock.try_lock
      case model = env["rainbows.model"]
      when :EventMachine, :NeverBlock
        extend(EventMachine)
      when :Coolio, :CoolioThreadPool, :CoolioThreadSpawn
        extend(Coolio)
      when :RevFiberSpawn, :Rev, :RevThreadPool, :RevThreadSpawn
        warn "#{model} is not *well* supported with #{self.class}"
        warn "Switch to #{model.to_s.gsub(/Rev/, 'Coolio')}!"
        extend(Synchronous)
      when :Revactor
        warn "Revactor is not *well* supported with #{self.class} yet"
        extend(Synchronous)
      when :FiberSpawn, :FiberPool, :CoolioFiberSpawn
        extend(Synchronous)
        Synchronous::UpstreamSocket.
          __send__(:include, Rainbows::Fiber::IO::Methods)
      when :WriterThreadSpawn, :WriterThreadPool
        warn "#{model} is not recommended for use with #{self.class}"
        extend(Synchronous)
      else
        extend(Synchronous)
      end
      extend(MultiThread) if env["rack.multithread"]
      @lock.unlock
    else
      @lock.synchronize {} # wait for the first locker to finish
    end
    call(env)
  end

  # returns request headers for sending to the upstream as a string
  def build_headers(env, input)
    remote_addr = env[REMOTE_ADDR]
    xff = env[HTTP_X_FORWARDED_FOR]
    xff = xff ? "#{xff},#{remote_addr}" : remote_addr
    req = "#{env[REQUEST_METHOD]} #{env[REQUEST_URI]} HTTP/1.0\r\n" \
          "Connection: close\r\n" \
          "X-Forwarded-For: #{xff}\r\n"
    uscore, dash = *TR
    env.each do |key, value|
      %r{\AHTTP_(\w+)\z} =~ key or next
      key = $1
      next if %r{\A(?:VERSION|CONNECTION|KEEP_ALIVE|X_FORWARDED_FOR)\z}x =~ key
      key.tr!(uscore, dash)
      req << "#{key}: #{value}\r\n"
    end
    input and req << (input.respond_to?(:size) ?
                     "Content-Length: #{input.size}\r\n" :
                     "Transfer-Encoding: chunked\r\n")
    req << CRLF
  end

  def pick_upstream(env) # +env+ is reserved for future expansion
    @nr += 1
    @upstreams[@nr %= @upstreams.size]
  end

  def prepare_input!(env)
    if cl = env[CONTENT_LENGTH]
      size = cl.to_i
      size > 0 or return
    elsif %r{\Achunked\z}i =~ env.delete(HTTP_TRANSFER_ENCODING)
      # do people use multiple transfer-encodings?
    else
      return
    end

    input = env[RackInput]
    if input.respond_to?(:rewind)
      if input.respond_to?(:size)
        input.size # TeeInput-specific behavior
        return input
      else
        return SizedInput.new(input, size)
      end
    end
    tmp = size && size < 0x4000 ? StringIO.new("") : Unicorn::TmpIO.new
    each_block(input) { |x| tmp.syswrite(x) }
    tmp.rewind
    tmp
  end

  class SizedInput
    attr_reader :size

    def initialize(input, n)
      buf = ""
      if n == nil
        n = 0
        while input.read(16384, buf)
          n += buf.size
        end
        input.rewind
      end
      @input, @size = input, n
    end

    def read(*args)
      @input.read(*args)
    end
  end

  class UpstreamSocket < Kgio::Socket
    alias readpartial kgio_read!
  end
end
