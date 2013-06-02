require_relative "../lib/objspace/stats"
require "yaml"

if RbConfig::CONFIG["MAJOR"].to_i < 2 || RbConfig::CONFIG["MINOR"].to_i < 1
  warn "Error: ObjectStats requires Ruby 2.1 or greater"
  exit 1
end

def allocate_a_string_from_spec_helper
  return "a string from spec_helper"
end
