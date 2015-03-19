shared_examples '.tmp_dir with a nonexisting specified directory' do
  it 'uses the specified directory' do
    expect(FileUtils).to receive(:mkdir_p).with(tmp_dir_path)
    expect(subject.tmp_dir).to eq(tmp_dir_path)
  end
end

shared_examples '.tmp_dir with an existing specified directory' do
  it 'does not create a directory' do
    expect(FileUtils).to_not receive(:anything)
    expect(subject.tmp_dir).to eq(tmp_dir_path)
  end
end

shared_examples '.tmp_dir without a specified directory' do
  it 'creates a temp directory' do
    expect(Dir).to receive(:mktmpdir).with('chef_backup')
    subject.tmp_dir
  end
end
