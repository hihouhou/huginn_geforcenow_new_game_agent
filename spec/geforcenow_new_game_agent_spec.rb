require 'rails_helper'
require 'huginn_agent/spec_helper'

describe Agents::GeforcenowNewGameAgent do
  before(:each) do
    @valid_options = Agents::GeforcenowNewGameAgent.new.default_options
    @checker = Agents::GeforcenowNewGameAgent.new(:name => "GeforcenowNewGameAgent", :options => @valid_options)
    @checker.user = users(:bob)
    @checker.save!
  end

  pending "add specs here"
end
