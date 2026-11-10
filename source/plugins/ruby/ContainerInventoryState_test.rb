require "minitest/autorun"
require "tmpdir"
require "fileutils"
require "logger"
require "stringio"
require_relative "ContainerInventoryState"

class ContainerInventoryStateTests < Minitest::Test
  def setup
    @directory = Dir.mktmpdir("container-inventory-")
    @inventory = File.join(@directory, "inventory")
    Dir.mkdir(@inventory)
    @previous_directory = ContainerInventoryState.class_variable_get(:@@InventoryDirectory)
    ContainerInventoryState.class_variable_set(:@@InventoryDirectory, @inventory + File::SEPARATOR)
    @previous_log = $log
    @log_output = StringIO.new
    $log = Logger.new(@log_output)
  end

  def teardown
    ContainerInventoryState.class_variable_set(:@@InventoryDirectory, @previous_directory)
    $log = @previous_log
    FileUtils.remove_entry(@directory)
  end

  def test_valid_id_lifecycle
    ["12345", "a" * 64, "A12b34", "a1b2-1234-5678-90ab", "runtime.id+v1_2-3", ".runtime-id", "_id", "+id", "-id", "a" * 255].each do |id|
      container = { "InstanceID" => id, "State" => "Running" }
      ContainerInventoryState.writeContainerState(container)
      container["State"] = "Terminated"
      ContainerInventoryState.writeContainerState(container)
      assert_equal [id], ContainerInventoryState.getDeletedContainers([])
      assert_empty ContainerInventoryState.getDeletedContainers([id])
      assert_equal container, ContainerInventoryState.readContainerState(id)
      refute File.exist?(File.join(@inventory, id))
    end
  end

  def test_invalid_ids_cannot_write_read_or_delete_outside_state
    sentinel = File.join(@directory, "sentinel")
    original = { "InstanceID" => "sentinel", "State" => "Running" }.to_json
    File.write(sentinel, original)
    invalid_ids = [
      nil, "", 42, false, ["id"], { "id" => "value" },
      ".", "..", "../sentinel", "nested/../../sentinel", sentinel, "/tmp/container-state",
      '..\sentinel', 'C:\sentinel', "C:sentinel", '\\\\server\share\sentinel',
      "nested/id", "id//suffix", "id:stream", "id\0", "id\n", "id\r", "id\t",
      "id ", "id.", "%2e%2e%2fsentinel", "id*", "id?", "id|",
      "CON", "nul.json", "COM1", "lpt9.txt", "a" * 256
    ]
    invalid_ids.each do |id|
      ContainerInventoryState.writeContainerState({ "InstanceID" => id })
      assert_nil ContainerInventoryState.readContainerState(id), id.inspect
      assert_equal original, File.read(sentinel), id.inspect
      assert_empty Dir.children(@inventory), id.inspect
    end
    assert_includes @log_output.string, "Invalid container ID"
  end

  def test_symlinks_and_directories_are_not_container_state
    sentinel = File.join(@directory, "sentinel")
    original = { "InstanceID" => "sentinel" }.to_json
    File.write(sentinel, original)
    { "link" => sentinel, "dangling" => File.join(@directory, "absent") }.each do |id, target|
      File.symlink(target, File.join(@inventory, id))
      ContainerInventoryState.writeContainerState({ "InstanceID" => id })
      assert_nil ContainerInventoryState.readContainerState(id)
      assert File.symlink?(File.join(@inventory, id))
    end
    Dir.mkdir(File.join(@inventory, "directory"))
    ContainerInventoryState.writeContainerState({ "InstanceID" => "directory" })
    assert_nil ContainerInventoryState.readContainerState("directory")
    File.write(File.join(@inventory, "invalid:name"), original)
    assert_empty ContainerInventoryState.getDeletedContainers([])
    assert_equal original, File.read(sentinel)
    refute File.exist?(File.join(@directory, "absent"))
  end

  def test_parent_traversal_does_not_change_outside_file
    sentinel = File.join(@directory, "sentinel")
    original = { "InstanceID" => "sentinel", "State" => "Running" }.to_json
    File.write(sentinel, original)
    ContainerInventoryState.writeContainerState({ "InstanceID" => "../sentinel" })
    assert_equal original, File.read(sentinel)
    assert_nil ContainerInventoryState.readContainerState("../sentinel")
    assert_equal original, File.read(sentinel)
  end

  def test_serialization_and_read_failures_preserve_existing_state
    path = File.join(@inventory, "good-id")
    original = { "InstanceID" => "good-id", "State" => "Running" }.to_json
    File.write(path, original)
    container = { "InstanceID" => "good-id" }
    container["cycle"] = container
    ContainerInventoryState.writeContainerState(container)
    assert_equal original, File.read(path)
    File.write(path, "invalid json")
    assert_nil ContainerInventoryState.readContainerState("good-id")
    assert File.file?(path)
  end
end
