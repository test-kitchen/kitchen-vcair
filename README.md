# kitchen-vcair

A driver to allow Test Kitchen to consume vCloud Air resources to perform testing.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'kitchen-vcair'
```

And then execute:

`bundle`

Or install it yourself as:

`gem install kitchen-vcair`

Or even better, install it via ChefDK:

`chef gem install kitchen-vcair`

## Usage

After installing the gem as described above, edit your .kitchen.yml file to set the driver to 'vcair' and supply your login credentials:

```yaml
driver:
  name: vcair
  vcair_username: user@domain.com
  vcair_password: MyS33kretPassword
  vcair_api_host: some-host.vchs.vmware.com
  vcair_org: M12345678-4321
```

Additionally, the following parameters are required:

 * **vdc_id** or **vdc_name**: The ID or name of the vDC in which to create your vApp/VM.
 * **catalog_id** or **catalog_name**: The ID or name of the catalog that contains your image/template.
 * **image_id** or **image_name**: The ID or name of the image you wish to use to create your VM.
 * **network_id** or **network_name**: The ID or name of the network to which to attach to your VM.

There are a number of optional parameters you can configure as well:

 * **cpus**: The number of vCPUs to configure for your VM. Default: 1
 * **memory**: The amount of RAM, in MB, to configure for your VM. Default: 1024
 * **vcair_api_path**: The URI path for the compute API. This needs to be set when using vCloud Air OnDemand. Default: /api
 * **vm_password**: The password to set via VM customization for the root/administrator user.
   * Be sure to set the same password in your `transport` section, too!
   * NOTE: see the *known issues* section below regarding Windows and passwords.

All of the above settings can be set globally (in the top-level `driver` section), or can be set individually for each platform. For example, you may wish to set your vDC and network globally, but set your catalog and image for each individual platform, and increase the vCPUs/RAM assigned to your windows node:

```yaml
driver:
  name: vcair
  vcair_username: user@domain.com
  vcair_password: MyS33kretPassword
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
```

### vCloud Air Subscription vs. OnDemand

kitchen-vcair works as-is with vCloud Air Subscription. In vCloud Air OnDemand,
the API path is different. To use this plugin with vCloud Air OnDemand, you
will need to set the `vcair_api_path` configuration parameter to `/api/compute/api`:

```yaml
driver:
  vcair_api_path: /api/compute/api
```

Also, in our testing, we found many of the VMware-provided images are missing
core configurations, such as properly-configured DNS resolvers. We strongly
recommend building your own images off the VMware-provided images with proper
configurations.

## Known Issues and Workarounds

### SSH Authentication - passwords vs. public-key

vCloud Air does not natively support deploying SSH keys to new VMs like other
cloud providers. Therefore, many of the images in the vCloud Air public catalog
only support password authentication.

#### Setting your own password

Through VM customization, vCloud Air allows you to specify a password that should
be set for the root account.  You can use the `vm_password` config parameter to
specify that password:

```yaml
driver:
  vm_password: mysupersecretpassword
```

... and then tell the transport to use that same password:

```yaml
transport:
  password: mysupersecretpassword
```

#### Using the pre-generated password by vCloud Air

**This is not supported.** Unfortunately, a bug in Fog prevents us from
retrieving that password, and a issue/PR will be logged to address this.

### WinRM Authentication

#### Setup

Many of the images in the vCloud Air public catalog do not have WinRM enabled.
You will need to provide a customization script to enable WinRM.  An example
can be found in the `examples/` directory in this repo.  Note that multiple
reboots are required for the VM to become ready for Test Kitchen to use, so
the time required for a Windows VM to be ready is fairly long.

A potential workaround to this would be to create your own VM with WinRM enabled
and configured properly and publish it in your own catalog.

#### Setting your own password

The same customization function that works for Linux does not appear to work for
Windows in vCloud Air. Additionally, Windows does not appear to honor the
customization setting that disables the forced password change on first login.

Therefore, a customization script will need to be used to set your Administrator
password. See the `examples/` directory for a sample customization script that
enables WinRM and sets the Administrator password.

### NAT and Public IP Support

Unlike other cloud providers, vCloud Air does not treat public IPs as objects
that can be associated with VMs. Instead, those IPs are associated with network
objects called "gateways" which then require NAT and firewall rules to be
created.  The Fog library does not support the creation of those objects.

Therefore, only routed networks are supported, and it is required that Test
Kitchen be executed on a network within vCloud Air that has access to the
destination network on which your test VMs will be deployed.

## License and Authors

Author:: Chef Partner Engineering (<partnereng@chef.io>)

Copyright:: Copyright (c) 2015 Chef Software, Inc.

License:: Apache License, Version 2.0

Licensed under the Apache License, Version 2.0 (the "License"); you may not use
this file except in compliance with the License. You may obtain a copy of the License at

<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software distributed under the
License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
either express or implied. See the License for the specific language governing permissions
and limitations under the License.

## Contributing

We'd love to hear from you if this doesn't perform in the manner you expect. Please log a GitHub issue, or even better, submit a Pull Request with a fix!

1. Fork it (<https://github.com/chef-partners/kitchen-vcair/fork>)
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request


