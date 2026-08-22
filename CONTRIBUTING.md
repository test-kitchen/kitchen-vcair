# Contributing to kitchen-vcair

We'd love to hear from you if this driver doesn't perform the way you expect. Bug reports, feature requests, and pull requests are all welcome.

## Reporting issues

Report bugs and request features on the [issue tracker](https://github.com/test-kitchen/kitchen-vcair/issues). For bugs, please include:

- the version of kitchen-vcair and Test Kitchen you are using
- whether you are on vCloud Air Subscription, OnDemand, or another vCloud
  Director deployment
- your `kitchen.yml` with credentials, org IDs, and hostnames removed
- the output of the failing command, ideally with `-l debug`

## Development setup

Clone the repository and install the dependencies:

```sh
git clone https://github.com/test-kitchen/kitchen-vcair.git
cd kitchen-vcair
bundle install
```

## Running the tests

Run the unit tests and the style check together:

```sh
bundle exec rake
```

Run them individually:

```sh
bundle exec rake test    # RSpec unit tests
bundle exec rake style   # Cookstyle / RuboCop
```

To run a single spec file:

```sh
bundle exec rspec spec/kitchen/driver/vcair_spec.rb
```

Many style offenses can be corrected automatically:

```sh
bundle exec cookstyle -a
```

The unit tests stub Fog, so they neither create VMs nor require credentials.

## Manual testing

Changes that touch vApp instantiation, guest customization, or connectivity
should also be exercised against a real deployment, since the stubbed tests
cannot catch API-level regressions.

Bear in mind while testing:

- Only routed networks work, and Test Kitchen has to run from a machine with
  direct network access to the test VMs. There is no NAT or public IP support,
  because Fog cannot create gateway objects.
- Windows instances take a long time to come up and need a customization script
  to enable WinRM. `examples/windows_customization.bat` is a working starting
  point.
- Confirm the vApp was actually deleted after `kitchen destroy`; a run that
  fails partway through can leave one powered on.

## Submitting changes

1. Fork the repository.
2. Create a feature branch off `main`.
3. Make your change, adding or updating tests to cover it.
4. Make sure `bundle exec rake` passes.
5. Push the branch to your fork and open a pull request.

Please keep pull requests focused on a single change — it makes review much
faster. Update the documentation in `README.md` when you add or change a
configuration option.

## Release process

Releases are handled by the maintainers.

1. Update `lib/kitchen/driver/vcair_version.rb` with the new version.
2. Update `CHANGELOG.md`.
3. Merge to `main`; the [publish workflow](.github/workflows/publish.yml) builds
   the gem and pushes it to RubyGems.
