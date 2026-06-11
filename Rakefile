# frozen_string_literal: true

require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

task :rubocopcheck do
  exec 'rubocop'
end

task :rubocopfix do
  exec 'rubocop -A'
end
