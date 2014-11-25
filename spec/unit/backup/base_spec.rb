require 'spec_helper'

describe ChefBackup::Base do
  setup_handy_default_variables

  subject { described_class.new(running_config) }

  before do
    allow(subject).to receive(:shell_out!).and_return(true)
    allow(subject).to receive(:shell_out).and_return(true)
  end

  describe '.backup' do
    it 'raises an exception' do
      expect { subject.backup }.to raise_error(NotImplementedError)
    end
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

  describe '.dump_db' do
    let(:dump_cmd) do
      ['/opt/opscode/embedded/bin/chpst',
       '-u opscode-pgsql',
       '/opt/opscode/embedded/bin/pg_dumpall',
       "> #{tmp_dir}/chef_backup-#{backup_time}.sql"
      ].join(' ')
    end

    before do
      allow(subject).to receive(:tmp_dir).and_return(tmp_dir)
      allow(subject).to receive(:backup_time).and_return(backup_time)
    end

    context 'on a backend' do
      subject do
        with_running_config(
          'role' => 'backend',
          'postgresql' => { 'username' => 'opscode-pgsql' }
        )
      end

      before do
        data_map = double('DataMap', services: { 'postgresql' => {} })
        allow(subject).to receive(:data_map).and_return(data_map)
      end

      it 'dumps the db' do
        expect(subject).to receive(:shell_out!).with(dump_cmd)
        subject.dump_db
      end

      it 'updates the data map' do
        expect(subject.data_map.services['postgresql'])
          .to receive(:[]=)
          .with('pg_dump_success', true)
        subject.dump_db
      end
    end

    context 'on a frontend' do
      subject { with_running_config('role' => 'frontend') }

      it "doesn't dump the db" do
        expect(subject.dump_db).to_not receive(:shell_out).with(/pg_dumpall/)
      end
    end
  end

  describe '.manifest' do
    before do
      data_map = double('DataMap', manifest: true)
      allow(subject).to receive(:data_map).and_return(data_map)
    end

    it 'returns the data_map manifest' do
      expect(subject.data_map).to receive(:manifest)
      subject.manifest
    end
  end

  describe '.write_manifest' do
    let(:manifest) do
      { 'some' => {
        'nested' => {
          'hash' => true
        },
        'another' => true
      }
      }
    end

    before do
      allow(subject).to receive(:manifest).and_return(manifest)
      allow(subject).to receive(:tmp_dir).and_return(tmp_dir)
      @file = double('file', write: true)
      allow(File).to receive(:open).and_yield(@file)
    end

    it 'converts the manifest to json' do
      json_manifest = JSON.pretty_generate(subject.manifest)
      expect(@file).to receive(:write).with(json_manifest)
      subject.write_manifest
    end

    it 'writes a json file to the tmp_dir' do
      expect(File).to receive(:open).with("#{tmp_dir}/manifest.json", 'w')
      subject.write_manifest
    end
  end

#  describe '.backup_opscode_config' do
#    addons = %w(
#      opscode-reporting
#      opscode-push-jobs-server
#      opscode-analytics
#      opscode-manage
#    )
#
#    before do
#      data_map = double('DataMap', add_config: true, add_service: true)
#      allow(subject).to receive(:data_map).and_return(data_map)
#      allow(subject).to receive(:tmp_dir).and_return(tmp_dir)
#    end
#
#    it 'always backs up the private-chef config' do
#      cmd = "rsync -chaz /etc/opscode #{tmp_dir}/"
#      expect(subject).to receive(:shell_out).with(cmd)
#      subject.backup_opscode_config
#    end
#
#    it 'updates the opscode entry in the data map' do
#      expect(subject.data_map)
#        .to receive(:add_config)
#        .with('opscode', '/etc/opscode')
#      subject.backup_opscode_config
#    end
#
#    addons.each do |service|
#      context "when #{service} is installed" do
#        before { allow(subject).to receive(:addon?).and_return(true) }
#
#        it "backs up the #{service} config" do
#          cmd = "rsync -chaz /etc/#{service} #{tmp_dir}/"
#          expect(subject).to receive(:shell_out).with(cmd)
#          subject.backup_opscode_config
#        end
#
#        it "updates the #{service} entry in the data map" do
#          expect(subject.data_map)
#            .to receive(:add_config)
#          subject.backup_opscode_config
#        end
#      end
#
#      context "when #{service} isn't installed" do
#        before { allow(subject).to receive(:addon?).and_return(false) }
#
#        it "does not try to backup #{service}'s config" do
#          expect(subject.backup_opscode_config).to_not receive(:shell_out)
#        end
#      end
#    end
#  end

  describe '.cleanup' do
    before do
      noop_external_methods_except(:cleanup)
      allow(subject).to receive(:tmp_dir).and_return(tmp_dir)
    end

    it 'cleans up all items in the temp directory' do
      expect(FileUtils).to receive(:rm_r).with(tmp_dir)
      subject.cleanup
    end
  end
end
