require 'spec_helper'

describe ChefBackup::DataMap do
  set_common_variables

  describe '.initialize' do
    it 'yields a config block' do
      expect { |b| described_class.new(&b) }.to yield_with_args
    end
  end

  describe '.add_service' do
    subject { described_class.new }

    it 'adds a service' do
      subject.add_service('bookshelf', '/bookshelf/path')
      expect(subject.services.keys.count).to eq(1)
      expect(subject.services['bookshelf']['data_dir']).to eq('/bookshelf/path')
    end
  end

  describe '.add_config' do
    subject { described_class.new }

    it 'adds a config' do
      subject.add_config('opscode-manage', '/opscode-manage/path')
      expect(subject.configs.keys.count).to eq(1)
      expect(subject.configs['opscode-manage']['config'])
        .to eq('/opscode-manage/path')
    end
  end

  describe '.add_version' do
    subject { described_class.new }

    it 'adds a version' do
      subject.add_version('opscode-manage', :no_version)
      expect(subject.versions.keys.count).to eq(1)
      expect(subject.versions['opscode-manage']).to eq(:no_version)
    end
  end

  describe '.manifest' do
    subject do
      described_class.new do |dm|
        dm.strategy = 'test'
        dm.backup_time = backup_time
        dm.add_config('somethingstrange', 'inthehood')
        dm.add_service('whoyagonnacall', 'ghostbusters')
      end
    end

    it 'includes the backup strategy type' do
      expect(subject.manifest).to include('strategy' => 'test')
    end

    it 'includes the backup timestamp' do
      expect(subject.manifest).to include('backup_time' => backup_time)
    end

    it 'includes the backup config' do
      expect(subject.manifest).to include('configs' => subject.configs)
    end

    it 'includes the backup service' do
      expect(subject.manifest).to include('services' => subject.services)
    end
  end
end
