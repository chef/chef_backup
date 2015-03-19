require 'spec_helper'

shared_examples 'a tar based restore' do
  it "cleanse's the chef server" do
    expect(subject).to receive(:cleanse_chef_server).once
    subject.restore
  end

  it 'restores the configs' do
    configs.each do |config|
      expect(subject).to receive(:restore_data).with(:configs, config).once
    end
    subject.restore
  end

  it 'touches the bootstrap sentinel file' do
    expect(subject).to receive(:touch_sentinel).once
    subject.restore
  end

  it 'reconfigures the server' do
    expect(subject).to receive(:reconfigure_server).once
    subject.restore
  end

  it 'updates the config' do
    expect(subject).to receive(:update_config).once
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

shared_examples 'a tar based frontend restore' do
  it 'does not restore services' do
    expect(subject).to_not receive(:restore_services)
    subject.restore
  end

  it 'does not start postgres' do
    expect(subject).to_not receive(:start_service).with(:postgresql)
    subject.restore
  end

  it 'does not attempt to import a database' do
    expect(subject).to_not receive(:import_db)
    subject.restore
  end
end

shared_examples 'a tar based backend restore' do
  it 'restores the stateful services' do
    services.each do |service|
      expect(subject)
        .to receive(:restore_data)
        .with(:services, service)
        .once
    end
    subject.restore
  end
end

shared_examples 'a tar based backend restore with db dump' do
  it 'restores the db dump' do
    expect(subject).to receive(:import_db)
    subject.restore
  end
end

shared_examples 'a tar based backend restore without db dump' do
  it 'does not try to import a db dump' do
    expect(subject).to_not receive(:import_db)
    expect(subject).to_not receive(:start_service).with(:postgresql)
    subject.restore
  end
end
