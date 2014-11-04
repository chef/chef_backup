require 'spec_helper'

describe ChefBackup do
  before do
    # Fake test class
    class ChefBackup::Test; def initialize(_p = {}) end; end
  end

  after do
    described_class.send(:remove_const, :Test)
  end

  describe '.from_config' do
    it 'returns a ChefBackup class from a given strategy' do
      config = { 'private_chef' =>  { 'backup' =>  { 'strategy' => 'test' } } }
      expect(described_class.from_config(running_config.merge(config)))
        .to be_an(ChefBackup::Test)
    end
  end
end
