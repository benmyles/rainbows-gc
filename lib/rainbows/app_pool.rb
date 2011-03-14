# -*- encoding: binary -*-

require 'thread'

# Rack middleware to limit application-level concurrency independently
# of network conncurrency in \Rainbows!   Since the +worker_connections+
# option in \Rainbows! is only intended to limit the number of
# simultaneous clients, this middleware may be used to limit the
# number of concurrent application dispatches independently of
# concurrent clients.
#
# Instead of using M:N concurrency in \Rainbows!, this middleware
# allows M:N:P concurrency where +P+ is the AppPool +:size+ while
# +M+ remains the number of +worker_processes+ and +N+ remains the
# number of +worker_connections+.
#
#   rainbows master
#    \_ rainbows worker[0]
#    |  \_ client[0,0]------\      ___app[0]
#    |  \_ client[0,1]-------\    /___app[1]
#    |  \_ client[0,2]-------->--<       ...
#    |  ...                __/    `---app[P]
#    |  \_ client[0,N]----/
#    \_ rainbows worker[1]
#    |  \_ client[1,0]------\      ___app[0]
#    |  \_ client[1,1]-------\    /___app[1]
#    |  \_ client[1,2]-------->--<       ...
#    |  ...                __/    `---app[P]
#    |  \_ client[1,N]----/
#    \_ rainbows worker[M]
#       \_ client[M,0]------\      ___app[0]
#       \_ client[M,1]-------\    /___app[1]
#       \_ client[M,2]-------->--<       ...
#       ...                __/    `---app[P]
#       \_ client[M,N]----/
#
# AppPool should be used if you want to enforce a lower value of +P+
# than +N+.
#
# AppPool has no effect on the Rev or EventMachine concurrency models
# as those are single-threaded/single-instance as far as application
# concurrency goes.  In other words, +P+ is always +one+ when using
# Rev or EventMachine.  As of \Rainbows! 0.7.0, it is safe to use with
# Revactor and the new FiberSpawn and FiberPool concurrency models.
#
# Since this is Rack middleware, you may load this in your Rack
# config.ru file and even use it in threaded servers other than
# \Rainbows!
#
#   use Rainbows::AppPool, :size => 30
#   map "/lobster" do
#     run Rack::Lobster.new
#   end
#
# You may to load this earlier or later in your middleware chain
# depending on the concurrency/copy-friendliness of your middleware(s).
class Rainbows::AppPool < Struct.new(:pool, :re)

  # +opt+ is a hash, +:size+ is the size of the pool (default: 6)
  # meaning you can have up to 6 concurrent instances of +app+
  # within one \Rainbows! worker process.  We support various
  # methods of the +:copy+ option: +dup+, +clone+, +deep+ and +none+.
  # Depending on your +app+, one of these options should be set.
  # The default +:copy+ is +:dup+ as is commonly seen in existing
  # Rack middleware.
  def initialize(app, opt = {})
    self.pool = Queue.new
    (1...(opt[:size] || 6)).each do
      pool << case (opt[:copy] || :dup)
      when :none then app
      when :dup then app.dup
      when :clone then app.clone
      when :deep then Marshal.load(Marshal.dump(app)) # unlikely...
      else
        raise ArgumentError, "unsupported copy method: #{opt[:copy].inspect}"
      end
    end
    pool << app # the original
  end

  # Rack application endpoint, +env+ is the Rack environment
  def call(env) # :nodoc:

    # we have to do this check at call time (and not initialize)
    # because of preload_app=true and models being changeable with SIGHUP
    # fortunately this is safe for all the reentrant (but not multithreaded)
    # classes that depend on it and a safe no-op for multithreaded
    # concurrency models
    self.re ||= begin
      case env["rainbows.model"]
      when :FiberSpawn, :FiberPool, :Revactor, :NeverBlock,
           :RevFiberSpawn, :CoolioFiberSpawn
        self.pool = Rainbows::Fiber::Queue.new(pool)
      end
      true
    end

    app = pool.shift
    app.call(env)
    ensure
      pool << app
  end
end
