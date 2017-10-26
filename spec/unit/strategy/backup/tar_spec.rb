require 'spec_helper'
require 'chef_backup/deep_merge'
require_relative 'shared_examples/backup'

describe ChefBackup::Strategy::TarBackup do
  set_common_variables

  subject { described_class.new }

  before do
    use_default_running_config
    allow(subject).to receive(:tmp_dir).and_return(tmp_dir)
    allow(subject).to receive(:backup_time).and_return(backup_time)
  end

  describe '.backup' do
    before do
      %i(write_manifest dump_db stop_service create_tarball cleanup
         start_service export_tarball
      ).each do |method|
        allow(subject).to receive(method).and_return(true)
      end

      allow(subject).to receive(:enabled_services).and_return(enabled_services)
      allow(subject).to receive(:all_services).and_return(all_services)
      allow(subject).to receive(:dump_db).and_return(true)
    end

    context 'when config_only is true' do
      before do
        private_chef('backup' => { 'config_only' => true })
      end

      it_behaves_like 'a tar based backup'
      it_behaves_like 'a tar based frontend'
    end

    context 'on a frontend' do
      before { private_chef('role' => 'frontend') }

      it_behaves_like 'a tar based backup'
      it_behaves_like 'a tar based frontend'
    end

    context 'on a backend' do
      before { private_chef('role' => 'backend') }

      context 'during an online backup' do
        before do
          private_chef('role' => 'backend', 'backup' => { 'mode' => 'online' })
        end

        it_behaves_like 'a tar based backup'
        it_behaves_like 'a tar based online backend'
      end

      context 'during an offline backup' do
        it_behaves_like 'a tar based backup'
        it_behaves_like 'a tar based offline backend'
      end

      context 'when no mode is configured' do
        before do
          private_chef('role' => 'backend', 'backup' => { 'mode' => nil })
        end

        it_behaves_like 'a tar based backup'
        it_behaves_like 'a tar based offline backend'
      end
    end

    context 'on a standalone' do
      before { private_chef('role' => 'standalone') }

      context 'during an online backup' do
        before do
          private_chef('role' => 'standalone',
                       'backup' => { 'mode' => 'online' })
        end

        it_behaves_like 'a tar based backup'
        it_behaves_like 'a tar based online backend'
      end

      context 'during an offline backup' do
        it_behaves_like 'a tar based backup'
        it_behaves_like 'a tar based offline backend'
      end

      context 'when no mode is configured' do
        before do
          private_chef('role' => 'standalone', 'backup' => { 'mode' => nil })
        end

        it_behaves_like 'a tar based backup'
        it_behaves_like 'a tar based offline backend'
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

    let(:pg_options) { ["PGOPTIONS=#{ChefBackup::Helpers::DEFAULT_PG_OPTIONS}"] }
    let(:tmp_dir) { '/tmp/notaswear' }
    let(:backup_time) { Time.now }

    before do
      allow(subject).to receive(:tmp_dir).and_return(tmp_dir)
      allow(subject).to receive(:backup_time).and_return(backup_time)
      allow(subject).to receive(:shell_out!).with(dump_cmd, env: pg_options).and_return(true)
      private_chef('postgresql' => { 'username' => 'opscode-pgsql' })
      subject.data_map.add_service('postgresql', '/data/dir')
    end

    %w(backend standalone).each do |role|
      context "on a #{role}" do
        before do
          private_chef('role' => role)
        end

        it 'dumps the db' do
          expect(subject).to receive(:shell_out!).with(dump_cmd, env: pg_options)
          subject.dump_db
        end

        it 'updates the data map' do
          subject.dump_db
          expect(subject.data_map.services['postgresql'])
            .to include('pg_dump_success' => true)
        end

        it 'adds the postgresql username to the data map' do
          subject.dump_db
          expect(subject.data_map.services['postgresql'])
            .to include('username' => 'opscode-pgsql')
        end
      end
    end

    context 'on a frontend' do
      before { private_chef('role' => 'frontend') }

      it "doesn't dump the db" do
        expect(subject).to_not receive(:shell_out).with(/pg_dumpall/)
        subject.dump_db
      end
    end
  end

  describe '.create_tarball' do
    before do
      allow(subject).to receive(:data_map).and_return(data_map)
      allow(Dir).to receive(:[]).and_return(%w(sql.sql manifest.json))
    end

    it 'creates a tarball with all items in the temp directory' do
      cmd = [
        "tar -czf #{tmp_dir}/chef-backup-#{backup_time}.tgz",
        data_map.services.map { |_, v| v['data_dir'] }.compact.join(' '),
        data_map.configs.map { |_, v| v['data_dir'] }.compact.join(' '),
        Dir["#{tmp_dir}/*"].map { |f| File.basename(f) }.join(' ')
      ].join(' ').strip

      allow(subject).to receive(:shell_out!).with(cmd, cdw: tmp_dir)
      expect(subject).to receive(:shell_out!).with(cmd, cwd: tmp_dir)
      subject.create_tarball
    end
  end

  describe '.export_tarball' do
    before do
      allow(subject).to receive(:export_dir).and_return('/mnt/chef-backups')
    end

    it 'moves the tarball to the archive location' do
      cmd = "rsync -chaz #{tmp_dir}/chef-backup-#{backup_time}.tgz"
      cmd << " #{export_dir}/"

      allow(subject).to receive(:shell_out!).with(cmd)
      expect(subject).to receive(:shell_out!).with(cmd)
      subject.export_tarball
    end
  end

  describe '.write_manifest' do
    let(:manifest) do
      { 'some' =>
        {
          'nested' => {
            'hash' => true
          },
          'another' => true
        }
      }
    end

    let(:file) { double('file', write: true) }

    before do
      allow(subject).to receive(:manifest).and_return(manifest)
      allow(subject).to receive(:tmp_dir).and_return(tmp_dir)
      allow(File).to receive(:open).and_yield(file)
    end

    it 'converts the manifest to json' do
      json_manifest = JSON.pretty_generate(subject.manifest)
      expect(file).to receive(:write).with(json_manifest)
      subject.write_manifest
    end

    it 'writes a json file to the tmp_dir' do
      expect(File).to receive(:open).with("#{tmp_dir}/manifest.json", 'w')
      subject.write_manifest
    end
  end

  describe '.populate_data_map' do
    let(:services) { %w(opscode-solr4 bookshelf rabbitmq) }
    let(:configs) { %w(opscode opscode-manage opscode-analytics) }
    let(:versions) do
      {
        'opscode' => { 'version' => '12.9.1',
                       'revision' => 'aa7b99ac81ff4c018a0081e9a273b87b15342f12',
                       'path' => '/opt/opscode/version-manifest.json' },
        'opscode-manage' => :no_version,
        'opscode-analytics' => :no_version
      }
    end
    let(:config) do
      { 'bookshelf' => { 'data_dir' => '/bookshelf/data' },
        'opscode-solr4' => { 'data_dir' => '/solr4/data' },
        'rabbitmq' => { 'data_dir' => '/rabbitmq/data' }
      }
    end

    before do
      allow(subject).to receive(:data_map).and_return(data_map)
      allow(subject).to receive(:stateful_services).and_return(services)
      allow(subject).to receive(:config_directories).and_return(configs)
      %w(add_service add_config add_ha_info add_version).each do |method|
        allow(data_map).to receive(method.to_sym).and_return(true)
      end
    end

    %w(frontend backend standalone).each do |role|
      context "on a #{role}" do
        before { private_chef(config.merge('role' => role)) }

        it 'populates the data map with config directories' do
          configs.each do |config|
            expect(subject.data_map)
              .to receive(:add_config)
              .with(config, "/etc/#{config}")
          end

          subject.populate_data_map
        end
      end
    end

    %w(backend standalone).each do |role|
      context "on a #{role}" do
        before { private_chef(config.merge('role' => role)) }

        it 'populates the data map with service directories' do
          services.each do |service|
            expect(subject.data_map)
              .to receive(:add_service)
              .with(service, config[service]['data_dir'])
          end

          subject.populate_data_map
        end

        it 'populates the data map with the upgrades' do
          expect(subject.data_map)
            .to receive(:add_service)
            .with('upgrades', '/var/opt/opscode/upgrades')

          subject.populate_data_map
        end
      end
    end

    context 'when config_only is true' do
      before do
        private_chef('role' => 'standalone', 'backup' => { 'config_only' => true })
        data_mock = double('DataMap')
        allow(subject).to receive(:data_map).and_return(data_mock)
        allow_any_instance_of(ChefBackup::Helpers)
          .to receive(:version_from_manifest_file).and_return(:version_stub)
        allow(subject).to receive(:enabled_addons).and_return('opscode' => nil,
                                                              'opscode-manage' => nil,
                                                              'opscode-analytics' => nil)
      end

      it 'populates the data map with config and upgrade directories only' do
        configs.each do |config|
          expect(subject.data_map)
            .to receive(:add_config).with(config, "/etc/#{config}")
        end

        versions.keys.each do |version|
          expect(subject.data_map)
            .to receive(:add_version).with(version, :version_stub)
        end

        expect(subject.data_map)
          .to receive(:add_service)
          .with('upgrades', '/var/opt/opscode/upgrades')

        subject.populate_data_map
      end
    end

    context 'on a frontend' do
      before { private_chef(config.merge('role' => 'frontend')) }

      it "doesn't populate the data map with the services" do
        expect(subject.data_map).to_not receive(:add_service)
      end
    end
  end

  describe '.pg_dump?' do
    it 'returns true' do
      expect(subject.pg_dump?).to eq(true)
    end

    context 'when db dump is disabled' do
      before { private_chef('backup' => { 'always_dump_db' => false }) }

      it 'returns false' do
        expect(subject.pg_dump?).to eq(false)
      end
    end
  end
end
