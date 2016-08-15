ENV["RACK_ENV"] = "test"

HOOKHAND_ROOT = File.expand_path "#{File.dirname(__FILE__)}/../"

if ENV["COVERAGE"]
  require "simplecov"
  SimpleCov.start do
    project_name "HookHand"
    add_filter "/test/"
    add_filter "/vendor/"
    coverage_dir "#{HOOKHAND_ROOT}/test/coverage"
    minimum_coverage 100
  end
end

require "minitest/autorun"
require "rack/test"
require "#{HOOKHAND_ROOT}/hookhand.rb"

def scripts
  File.expand_path "#{HOOKHAND_ROOT}/test/scripts"
end

cleanup = Proc.new { FileUtils.rm_rf scripts }
cleanup.call
MiniTest.after_run(&cleanup)

class HookHandTest < Minitest::Test
  include Rack::Test::Methods

  def app
    Hookhand.new
  end

  def setup
    ENV["SCRIPTS_DIR"] = scripts
    ENV["SCRIPTS_GIT_USERNAME"] = "test"
    ENV["SCRIPTS_GIT_REPO"] = \
      "https://github.com/mikemcquaid/HookHandTestScripts"
    ENV.delete "REQUEST_TIMEOUT"
  end

  def test_raise_exception
    assert_raises(RuntimeError) { get "/_raise_test_exception" }
  end

  def test_welcome
    get "/"
    assert last_response.ok?
    assert_equal "Welcome to HookHand!", last_response.body
  end

  def test_default_scripts_dir
    ENV.delete "SCRIPTS_DIR"
    get "/"
    assert last_response.ok?
  end

  def test_set_existing_scripts_dir
    ENV.delete "SCRIPTS_GIT_REPO"
    FileUtils.mkdir_p ENV["SCRIPTS_DIR"]
    assert File.directory? ENV["SCRIPTS_DIR"]
    get "/"
    assert last_response.ok?
  end

  def test_set_missing_scripts_dir
    ENV.delete "SCRIPTS_GIT_REPO"
    ENV["SCRIPTS_DIR"] = "./a/missing/directory"
    assert !File.directory?(ENV["SCRIPTS_DIR"])
    assert_raises(RuntimeError) { get "/" }
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

  def test_timeout_script
    ENV["REQUEST_TIMEOUT"] = "1"
    get "/sleep/"
    assert last_response.server_error?, last_response.body
  end

  def test_background_script
    ENV["REQUEST_TIMEOUT"] = "1"
    get "/sleep/", { background: true }
    assert_equal last_response.status, 202
  end

  def test_post_form_script
    post "/test/a/b/c/", { testing: :a }
    assert last_response.ok?
    assert_includes last_response.body, "parameters: a b c"
    assert_includes last_response.body, "HOOKHAND_TESTING=a"
  end

  def test_post_json_script
    header "X-GitHub-Event", "ping"
    post "/test/1/2/3/",
      { testing_again: "b", more_test: [[[1, 2], 3], 4] }.to_json,
      { "CONTENT_TYPE" => "application/json" }
    assert last_response.ok?
    assert_includes last_response.body, "parameters: 1 2 3"
    assert_includes last_response.body, "HOOKHAND_TESTING_AGAIN=b"
  end
end
