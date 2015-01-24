require 'spec_helper'

describe ChefBackup::Helpers do
  before do
    # Test class to include our helpers methods
    class HelperTest; include ChefBackup::Helpers; end
  end

  after do
    Object.send(:remove_const, :HelperTest)
  end

  subject { HelperTest.new }

  describe '.tmp_dir' do
    context 'with default settings' do
      it 'creates a temp directory' do
        allow(Dir).to receive(:mktmpdir).and_return('/tmp/mktmpdir')
        expect(Dir).to receive(:mktmpdir)
        subject.tmp_dir
      end
    end

    context 'with a specific backup directory' do
      let(:tmp_dir) { '/tmp/pccbak' }
      before { private_chef('backup' => { 'tmp_dir' => tmp_dir }) }

      it 'uses the specified directory' do
        allow(FileUtils).to receive(:mkdir_p).and_return([tmp_dir])
        expect(FileUtils).to receive(:mkdir_p).with(tmp_dir)
        subject.tmp_dir
      end
    end
  end
end
