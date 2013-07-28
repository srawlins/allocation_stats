require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task :fetch_active_support_delegation do
  `wget https://raw.github.com/rails/rails/v4.0.0/activesupport/lib/active_support/core_ext/module/delegation.rb -O lib/active_support/core_ext/module/delegation.rb`
end
