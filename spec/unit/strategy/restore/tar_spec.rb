require 'spec_helper'
require_relative 'shared_examples/restore'

describe ChefBackup::Strategy::TarRestore do
  let(:manifest) do
    { 'strategy' => 'tar',
      'backup_time' => '2014-12-02-22-46-58',
      'services' => {
        'rabbitmq' => { 'data_dir' => '/var/opt/opscode/rabbitmq/db' },
        'opscode-solr4' => {
          'data_dir' => '/var/opt/opscode/opscode-solr4/data'
        },
        'redis_lb' => { 'data_dir' => '/var/opt/opscode/redis_lb/data' },
        'postgresql' => {
          'data_dir' => '/var/opt/opscode/postgresql/9.2/data',
          'pg_dump_success' => pg_dump_success
        },
        'bookshelf' => { 'data_dir' => '/var/opt/opscode/bookshelf/data' }
      },
      'configs' => {
        'opscode' => { 'data_dir' => '/etc/opscode' },
        'opscode-manage' => { 'data_dir' => '/etc/opscode-manage' },
        'opscode-reporting' => { 'data_dir' => '/etc/opscode-reporting' },
        'opscode-analytics' => { 'data_dir' => '/etc/opscode-analytics' }
      }
    }
  end

  let(:pg_dump_success) { true }
  let(:tarball_path) { '/var/backups/chef-backup-2014-12-02-22-46-58.tgz' }
  let(:configs) { manifest['configs'].keys }
  let(:services) { manifest['services'].keys }
  let(:restore_dir) { ChefBackup::Config['restore_dir'] }

  subject { described_class.new(tarball_path) }

  before(:each) { use_default_cli_args }

  describe '.restore' do
    before do
      %i(shell_out shell_out! unpack_tarball stop_chef_server ensure_file!
         start_chef_server reconfigure_server cleanse_chef_server
         update_config import_db
      ).each do |method|
        allow(subject).to receive(method).and_return(true)
      end
      configs.each do |config|
        allow(subject)
          .to receive(:restore_data)
          .with(:configs, config)
          .and_return(true)
      end
      services.each do |service|
        allow(subject)
          .to receive(:restore_data)
          .with(:services, service)
          .and_return(true)
      end

      allow(subject).to receive(:tarball_path).and_return(tarball_path)
      allow(subject).to receive(:manifest).and_return(manifest)
    end

    it_behaves_like 'a tar based restore'

    context 'on a frontend' do
      before do
        allow(subject).to receive(:frontend?).and_return(true)
      end

      it_behaves_like 'a tar based frontend restore'
    end

    context 'on a backend' do
      before do
        allow(subject).to receive(:frontend?).and_return(false)
      end

      it_behaves_like 'a tar based backend restore'

      context 'when a db dump is present' do
        before do
          allow(subject).to receive(:restore_db_dump?).and_return(true)
          allow(subject)
            .to receive(:start_service).with(:postgresql).and_return(true)
          allow(subject).to receive(:import_db).and_return(true)
        end

        it_behaves_like 'a tar based backend restore with db dump'
      end

      context 'when a db dump is not present' do

        before do
          allow(subject).to receive(:restore_db_dump?).and_return(false)
        end

        it_behaves_like 'a tar based backend restore without db dump'
      end
    end

    context 'on a standalone' do
      before do
        allow(subject).to receive(:frontend?).and_return(false)
      end

      it_behaves_like 'a tar based backend restore'

      context 'when a db dump is present' do
        before do
          allow(subject).to receive(:restore_db_dump?).and_return(true)
        end

        it_behaves_like 'a tar based backend restore with db dump'
      end

      context 'when a db dump is not present' do
        before do
          allow(subject).to receive(:restore_db_dump?).and_return(false)
        end

        it_behaves_like 'a tar based backend restore without db dump'
      end
    end
  end

  describe '.manifest' do
    let(:json) { "{\"some\":\"json\"}" }
    let(:manifest_json) { File.join(restore_dir, 'manifest.json') }

    it 'parses the manifest from the restore dir' do
      allow(subject).to receive(:ensure_file!).and_return(true)
      allow(File).to receive(:read).with(manifest_json).and_return(json)
      expect(subject.manifest).to eq('some' => 'json')
    end

    it 'raises an error if the manifest is invalid' do
      expect { subject.manifest }
        .to raise_error(
          ChefBackup::Strategy::TarRestore::InvalidManifest,
          "#{File.join(restore_dir, 'manifest.json')} not found"
        )
    end
  end

  describe '.restore_data' do
    before do
      ChefBackup::Config['restore_dir'] = restore_dir
      allow(subject).to receive(:manifest).and_return(manifest)
      allow(subject).to receive(:shell_out!).and_return(true)
      allow(File).to receive(:directory?).and_return(true)
    end

    context 'with config data' do
      it 'rsyncs the config from the restore dir to the data_dir' do
        source = File.expand_path(
          File.join(restore_dir, manifest['configs']['opscode']['data_dir']))
        destination = manifest['configs']['opscode']['data_dir']
        cmd = "rsync -chaz --delete #{source}/ #{destination}"

        expect(subject).to receive(:shell_out!).with(cmd)
        subject.restore_data(:configs, 'opscode')
      end
    end

    context 'with service data' do
      it 'rsyncs the service from the restore dir to the data_dir' do
        source = File.expand_path(
          File.join(restore_dir, manifest['services']['rabbitmq']['data_dir']))
        destination = manifest['services']['rabbitmq']['data_dir']
        cmd = "rsync -chaz --delete #{source}/ #{destination}"

        expect(subject).to receive(:shell_out!).with(cmd)
        subject.restore_data(:services, 'rabbitmq')
      end
    end
  end

  describe '.import_db' do
    before do
      allow(subject).to receive(:manifest).and_return(manifest)
      allow(subject).to receive(:shell_out!).and_return(true)
      allow(subject).to receive(:running_config).and_return(running_config)
      private_chef('postgresql' => {'username' => 'opscode-pgsql'})
    end

    context 'without a db dump' do
      it 'raises an exception' do
        expect { subject.import_db }
          .to raise_error(ChefBackup::Exceptions::InvalidDatabaseDump)
      end
    end

    context 'with a db dump' do
      let(:db_sql) do
        File.join(restore_dir, "chef_backup-#{manifest['backup_time']}.sql")
      end

      let(:import_cmd) do
        ['/opt/opscode/embedded/bin/chpst -u opscode-pgsql',
         '/opt/opscode/embedded/bin/psql -U opscode-pgsql',
         "-d opscode_chef < #{db_sql}"
        ].join(' ')
      end

      before do
        allow(subject)
          .to receive(:ensure_file!)
          .with(db_sql,
                ChefBackup::Exceptions::InvalidDatabaseDump,
                "#{db_sql} not found")
          .and_return(true)
      end

      it 'imports the database' do
        expect(subject).to receive(:shell_out!).with(import_cmd)
        subject.import_db
      end
    end
  end
end
