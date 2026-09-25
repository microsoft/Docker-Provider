require "minitest/autorun"
require "fluent/test"
require "logger"
require "net/http"
require "time"
require "timeout"
require_relative "in_kube_podinventory"

class InKubePodInventoryTests < Minitest::Test
  Watch = Struct.new(:events) do
    def each
      events.each do |event|
        yield(event.respond_to?(:call) ? event.call : event)
      end
    end

    def finish
    end
  end

  class ApiClient
    attr_accessor :responses, :node_events, :pod_events
    attr_reader :requests, :snapshots, :classifications, :watches

    def initialize(&cache_reader)
      @cache_reader = cache_reader
      @responses = []
      @node_events = []
      @pod_events = []
      @requests = []
      @snapshots = []
      @classifications = {}
      @watches = []
    end

    def getNodesResourceUri(uri)
      uri
    end

    def getResourcesAndContinuationTokenV2(uri)
      @requests << uri
      @snapshots << @cache_reader.call
      response = @responses.shift
      raise Minitest::Assertion, "Unexpected API request: #{uri}" unless response
      response.respond_to?(:call) ? response.call(uri) : response
    end

    def getWindowsNodesArray
      raise Minitest::Assertion, "Pod watcher must not fetch a separate node snapshot"
    end

    def getOptimizedItem(_resource, item, is_windows)
      @classifications[item["metadata"]["uid"]] = is_windows
      item
    end

    def watch(resource, **options)
      @watches << [resource, options]
      Watch.new(resource == "nodes" ? @node_events : @pod_events)
    end
  end

  def setup
    Fluent::Test.setup
    @previous_log = $log
    $log = Logger.new(File::NULL)
    @plugin_class = Fluent::Plugin::Kube_PodInventory_Input
    @plugin = @plugin_class.allocate
    @plugin.instance_variable_set(:@windowsNodeNameListCache, ["win-cached"])
    @plugin.instance_variable_set(:@podCacheRefreshRequested, false)
    @plugin.instance_variable_set(:@windowsNodeNameCacheMutex, Mutex.new)
    @plugin.instance_variable_set(:@finished, false)
    @plugin.instance_variable_set(:@podItemsCache, {})
    @plugin.instance_variable_set(:@podCacheMutex, Mutex.new)
    @plugin.instance_variable_set(:@NODES_CHUNK_SIZE, 2)
    @plugin.instance_variable_set(:@PODS_CHUNK_SIZE, 2)
    @plugin.define_singleton_method(:loop) { |&iteration| iteration.call }
    retry_delays = @retry_delays = []
    @plugin.define_singleton_method(:sleep) { |duration| retry_delays << duration }
    @api = ApiClient.new { cached_nodes }
    @plugin_class.const_set(:KubernetesApiClient, @api)
  end

  def teardown
    @plugin_class.send(:remove_const, :KubernetesApiClient)
    $log = @previous_log
  end

  def cached_nodes
    @plugin.instance_variable_get(:@windowsNodeNameListCache).dup
  end

  def node_inventory(names, version = "10")
    {
      "metadata" => { "resourceVersion" => version },
      "items" => names.map { |name| { "metadata" => { "name" => name } } },
    }
  end

  def pod_inventory(node_name = "win-new")
    {
      "metadata" => { "resourceVersion" => "11" },
      "items" => [{ "metadata" => { "uid" => "pod-1" }, "spec" => { "nodeName" => node_name } }],
    }
  end

  def node_event(type, name)
    { "type" => type, "object" => { "metadata" => { "name" => name, "resourceVersion" => "11" } } }
  end

  def test_paginated_node_list_is_published_atomically
    @api.responses = [["next-page", node_inventory(["win-a"]), "200"], [nil, node_inventory(["win-b"]), "200"]]

    @plugin.watch_windows_nodes

    assert_equal [["win-cached"], ["win-cached"]], @api.snapshots
    assert_equal ["win-a", "win-b"], cached_nodes
    assert_equal @api.requests.first + "&continue=next-page", @api.requests.last
    assert_equal "10", @api.watches.first.last[:resource_version]
    assert @plugin.instance_variable_get(:@podCacheRefreshRequested)
  end

  def test_valid_empty_node_list_clears_cache_without_requesting_a_relist
    @api.responses = [[nil, node_inventory([]), "200"]]

    @plugin.watch_windows_nodes

    assert_empty cached_nodes
    refute @plugin.instance_variable_get(:@podCacheRefreshRequested)
    assert_equal "nodes", @api.watches.first.first
  end

  def test_invalid_first_page_preserves_cache_without_requesting_a_relist
    @api.responses = [[nil, nil, "503"]]

    @plugin.watch_windows_nodes

    assert_equal ["win-cached"], cached_nodes
    refute @plugin.instance_variable_get(:@podCacheRefreshRequested)
    assert_empty @api.watches
    assert_equal [30], @retry_delays
  end

  def test_invalid_later_pages_preserve_complete_cache
    invalid_responses = [
      [nil, nil, "503"],
      [nil, nil, "200"],
      [nil, {}, "200"],
      [nil, { "metadata" => { "resourceVersion" => "10" } }, "200"],
      [nil, { "items" => [] }, "200"],
      [nil, node_inventory([], nil), "200"],
      [nil, node_inventory([], ""), "200"],
      [nil, node_inventory([], "0"), "200"],
      [nil, node_inventory(["win-b"], "11"), "200"],
      [nil, node_inventory([nil]), "200"],
    ]
    invalid_responses.each do |response|
      @api.responses = [["next-page", node_inventory(["win-a"]), "200"], response]

      @plugin.watch_windows_nodes

      assert_equal ["win-cached"], cached_nodes, "Invalid page: #{response.inspect}"
      assert_empty @api.watches
      refute @plugin.instance_variable_get(:@podCacheRefreshRequested)
    end
    assert_equal [30] * invalid_responses.length, @retry_delays
  end

  def test_node_watch_addition_during_pod_list_is_preserved
    @api.node_events = [node_event("ADDED", "win-new")]
    @api.responses = [lambda { |_uri| @plugin.watch_windows_nodes; [nil, pod_inventory, "200"] }, [nil, node_inventory(["win-cached"]), "200"]]

    @plugin.watch_pods

    assert_equal ["win-cached", "win-new"], cached_nodes
    assert_equal true, @api.classifications.fetch("pod-1")
  end

  def test_node_watch_deletion_during_pod_list_is_preserved
    @api.node_events = [node_event("DELETED", "win-cached")]
    @api.responses = [lambda { |_uri| @plugin.watch_windows_nodes; [nil, pod_inventory("win-cached"), "200"] }, [nil, node_inventory(["win-cached"]), "200"]]

    @plugin.watch_pods

    assert_empty cached_nodes
    assert_equal false, @api.classifications.fetch("pod-1")
  end

  def test_pod_relists_do_not_fetch_or_replace_the_node_cache
    original_cache = @plugin.instance_variable_get(:@windowsNodeNameListCache)
    @plugin.define_singleton_method(:loop) { |&iteration| 2.times(&iteration) }
    @api.pod_events = [{ "type" => "ERROR", "object" => {} }]
    @api.responses = [[nil, pod_inventory("win-cached"), "200"], [nil, pod_inventory("win-cached"), "200"]]

    @plugin.watch_pods

    assert_equal ["pods?limit=2", "pods?limit=2"], @api.requests
    assert_same original_cache, @plugin.instance_variable_get(:@windowsNodeNameListCache)
    assert_equal true, @api.classifications.fetch("pod-1")
  end

  def test_linux_pods_start_before_windows_node_discovery
    @plugin.instance_variable_set(:@windowsNodeNameListCache, [])
    linux_pods = pod_inventory("linux-node")
    @api.responses = [[nil, linux_pods, "200"]]

    Timeout.timeout(5) { @plugin.watch_pods }

    assert_equal ["pods?limit=2"], @api.requests
    assert_equal false, @api.classifications.fetch("pod-1")
    assert_equal linux_pods["items"].first, @plugin.instance_variable_get(:@podItemsCache).fetch("pod-1")
  end

  def test_linux_pods_continue_after_windows_node_discovery_fails
    @plugin.instance_variable_set(:@windowsNodeNameListCache, [])
    2.times do
      @api.responses = [[nil, nil, "503"]]
      @plugin.watch_windows_nodes
    end
    @api.responses = [[nil, pod_inventory("linux-node"), "200"]]

    Timeout.timeout(5) { @plugin.watch_pods }

    assert_equal false, @api.classifications.fetch("pod-1")
    assert_equal [30, 30], @retry_delays
    assert_equal "pods", @api.watches.last.first
    assert_equal ["pod-1"], @plugin.instance_variable_get(:@podItemsCache).keys
  end

  def test_linux_only_cluster_does_not_relist_pods_after_empty_node_discovery
    @plugin.instance_variable_set(:@windowsNodeNameListCache, [])
    @plugin.define_singleton_method(:loop) { |&iteration| 2.times(&iteration) }
    @api.responses = [[nil, node_inventory([]), "200"]]
    @plugin.watch_windows_nodes
    @api.responses = [[nil, pod_inventory("linux-node"), "200"]]

    @plugin.watch_pods

    assert_equal 1, @api.requests.count { |uri| uri.start_with?("pods?") }
    assert_equal 2, @api.watches.count { |resource, _options| resource == "pods" }
    assert_equal false, @api.classifications.fetch("pod-1")
  end

  def test_windows_node_discovery_during_pod_watch_triggers_recovery
    @plugin.instance_variable_set(:@windowsNodeNameListCache, [])
    @plugin.define_singleton_method(:loop) { |&iteration| 2.times(&iteration) }
    linux_pod = pod_inventory("linux-node")["items"].first
    linux_pod["metadata"]["uid"] = "pod-linux"
    mixed_pods = pod_inventory
    mixed_pods["items"] << linux_pod
    @api.responses = [[nil, mixed_pods, "200"], [nil, node_inventory(["win-new"]), "200"], [nil, mixed_pods, "200"]]
    @api.pod_events = [lambda {
      assert_equal false, @api.classifications.fetch("pod-1")
      @plugin.watch_windows_nodes
      @api.pod_events = []
      { "type" => "BOOKMARK", "object" => { "metadata" => { "resourceVersion" => "12" } } }
    }]

    @plugin.watch_pods

    assert_equal true, @api.classifications.fetch("pod-1")
    assert_equal false, @api.classifications.fetch("pod-linux")
    assert_equal 2, @api.requests.count { |uri| uri.start_with?("pods?") }
    assert_equal linux_pod, @plugin.instance_variable_get(:@podItemsCache).fetch("pod-linux")
    refute @plugin.instance_variable_get(:@podCacheRefreshRequested)
  end

  def test_windows_node_discovery_recovers_pods_after_idle_watch_timeout
    @plugin.instance_variable_set(:@windowsNodeNameListCache, [])
    @plugin.define_singleton_method(:loop) { |&iteration| 2.times(&iteration) }
    @api.responses = [[nil, pod_inventory, "200"], [nil, node_inventory(["win-new"]), "200"], [nil, pod_inventory, "200"]]
    @api.pod_events = [lambda {
      @plugin.watch_windows_nodes
      @api.pod_events = []
      raise Net::ReadTimeout
    }]

    @plugin.watch_pods

    assert_equal true, @api.classifications.fetch("pod-1")
    assert_equal 2, @api.requests.count { |uri| uri.start_with?("pods?") }
  end

  def test_unchanged_windows_nodes_do_not_request_another_pod_relist
    @api.responses = [[nil, node_inventory(["win-cached"]), "200"]]
    @api.node_events = [node_event("ADDED", "win-cached")]

    @plugin.watch_windows_nodes

    refute @plugin.instance_variable_get(:@podCacheRefreshRequested)
  end

  def test_pod_watcher_exits_if_shutdown_was_requested
    @plugin.instance_variable_set(:@finished, true)

    @plugin.watch_pods

    assert_empty @api.requests
    assert_empty @api.watches
  end
end