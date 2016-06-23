# HookHand
HookHand is a small web application which runs scripts from webhooks.

## Features
- Runs scripts from a cloned Git repository or local directory.
- Runs script and passes parameters based on URL path.
- Webhook metadata can be passed through POSTed JSON or form data and is exposed to the script as environment variables.
- Script output is returned as plain text.
- HTTP status code set based on script exit code.
- Run scripts in the background with `?background=1`.

## Usage
To use locally run:
```bash
git clone https://github.com/mikemcquaid/HookHand
cd HookHand
bundle install
SCRIPTS_GIT_REPO="..." foreman start
```

Alternatively, to deploy to [Heroku](https://www.heroku.com) click:

[![Deploy to Heroku](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

## Example
1. Run `SCRIPTS_GIT_REPO=https://github.com/mikemcquaid/HookHandTestScripts foreman start` to start the application and download the `HookHandTestScripts` repository.
2. Access [http://localhost:5000/test/a/b/c](http://localhost:5000/test/a/b/c) and see that it is running the [test script](https://github.com/mikemcquaid/HookHandTestScripts/blob/master/test) and passing parameters `a b c`.
3. Deploy to a server and set up a webhook with `http://yourserver/test/a/b/c` as the Payload URL and see that the webhook variables are exported in the format e.g. `HOOKHAND_REPOSITORY_CREATED_AT=1412962305`. If it's a private repository set the username and password with the `SCRIPTS_GIT_USERNAME` and `SCRIPTS_GIT_PASSWORD` environment variables (or set `SCRIPTS_GIT_PASSWORD` to a personal access token).

## Configuration Environment Variables
- `REQUEST_TIMEOUT`: the number of seconds a script is allowed to run for before being killed. Defaults to 25.
- `SCRIPTS_DIR`: a path to the directory either storing the scripts or a destination to clone `SCRIPTS_GIT_REPO` into. Defaults to `./scripts/` relative to the working directory.
- `SCRIPTS_GIT_REPO`: the Git repository to clone for scripts.
- `SCRIPTS_GIT_USERNAME`: the HTTP username for accessing a private Git repository.
- `SCRIPTS_GIT_PASSWORD`: the HTTP password for accessing a private Git repository. Alternatively, a GitHub personal access token.
- `WEB_CONCURRENCY`: the number of Unicorn (web server) processes to run.

## Status
The above features are implemented. Will fix bugs that come along but want to avoid scope-creep.

[![Build Status](https://travis-ci.org/MikeMcQuaid/HookHand.svg?branch=master)](https://travis-ci.org/MikeMcQuaid/HookHand)

## Contact
[Mike McQuaid](mailto:mike@mikemcquaid.com)

## License
HookHand is licensed under the [MIT License](http://en.wikipedia.org/wiki/MIT_License).
The full license text is available in [LICENSE.txt](https://github.com/mikemcquaid/HookHand/blob/master/LICENSE.txt).
