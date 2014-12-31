require 'spec_helper'

describe ChefBackup::Strategy::TarRestore do
  let(:manifest) do
    {"strategy"=>"tar",
     "backup_time"=>"2014-12-02-22-46-58",
     "services"=>
      {"rabbitmq"=>{"data_dir"=>"/var/opt/opscode/rabbitmq/db"},
       "opscode-solr4"=>{"data_dir"=>"/var/opt/opscode/opscode-solr4/data"},
       "redis_lb"=>{"data_dir"=>"/var/opt/opscode/redis_lb/data"},
       "postgresql"=>{"data_dir"=>"/var/opt/opscode/postgresql/9.2/data", "pg_dump_success"=>true},
       "bookshelf"=>{"data_dir"=>"/var/opt/opscode/bookshelf/data"}},
     "configs"=>
      {"opscode"=>{"data_dir"=>"/etc/opscode"},
       "opscode-manage"=>{"data_dir"=>"/etc/opscode-manage"},
       "opscode-reporting"=>{"data_dir"=>"/etc/opscode-reporting"},
       "opscode-analytics"=>{"data_dir"=>"/etc/opscode-analytics"}}}
  end

  let(:tarball_path) { '/var/backups/chef-backup-2014-12-02-22-46-58.tgz' }
  let(:configs) { manifest['configs'].keys }
  let(:services) { manifest['services'].keys }

  subject { described_class.new(tarball_path, running_config) }

  describe '.restore' do
    before do
      %i(shell_out shell_out! unpack_tarball stop_chef_server
        start_chef_server reconfigure_server import_db
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
      allow(subject).to receive(:restore_directory).and_return('/tmp/restore')
      allow(subject).to receive(:manifest).and_return(manifest)
    end

    context 'on a frontend' do
      subject do
        with_path_and_running_config(
          tarball_path,
          'role' => 'frontend',
          'backup' => {}
        )
      end

      it 'does not restore backend service state' do
        expect(subject).to_not receive(:restore_data).with(:services, anything)
        expect(subject).to_not receive(:import_db)
        subject.restore
      end
    end

    %w(backend standalone).each do |role|
      context "on a #{role}" do
        subject do
          with_path_and_running_config(
            tarball_path,
            'role' => role,
            'backup' => {}
          )
        end

        it 'restores the stateful services' do
          services.each do |service|
            expect(subject)
              .to receive(:restore_data)
              .with(:services, service)
              .once
          end
          subject.restore
        end

        context 'when backup includes a postgresql db dump' do
          # The default manifest has pg_dump_success = true
          it 'restores the db dump' do
            allow(subject).to receive(:import_db).and_return(true)
            expect(subject).to receive(:import_db)
            subject.restore
          end
        end

        context "when backup doesn't include a postgresql db dump" do
          it 'does not try to import a db dump' do
            man = manifest
            man['services']['postgresql']['pg_dump_success'] = nil
            allow(subject).to receive(:manifest).and_return(man)
            allow(subject).to receive(:import_db).and_return(true)
            expect(subject).to_not receive(:import_db)
            subject.restore
          end
        end
      end
    end

    %w(frontend backend standalone).each do |role|
      context "on a #{role}" do
        subject do
          with_path_and_running_config(
            tarball_path,
            'role' => role,
            'backup' => {}
          )
        end

        it 'stops the server' do
          expect(subject).to receive(:stop_chef_server).once
          subject.restore
        end

        it 'unpacks the tarball' do
          expect(subject).to receive(:unpack_tarball).once
          subject.restore
        end

        it 'restores the configs' do
          configs.each do |config|
            expect(subject)
              .to receive(:restore_data).with(:configs, config).once
          end
          subject.restore
        end

        it 'reconfigures the server' do
          expect(subject).to receive(:reconfigure_server).once
          subject.restore
        end

        it 'starts the server' do
          expect(subject).to receive(:start_chef_server).once
          subject.restore
        end

        it 'cleans up the temp directory' do
          expect(subject).to receive(:cleanup).once
          subject.restore
        end
      end
    end
  end

  describe '.unpack_tarball' do
    let(:restore_dir) { '/tmp/restore_dir' }

    it 'raises an error if the tarball is invalid' do
      allow(subject).to receive(:shell_out!).and_return(false)
      expect { subject.unpack_tarball }
        .to raise_error(ChefRestore::InvalidTarball,
                        "#{tarball_path} not found")
    end

    it 'explodes the tarball into the restore directory' do
      allow(subject).to receive(:ensure_file!).and_return(true)
      allow(subject).to receive(:restore_directory).and_return(restore_dir)
      allow(subject).to receive(:shell_out!).and_return(true)
      allow(subject).to receive(:tarball_path).and_return(tarball_path)

      cmd = "tar zxf #{tarball_path} -C #{restore_dir}"
      expect(subject).to receive(:shell_out!).with(cmd)
      subject.unpack_tarball
    end
  end

  describe '.manifest' do
    let(:restore_dir) { '/tmp/restore_dir' }
    let(:manifest_path) { File.join(restore_dir, 'manifest.json') }

    before do
      allow(subject).to receive(:restore_directory).and_return(restore_dir)
    end

    it 'raises an error if the manifest is invalid' do
      allow(subject).to receive(:shell_out!).and_return(false)
      expect { subject.manifest }
        .to raise_error(ChefRestore::InvalidManifest,
                        "#{manifest_path} not found")
    end
  end

  describe '.restore_data' do
    let(:restore_dir) { '/tmp/restore_dir' }

    before do
      allow(subject).to receive(:restore_directory).and_return(restore_dir)
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
    let(:restore_dir) { '/tmp/restore_dir' }

    before do
      allow(subject).to receive(:restore_directory).and_return(restore_dir)
      allow(subject).to receive(:manifest).and_return(manifest)
      allow(subject).to receive(:shell_out!).and_return(true)
    end

    %w(backend standalone).each do |role|
      context "on a #{role}" do
        context 'when a valid database dump is present' do
          subject do
            with_path_and_running_config(
              tarball_path,
              'role' => role,
              'postgresql' => { 'username' => 'opscode-pgsql' }
            )
          end

          it 'imports the database' do
            sql_file = File.join(restore_dir,
                                 "chef_backup-#{manifest['backup_time']}.sql")
            allow(File).to receive(:exists?).and_return(true)

            cmd = ['/opt/opscode/embedded/bin/chpst',
                   '-u opscode-pgsql',
                   '/opt/opscode/embedded/bin/psql',
                   '-U opscode-pgsql',
                   '-d opscode_chef',
                   "< #{sql_file}"
                  ].join(' ')

            expect(subject).to receive(:shell_out!).with(cmd)
            subject.import_db
          end
        end

        context 'when no database dump is present' do
          subject do
            with_path_and_running_config(
              tarball_path,
              'role' => role,
              'postgresql' => {
                'username' => 'opscode-pgsql',
                'pg_dump_success' => false
              }
            )

            it 'does not attempt to import the dump' do
              expect(subject).to_not receive(:shell_out!).with(/psql/)
              subject.import_db
            end
          end
        end
      end
    end

    context 'on a frontend' do
      context 'when a valid database dump is present' do
        subject do
          with_path_and_running_config(
            tarball_path,
            'role' => 'frontend',
            'postgresql' => { 'username' => 'opscode-pgsql' }
          )
        end

        it 'does not attempt to import the dump' do
          allow(File).to receive(:exists?).and_return(true)
          expect(subject).to_not receive(:shell_out!).with(/psql/)
          subject.import_db
        end
      end

      context 'when no database dump is present' do
        subject do
          with_path_and_running_config(
            tarball_path,
            'role' => 'frontend',
            'postgresql' => {
              'username' => 'opscode-pgsql',
              'pg_dump_success' => false
            }
          )

          it 'does not attempt to import the dump' do
            expect(subject).to_not receive(:shell_out!).with(/psql/)
            subject.import_db
          end
        end
      end
    end
  end

  describe '.restore_directory' do
    it 'creates or returns a directory in tmp_dir' do
      allow(subject).to receive(:tmp_dir).and_return('/tmp/chef_backup')
      allow(File).to receive(:directory?).and_return(true)

      expect(subject.restore_directory)
        .to eq(File.join('/tmp/chef_backup', 'chef-backup-2014-12-02-22-46-58'))
    end
  end
end
