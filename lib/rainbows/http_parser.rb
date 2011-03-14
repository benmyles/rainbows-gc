# -*- encoding: binary -*-
# :enddoc:
# avoid modifying Unicorn::HttpParser
class Rainbows::HttpParser < Unicorn::HttpParser
  def self.quit
    alias_method :next?, :never!
  end

  def never!
    false
  end
end
