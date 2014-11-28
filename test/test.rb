ENV["RACK_ENV"] = "test"

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    project_name "HookHand"
    add_filter "/test/"
    add_filter "/vendor/"
    coverage_dir "test/coverage"
    minimum_coverage 100
  end
end

require "minitest/autorun"
require "rack/test"
require File.expand_path("#{File.dirname(__FILE__)}/../hookhand.rb")

def home
  File.expand_path("#{File.dirname(__FILE__)}/tmp")
end

def scripts
  File.expand_path("#{File.dirname(__FILE__)}/scripts/")
end

cleanup = Proc.new { FileUtils.rm_rf home; FileUtils.rm_rf scripts }
cleanup.call
MiniTest::Unit.after_tests &cleanup

class HookHandTest < MiniTest::Unit::TestCase
  include Rack::Test::Methods

  def app
    Hookhand.new
  end

  def setup
    FileUtils.mkdir_p home
    ENV["HOME"] = home
    ENV["SCRIPTS_GIT_USERNAME"] = "test"
    ENV["SCRIPTS_GIT_REPO"] = \
      "https://github.com/mikemcquaid/HookHandTestScripts"
  end

  def test_welcome
    get "/"
    assert last_response.ok?
    assert_equal "Welcome to HookHand!", last_response.body
  end

  def test_invalid_scripts_repo
    FileUtils.rm_rf scripts
    FileUtils.mkdir_p scripts
    ENV["SCRIPTS_GIT_REPO"] = "git://invalid/repository"
    assert_raises(RuntimeError) { get "/" }
  end

  def test_missing_script
    get "/notthetest/"
    assert last_response.not_found?
  end

  def test_failed_script
    get "/false/"
    assert last_response.server_error?
  end

  def test_post_form_script
    post "/test/a/b/c/", { testing: :a }
    assert last_response.ok?
    assert_includes last_response.body, "parameters: a b c"
    assert_includes last_response.body, "HOOKHAND_TESTING=a"
  end

  def test_post_json_script
    post "/test/1/2/3/",
      { testing_again: "b", more_test: [[[1, 2], 3], 4] }.to_json,
      { "CONTENT_TYPE" => "application/json" }
    assert last_response.ok?
    assert_includes last_response.body, "parameters: 1 2 3"
    assert_includes last_response.body, "HOOKHAND_TESTING_AGAIN=b"
  end
end
