require 'spec_helper'

describe ChefBackup::Runner do
  let(:test_strategy) { double('TestBackup', backup: true, restore: true) }
  let(:backup_tarball) { '/tmp/chef-backup-2014-12-10-20-31-40.tgz' }
  let(:backup_name) { 'chef-backup-2014-12-10-20-31-40' }
  let(:restore_dir) { ChefBackup::Config['restore_dir'] }
  let(:manifest_json) { "#{restore_dir}/manifest.json" }
  let(:manifest) { { 'strategy' => 'test_strategy' } }
  let(:json) { '{"some":{"nested":{"hash":1}}}' }
  let(:runner_config) do
    {
      'tmp_dir' => '/tmp/runner_spec_tmp_dir',
      'restore_param' => backup_tarball,
      'agree_to_cleanse' => 'yes',
      'private_chef' => { 'backup' => { 'strategy' => 'test' } }
    }
  end

  subject { described_class.new(runner_config) }

  describe '.backup' do
    it 'initializes a ChefBackup::Strategy and calls .backup' do
      allow(ChefBackup::Strategy)
        .to receive(:backup)
        .with('test')
        .and_return(test_strategy)

      expect(test_strategy).to receive(:backup).once
      subject.backup
    end
  end

  describe '.restore' do
    it 'initializes a ChefBackup::Strategy and calls .restore' do
      allow(subject).to receive(:restore_strategy).and_return('test')
      allow(ChefBackup::Strategy)
        .to receive(:restore)
        .with('test', backup_tarball)
        .and_return(test_strategy)

      expect(test_strategy).to receive(:restore).once
      subject.restore
    end
  end

  describe '.manifest' do
    before do
      allow(subject).to receive(:restore_directory).and_return(restore_dir)
      allow(subject).to receive(:ensure_file!).and_return(true)
      allow(File).to receive(:read).with(manifest_json).and_return(json)
    end

    it 'verifies that the file exists' do
      expect(subject).to receive(:ensure_file!)
      subject.manifest
    end

    it 'parses the manifest.json' do
      expect(subject.manifest).to eq(JSON.parse(json).to_h)
    end
  end

  describe '.restore_directory' do
    let(:rest_dir) do
      ChefBackup::Config['tmp_dir'] = '/tmp/chef_backup'
      File.join(ChefBackup::Config['tmp_dir'], backup_name)
    end

    before(:each) do
      ChefBackup::Config['tmp_dir'] = '/tmp/chef_backup'
      allow(subject).to receive(:backup_name).and_return(backup_name)
    end

    context 'when the restore directory already exists' do
      before do
        allow(File).to receive(:directory?).and_return(true)
        allow(Dir).to receive(:glob).and_return(%w[a b c])
        allow(FileUtils).to receive(:rm_r).and_return(true)
      end

      it 'cleans the restore directory' do
        # The directory needs to exist but has not been set in the config
        ChefBackup::Config['restore_dir'] = nil
        expect(FileUtils).to receive(:rm_r).with(%w[a b c])
        subject.restore_directory
      end

      it 'does not create a new directory' do
        ChefBackup::Config['restore_dir'] = '/tmp/restore_dir'
        subject.restore_directory
        expect(ChefBackup::Config['restore_dir']).to eq(restore_dir)
      end
    end

    context 'when the restore directory does not exist' do
      before do
        allow(File).to receive(:directory?).and_return(false)
        allow(FileUtils).to receive(:rm_r).and_return(true)
        allow(FileUtils).to receive(:mkdir_p).and_return(true)
      end

      it 'creates a restore directory in the runner tmp_dir' do
        ChefBackup::Config['restore_dir'] = nil
        expect(FileUtils).to receive(:mkdir_p).with(rest_dir)
        subject.restore_directory
      end

      it 'updates the config with the restore dir' do
        ChefBackup::Config['restore_dir'] = nil
        subject.restore_directory
        expect(ChefBackup::Config['restore_dir']).to eq(restore_dir)
      end
    end
  end

  describe '.unpack_tarball' do
    before do
      allow(subject).to receive(:restore_param).and_return(backup_tarball)
      allow(subject).to receive(:restore_directory).and_return(restore_dir)
      allow(subject).to receive(:shell_out!).and_return(true)
    end

    it 'raises an error if the tarball is invalid' do
      allow(File)
        .to receive(:exist?).with(backup_tarball).and_return(false)
      expect { subject.unpack_tarball }
        .to raise_error(ChefBackup::Exceptions::InvalidTarball,
                        "#{backup_tarball} not found")
    end

    it 'explodes the tarball into the restore directory' do
      allow(subject).to receive(:ensure_file!).and_return(true)

      cmd = "tar zxf #{backup_tarball} -C #{restore_dir}"
      expect(subject).to receive(:shell_out!).with(cmd)
      subject.unpack_tarball
    end
  end

  describe '.restore_strategy' do
    context 'when the restore param is a tarball' do
      before do
        allow(subject).to receive(:tarball?).and_return(true)
        allow(subject).to receive(:unpack_tarball).and_return(true)
        allow(subject).to receive(:manifest).and_return(manifest)
      end

      it 'unpacks the tarball' do
        expect(subject).to receive(:unpack_tarball)
        subject.restore_strategy
      end

      it 'returns the strategy from the manifest' do
        expect(subject.restore_strategy).to eq('test_strategy')
        subject.restore_strategy
      end
    end

    context 'when the restore param is an ebs snapshot' do
      before do
        allow(subject).to receive(:tarball?).and_return(false)
        allow(subject).to receive(:ebs_snapshot?).and_return(true)
      end

      it 'returns "ebs" as the strategy' do
        expect(subject.restore_strategy).to eq('ebs')
      end
    end

    context 'when the restore param is not valid' do
      before do
        allow(subject).to receive(:tarball?).and_return(false)
        allow(subject).to receive(:ebs_snapshot?).and_return(false)
        allow(subject).to receive(:restore_param).and_return('invalid_param')
      end

      it 'raises an exception' do
        expect { subject.restore_strategy }
          .to raise_error(ChefBackup::Exceptions::InvalidStrategy,
                          'invalid_param is not a valid backup')
      end
    end
  end
end
