# -*- encoding: binary -*-
# :enddoc:

# Middleware that will run the app dispatch in a separate thread.
# This middleware is automatically loaded by Rainbows! when using
# EventMachine and if the app responds to the +deferred?+ method.
class Rainbows::EventMachine::TryDefer < Struct.new(:app)
  # shortcuts
  ASYNC_CALLBACK = Rainbows::EvCore::ASYNC_CALLBACK

  def initialize(app)
    # the entire app becomes multithreaded, even the root (non-deferred)
    # thread since any thread can share processes with others
    Rainbows::Const::RACK_DEFAULTS['rack.multithread'] = true
    super
  end

  def call(env)
    if app.deferred?(env)
      EM.defer(proc { catch(:async) { app.call(env) } }, env[ASYNC_CALLBACK])
      # all of the async/deferred stuff breaks Rack::Lint :<
      nil
    else
      app.call(env)
    end
  end
end
