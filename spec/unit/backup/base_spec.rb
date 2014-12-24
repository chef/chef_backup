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

  describe '.populate_data_map' do
    let(:services) { %w(opscode-solr4 bookshelf rabbitmq) }
    let(:configs) { %w(opscode opscode-manage opscode-analytics) }
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
      %w(add_service add_config).each do |method|
        allow(data_map).to receive(method.to_sym).and_return(true)
      end
    end

    %w(frontend backend standalone).each do |role|
      context "on a #{role}" do
        subject { with_running_config(config.merge('role' => role)) }

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
        subject { with_running_config(config.merge('role' => role)) }

        it 'populates the data map with service directories' do
          services.each do |service|
            expect(subject.data_map)
              .to receive(:add_service)
              .with(service, config[service]['data_dir'])
          end

          subject.populate_data_map
        end
      end
    end

    context 'on a frontend' do
      subject { with_running_config(config.merge('role' => 'frontend')) }

      it "doesn't populate the data map with the services" do
        expect(subject.data_map).to_not receive(:add_service)
      end
    end
  end

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
