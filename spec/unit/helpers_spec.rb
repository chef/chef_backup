require 'spec_helper'
require_relative 'shared_examples/helpers'

describe ChefBackup::Helpers do
  let(:tmp_dir_path) { '/tmp/chef_backup/tmp_dir' }

  before do
    # Test class to include our helpers methods
    class HelperTest; include ChefBackup::Helpers; end
  end

  after do
    Object.send(:remove_const, :HelperTest)
  end

  subject { HelperTest.new }

  describe '.tmp_dir' do
    context 'with CLI args' do
      before { private_chef!('tmp_dir' => tmp_dir_path) }

      context 'when the directory exists' do
        before do
          allow(File)
            .to receive(:directory?).with(tmp_dir_path).and_return(true)
        end

        it_behaves_like '.tmp_dir with an existing specified directory'
      end

      context 'when the directory does not exist' do
        before do
          allow(File)
            .to receive(:directory?).with(tmp_dir_path).and_return(false)
          allow(FileUtils)
            .to receive(:mkdir_p).with(tmp_dir_path).and_return([tmp_dir_path])
        end

        it_behaves_like '.tmp_dir with a nonexisting specified directory'
      end
    end

    context 'with running_config args' do
      before { private_chef!('tmp_dir' => tmp_dir_path) }

      context 'when the directory exists' do
        before do
          allow(File)
            .to receive(:directory?).with(tmp_dir_path).and_return(true)
        end

        it_behaves_like '.tmp_dir with an existing specified directory'
      end

      context 'when the directory does not exist' do
        before do
          allow(File)
            .to receive(:directory?).with(tmp_dir_path).and_return(false)
          allow(FileUtils)
            .to receive(:mkdir_p).with(tmp_dir_path).and_return([tmp_dir_path])
        end

        it_behaves_like '.tmp_dir with a nonexisting specified directory'
      end
    end

    context 'when no args are passed' do
      before do
        clear_config
        allow(Dir).to receive(:mktmpdir).with('chef_backup')
      end

      it_behaves_like '.tmp_dir without a specified directory'
    end
  end

  describe '.cleanup' do
    before do
      allow(subject).to receive(:tmp_dir).and_return(tmp_dir_path)
      allow(FileUtils).to receive(:rm_r).with(tmp_dir_path)
    end

    it 'cleans up all items in the temp directory' do
      expect(FileUtils).to receive(:rm_r).with(tmp_dir_path)
      subject.cleanup
    end
  end
end
