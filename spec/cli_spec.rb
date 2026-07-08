# frozen_string_literal: true

require 'spec_helper'
require_relative '../lib/cli/cli'

RSpec.describe AlcesJob::CLI do
  it 'registers the version command' do
    cli = Dry::CLI.new(described_class)

    output = capture_stdout do
      cli.call(arguments: ['version'])
    end

    expect(output).to include('2.0.1')
  end
end
