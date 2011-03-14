# -*- encoding: binary -*-
# :enddoc:
# This class handles the Unicorn fchmod heartbeat mechanism
# in Coolio-based concurrency models to prevent the master
# process from killing us unless we're blocked.  This class
# will also detect and execute the graceful exit if triggered
# by SIGQUIT
class Rainbows::Coolio::Heartbeat < Coolio::TimerWatcher
  KATO = Rainbows::Coolio::KATO
  CONN = Rainbows::Coolio::CONN

  def on_timer
    if (ot = Rainbows.keepalive_timeout) >= 0
      ot = Time.now - ot
      KATO.delete_if { |client, time| time < ot and client.timeout? }
    end
    exit if (! Rainbows.tick && CONN.size <= 0)
  end
end
