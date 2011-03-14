# -*- encoding: binary -*-

require 'actor'

# Actor concurrency model for Rubinius.  We can't seem to get message
# passing working right, so we're throwing a Mutex into the mix for
# now.  Hopefully somebody can fix things for us.  Currently, this is
# exactly the same as the ThreadSpawn model since we don't use the
# message passing capabilities of the Actor model (and even then
# it wouldn't really make sense since Actors in Rubinius are just
# Threads underneath and our ThreadSpawn model is one layer of
# complexity less.
#
# This is different from the Revactor one which is not prone to race
# conditions within the same process at all (since it uses Fibers).
module Rainbows::ActorSpawn
  include Rainbows::ThreadSpawn

  # runs inside each forked worker, this sits around and waits
  # for connections and doesn't die until the parent dies (or is
  # given a INT, QUIT, or TERM signal)
  def worker_loop(worker) # :nodoc:
    Rainbows::Const::RACK_DEFAULTS["rack.multithread"] = true # :(
    init_worker_process(worker)
    accept_loop(Actor)
  end
end
