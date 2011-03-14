# -*- encoding: binary -*-
# :enddoc:
class Rainbows::CoolioThreadSpawn::Client < Rainbows::Coolio::ThreadClient
  # MASTER will be set in worker_loop
  def app_dispatch
    Thread.new(self) { |client| MASTER << [ client, app_response ] }
  end
end
