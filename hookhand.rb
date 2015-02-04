require "rack/request"
require "rack/response"
require "json"
require "awesome_print" if ENV["RACK_ENV"] == "development"

# Let's timeout by default after 25s as e.g. Heroku times out after 30s.
DEFAULT_REQUEST_TIMEOUT = 25

class Hookhand
  def initialize
    @request_timeout_seconds = if ENV["REQUEST_TIMEOUT"]
      ENV["REQUEST_TIMEOUT"].to_i
    else
      DEFAULT_REQUEST_TIMEOUT
    end

    scripts = ENV["RACK_ENV"] == "test" ? "test/scripts" : "scripts"
    @scripts_dir = Pathname.new File.expand_path "#{File.dirname(__FILE__)}/scripts/"

    # Only run Git operations on the first Unicorn worker.
    # This is a filthy hack to prevent clobbering the same scripts Git
    # directory when we have multiple Unicorn workers.
    return if /unicorn worker\[([1-9])\d*\]/ =~ $0

    repo = ENV["SCRIPTS_GIT_REPO"]
    return if repo.to_s.empty?

    unless ENV["SCRIPTS_GIT_USERNAME"].to_s.empty?
      hostname = URI(repo).host
      username = ENV["SCRIPTS_GIT_USERNAME"]
      password = ENV["SCRIPTS_GIT_PASSWORD"]
      netrc_line = "machine #{hostname} login #{username} password #{password}\n"

      netrc_path = Pathname.new "#{ENV["HOME"]}/.netrc"
      if netrc_path.exist?
        netrc = netrc_path.read
        unless netrc.include?(netrc_line)
          File.open(netrc_path, "a") {|f| f.write netrc_line }
        end
      else
        netrc_path.write netrc_line
      end
    end

    if @scripts_dir.exist?
      Dir.chdir @scripts_dir do
        if repo == `git config --local remote.origin.url`.chomp
          system "git", "pull", "--quiet"
          raise "Updating #{repo} failed!" unless $?.success?
        else
          FileUtils.rm_rf @scripts_dir
        end
      end
    end

    unless @scripts_dir.exist?
      system "git", "clone", repo, @scripts_dir.to_s, err: "/dev/null"
      raise "Cloning #{repo} failed!" unless $?.success?
    end
  end

  # Always prefix environment variables to avoid environment injection.
  def env_from_parameters parameters, key_prefix="hookhand"
    env = {}
    parameters.each do |key, value|
      if key.is_a? Enumerable
        env.merge! env_from_parameters(key, key_prefix)
        next
      end

      env_key = "#{key_prefix.upcase}_#{key.to_s.upcase}"
      if value.is_a? Enumerable
        env.merge! env_from_parameters(value, env_key)
      else
        env[env_key] = value.to_s
      end
    end
    env
  end

  def call environment
    start_time = Time.now.to_i
    request = Rack::Request.new environment
    script_file, *path_parameters = *request.path.split("/").reject(&:empty?)

    raise "Raised test exception!" if script_file == "_raise_test_exception"

    # Rather than just using `script_file` instead look through the `./scripts/`
    # directory and find the first executable file that is named the same. This
    # whitelist approach will prevent attempts to run scripts outside the
    # `./scripts` directory.
    script_path = nil
    if @scripts_dir.exist?
      @scripts_dir.find do |scripts_file|
        next if scripts_file.directory?
        next unless scripts_file.executable_real?
        next unless scripts_file.basename.to_s == script_file
        script_path = scripts_file
        break
      end
    end

    if script_path
      request_parameters = case request.content_type
      when "application/json"
        body = request.body.read
        JSON.parse body
      when "application/x-www-form-urlencoded"
        request.params
      else []
      end

      env = env_from_parameters request_parameters
      env["HOOKHAND"] = "1"
      if (event = request.env["HTTP_X_GITHUB_EVENT"])
        env["HOOKHAND_X_GITHUB_EVENT"] = event
      end

      body = <<-EOS
Running script '#{script_file}' with parameters #{path_parameters}:
---
EOS
      # Use popen with a parameters array to avoid creating a subshell which
      # could allow running commands we don't want to allow. Instead, use the
      # `script_path` obtained above as the command name and pass the remaining
      # parameters as an array.
      script_process = Bundler.with_clean_env do
        ENV["PATH"] = "#{ENV["PATH"]}:#{@scripts_dir}"
        IO.popen env, [script_path.to_s, *path_parameters],
                           err: [:child, :out]
      end

      timeout = @request_timeout_seconds - (start_time - Time.now.to_i)

      begin
        raise Timeout::Error unless timeout > 0
        Timeout::timeout(timeout) do
          body += script_process.read
        end
      rescue Timeout::Error
        body += "---\nTimed out after #{@request_timeout_seconds} seconds!\n"
      end

      # Give the script a second to shut down gracefully then kill it hard.
      Process.kill "INT", script_process.pid
      sleep 1
      Process.kill "TERM", script_process.pid

      script_process.close
      script_success = $?.success?

      script_status_message = if script_success
        "successfully :D"
      else
        "unsuccessfully :("
      end
      body += <<-EOS
---
Ran script '#{script_file}' #{script_status_message}
EOS
      status_code = if script_success
        200
      else
        500
      end
    elsif script_file
      body = "No script named '#{script_file}' found!"
      status_code = 404
    else
      body = "Welcome to HookHand!"
      status_code = 200
    end

    Rack::Response.new(body, status_code).finish
  end
end
