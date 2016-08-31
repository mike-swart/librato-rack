require 'test_helper'
require 'rack/test'

# Tests for universal tracking for all request paths
#
class CustomTest < Minitest::Test
  include Rack::Test::Methods
  include EnvironmentHelpers

  def app
    Rack::Builder.parse_file('test/apps/custom.ru').first
  end

  def setup
    ENV["LIBRATO_TAGS"] = "hostname=metrics-web-stg-1"
    @tags = { hostname: "metrics-web-stg-1" }
  end

  def teardown
    # clear metrics before each run
    aggregate.delete_all
    counters.delete_all
    clear_config_env_vars
  end

  def test_increment
    get '/increment'
    assert_equal 1, counters[:hits]
    2.times { get '/increment' }
    assert_equal 3, counters[:hits]
  end

  def test_measure
    get '/measure'
    assert_equal 3.0, aggregate.fetch(:nodes, @tags)[:sum]
    assert_equal 1, aggregate.fetch(:nodes, @tags)[:count]
  end

  def test_timing
    get '/timing'
    assert_equal 1, aggregate.fetch("lookup.time", @tags)[:count]
  end

  def test_timing_block
    get '/timing_block'
    assert_equal 1, aggregate['sleeper'][:count]
    assert_in_delta 10, aggregate['sleeper'][:sum], 10
  end

  def test_grouping
    get '/group'
    assert_equal 1, counters['did.a.thing']
    assert_equal 1, aggregate['did.a.timing'][:count]
  end

  def test_tags
    tags = { region: "us-east-1" }
    get '/tags'
    assert_equal 1, counters.fetch("requests", tags: tags)
    assert_equal 1, aggregate.fetch("requests.time", tags: tags)[:count]
  end

  private

  def aggregate
    Librato.tracker.collector.aggregate
  end

  def counters
    Librato.tracker.collector.counters
  end

end
