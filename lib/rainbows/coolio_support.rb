# -*- encoding: binary -*-
# :enddoc:
begin
  require "coolio"
  Coolio::VERSION >= "1.0.0" or abort "cool.io >= 1.0.0 is required"
rescue LoadError
  require "rev"
  Rev::VERSION >= "0.3.0" or abort "rev >= 0.3.0 is required"
end
