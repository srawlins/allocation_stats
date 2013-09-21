require "yaml"
require File.join(__dir__, "..", "lib", "objectspace", "stats")

stats = ObjectSpace::Stats.new do
  y = YAML.dump(["one string", "two string"]) # lots of objects from Rbconfig::CONFIG["rubylibdir"]
end

stats.allocations.group_by(:sourcefile, :class).all.keys.each { |key| puts key.inspect }
