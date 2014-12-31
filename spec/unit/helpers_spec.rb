require 'spec_helper'

describe ChefBackup::Helpers do
  before do
    class HelperTest; include ChefBackup::Helpers; end
  end

  after do
    Object.send(:remove_const, :HelperTest)
  end

  describe '.tmp_dir' do
    context 'with default settings' do
      it 'creates a temp directory' do
        allow(Dir).to receive(:mktmpdir).and_return('/tmp/mktmpdir')
        expect(Dir).to receive(:mktmpdir)
        subject.tmp_dir
      end
    end

    context 'with a specific backup directory' do
      let(:temp_dir) { '/tmp/pccbak' }
      subject { with_config('tmp_dir', temp_dir) }

      it 'uses the specified directory' do
        allow(FileUtils).to receive(:mkdir_p).and_return([temp_dir])
        expect(FileUtils).to receive(:mkdir_p).with(temp_dir)
        subject.tmp_dir
      end
    end
  end

end
