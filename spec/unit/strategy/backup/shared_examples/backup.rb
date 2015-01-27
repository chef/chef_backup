require 'spec_helper'

shared_examples 'a tar based backup' do
  it 'populates the data map with services and configs' do
    expect(subject).to receive(:populate_data_map).once
    subject.backup
  end

  it 'creates a backup manifest' do
    expect(subject).to receive(:write_manifest).once
    subject.backup
  end

  it 'creates a tarball of the backup' do
    expect(subject).to receive(:create_tarball).once
    subject.backup
  end

  it 'cleans up the temp directory' do
    expect(subject).to receive(:cleanup).at_least(:once)
    subject.backup
  end
end

shared_examples 'a tar based frontend' do
  it 'doesnt stop any services' do
    expect(subject).to_not receive(:stop_service)
    subject.backup
  end

  it 'doesnt dump the db' do
    expect(subject).to_not receive(:dump_db)
    subject.backup
  end
end

shared_examples 'a tar based online backend' do
  it "doesn't start any services" do
    expect(subject).to_not receive(:start_service)
    subject.backup
  end

  it "doesn't stop any services" do
    expect(subject).to_not receive(:stop_service)
    subject.backup
  end

  it 'dumps the db' do
    expect(subject).to receive(:dump_db).once
    subject.backup
  end
end

shared_examples 'a tar based offline backend' do
  it 'stops all services besides keepalived and postgres' do
    expect(subject).to receive(:stop_chef_server).once

    %w(postgresql keepalived).each do |service|
      expect(subject).to_not receive(:stop_service).with(service)
    end

    subject.backup
  end

  it 'starts all the services again' do
    expect(subject).to receive(:start_chef_server).at_least(:once)
    subject.backup
  end

  it 'dumps the db' do
    expect(subject).to receive(:dump_db).once
    subject.backup
  end
end
