# kitchen-vcair

[![Gem Version](https://badge.fury.io/rb/kitchen-vcair.svg)](https://badge.fury.io/rb/kitchen-vcair)

A [Test Kitchen](https://kitchen.ci/) driver that creates and destroys VMware vCloud Air virtual machines, so you can test your cookbooks and infrastructure code against them.

> **Note:** VMware's vCloud Air service has been discontinued. This driver is
> useful only against a vCloud Director based deployment that still exposes the
> vCloud Air API, such as an environment migrated to another provider. If you
> are choosing a driver for a new project, this is probably not the one you
> want.

<!-- -->

> This documentation uses [Cinc Workstation](https://cinc.sh/) and the `cinc` commands throughout. Everything here works identically with Chef Workstation — see [Using with Chef](#using-with-chef).

## Requirements

- Ruby 3.1 or later (already satisfied if you use Cinc Workstation)
- Access to a vCloud Air or vCloud Director deployment
- An account with permission to instantiate and delete vApps
- Network access from the machine running Test Kitchen to the network your test
  VMs are deployed on — see [NAT and public IPs](#nat-and-public-ips)

## Installation

This driver ships as part of [Cinc Workstation](https://cinc.sh/start/workstation/). If you have Cinc Workstation installed, there is nothing else to install.

To install it into a standalone Ruby:

```sh
gem install kitchen-vcair
```

Or with Bundler, add it to your `Gemfile`:

```ruby
gem "kitchen-vcair"
```

...then run `bundle install`.

## Quick Start

```yaml
---
driver:
  name: vcair
  vcair_username: user@domain.com
  vcair_password: <%= ENV['VCAIR_PASSWORD'] %>
  vcair_api_host: some-host.vchs.vmware.com
  vcair_org: M12345678-4321
  vdc_name: MyCompany VDC 1
  network_name: vdc1-default-routed
  catalog_name: Public Catalog
  image_name: CentOS64-64BIT
  vm_password: <%= ENV['VCAIR_VM_PASSWORD'] %>

provisioner:
  name: cinc_infra

verifier:
  name: cinc_auditor

transport:
  password: <%= ENV['VCAIR_VM_PASSWORD'] %>

platforms:
  - name: centos

suites:
  - name: default
    run_list:
      - recipe[my_cookbook::default]
```

Then run the full test cycle:

```sh
cinc kitchen test
```

Or step through it:

```sh
cinc kitchen create    # instantiate the vApp and power it on
cinc kitchen converge  # apply your cookbook
cinc kitchen verify    # run your tests
cinc kitchen destroy   # delete the vApp
```

Note that `vm_password` and the transport's `password` must match. See
[SSH authentication](#ssh-authentication) for why.

## Configuration

All options can be set globally under the top-level `driver:` key, or per platform under `platforms[].driver:`. A common split is to set the vDC and network globally and the catalog, image, and sizing per platform.

### Credentials

| Option | Default | Description |
| --- | --- | --- |
| `vcair_username` | *none* | Username to authenticate with, e.g. `user@domain.com`. Required. |
| `vcair_password` | *none* | Password to authenticate with. Required. |
| `vcair_api_host` | *none* | API hostname, e.g. `some-host.vchs.vmware.com`. Required. |
| `vcair_org` | *none* | Organization ID, e.g. `M12345678-4321`. Required. |
| `vcair_api_path` | `"/api"` | URI path for the compute API. Must be `/api/compute/api` on vCloud Air OnDemand. |
| `vcair_api_version` | *library default* | vCloud Director API version to request. |

### Placement

Each of these pairs takes either an ID or a name. One of each pair is required.

| Option | Default | Description |
| --- | --- | --- |
| `vdc_id` / `vdc_name` | *none* | The vDC to create the vApp in. Required. |
| `catalog_id` / `catalog_name` | *none* | The catalog holding your image or template. Required. |
| `image_id` / `image_name` | *none* | The image to create the VM from. Required. |
| `network_id` / `network_name` | *none* | The network to attach the VM to. Required. |

### Machine

| Option | Default | Description |
| --- | --- | --- |
| `cpus` | `1` | Number of vCPUs. |
| `memory` | `1024` | RAM in MB. |
| `node_name` | generated, `tk-<random>` | Name of the VM. Must be 15 characters or fewer, contain only letters, digits and hyphens, not start or end with a hyphen, and not be all digits — the constraints Windows imposes on a computer name. |
| `node_description` | `Test Kitchen: <node_name>` | Description recorded on the vApp. |

### Guest customization

| Option | Default | Description |
| --- | --- | --- |
| `vm_password` | *unset* | Password set for the root or Administrator user through guest customization. Must match the transport's `password`. |
| `customization_script` | *unset* | Path to a guest customization script. Must exist and be readable, or the run fails immediately. Required for Windows — see [WinRM](#winrm). |

### Timing

| Option | Default | Description |
| --- | --- | --- |
| `wait_for` | `600` | Seconds to wait for the VM to become ready before timing out. |

## Subscription vs. OnDemand

The driver works as-is against vCloud Air Subscription. OnDemand exposes the
compute API at a different path, so set:

```yaml
driver:
  vcair_api_path: /api/compute/api
```

Many of the VMware-provided public catalog images are missing core
configuration, such as working DNS resolvers. Building your own images from
them, with proper configuration, is strongly recommended.

## SSH authentication

vCloud Air does not deploy SSH keys to new VMs the way other cloud providers do,
so many public catalog images support password authentication only.

Set the password through guest customization and give the transport the same
value:

```yaml
driver:
  vm_password: <%= ENV['VCAIR_VM_PASSWORD'] %>

transport:
  password: <%= ENV['VCAIR_VM_PASSWORD'] %>
```

Using the password vCloud Air generates itself is **not supported**: a bug in
Fog prevents the driver from retrieving it.

## WinRM

Windows instances need more setup than Linux ones.

Most public catalog Windows images do not have WinRM enabled, so you must supply
a customization script that enables it. A working example is in the
[`examples/`](examples/) directory as `windows_customization.bat`.

The customization mechanism that sets a password on Linux does not work on
Windows, and Windows does not honour the customization setting that disables the
forced password change at first login. The customization script therefore has to
set the Administrator password as well, which the bundled example does.

Expect Windows instances to take a long time to become ready — several reboots
are required before Test Kitchen can connect. Publishing your own image with
WinRM already enabled and configured avoids most of this.

## NAT and public IPs

vCloud Air does not treat public IPs as objects that attach to VMs. They attach
to network objects called gateways, which then need NAT and firewall rules, and
the Fog library cannot create those.

As a result **only routed networks are supported**, and Test Kitchen must be run
from a machine on a network inside vCloud Air with access to the network your
test VMs are deployed on.

## Examples

### Global settings with per-platform images

```yaml
driver:
  name: vcair
  vcair_username: user@domain.com
  vcair_password: <%= ENV['VCAIR_PASSWORD'] %>
  vcair_api_host: some-host.vchs.vmware.com
  vcair_org: M12345678-4321
  vdc_name: MyCompany VDC 1
  network_name: vdc1-default-routed

platforms:
  - name: centos
    driver:
      catalog_name: Public Catalog
      image_name: CentOS64-64BIT
  - name: windows
    driver:
      catalog_name: Public Catalog
      image_name: W2K12-STD-R2-64BIT
      cpus: 2
      memory: 4096
      customization_script: examples/windows_customization.bat
```

### vCloud Air OnDemand

```yaml
driver:
  name: vcair
  vcair_api_host: some-host.vchs.vmware.com
  vcair_api_path: /api/compute/api
  vcair_org: M12345678-4321
  vcair_username: user@domain.com
  vcair_password: <%= ENV['VCAIR_PASSWORD'] %>
```

### Naming the VM explicitly

```yaml
driver:
  name: vcair
  node_name: tk-web01
  node_description: Test Kitchen web server suite
```

### A slow environment

```yaml
driver:
  name: vcair
  wait_for: 1800
```

## Troubleshooting

**"Node name is not valid."** `node_name` must be 15 characters or fewer, use
only letters, digits and hyphens, not begin or end with a hyphen, and not be
entirely digits. Those are Windows computer name rules, and the driver applies
them to every platform.

**"Customization script ... is not found or not readable."** The path in
`customization_script` is resolved from where you run Test Kitchen. Check the
path and the file's permissions.

**Test Kitchen cannot connect over SSH.** Confirm `vm_password` and the
transport's `password` are the same value, and that your machine can reach the
test network directly — see [NAT and public IPs](#nat-and-public-ips).

**A Windows instance never becomes ready.** Confirm the customization script
enables WinRM, and raise `wait_for`; several reboots are expected.

## Using with Chef

This driver is not tied to Cinc. The examples above use Cinc Workstation and the `cinc_infra` provisioner, but the driver works exactly the same with [Chef Workstation](https://www.chef.io/downloads/tools/workstation) — run `kitchen` instead of `cinc kitchen`, and use `chef_infra` instead of `cinc_infra`:

```yaml
provisioner:
  name: chef_infra

verifier:
  name: inspec
```

No driver configuration changes are needed.

## Contributing

We'd love to hear from you if this doesn't perform the way you expect. Bug reports and pull requests are welcome on [GitHub](https://github.com/test-kitchen/kitchen-vcair). See [CONTRIBUTING.md](CONTRIBUTING.md) for development setup, how to run the tests, and the release process.

## License and Authors

Author: Chef Partner Engineering (<partnereng@chef.io>)

Licensed under the Apache License, Version 2.0. See [LICENSE](LICENSE) for details.
