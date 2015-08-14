Kitchen::Vcair
==================

A vCloud Air Servers driver for Test Kitchen!

Originally based on the [Rackspace driver](https://github.com/test-kitchen/kitchen-rackspace) (from [Jonathan Hartman's](https://github.com/RoboticCheese)) 


Installation
------------

Add this line to your application's Gemfile:

    gem 'kitchen-vcair'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install kitchen-vcair

Usage
-----

Provide, at a minimum, the required driver options in your `.kitchen.yml` file:

    driver:
      name: vcair
      vcair_username: [Your vCloud Air username]
      vcair_password: [Your vCloud Air password]
      vcair_api_host: [Your vCloud Air API Host]
      vcair_vm_password: [Initial system password used for bootstrap]
      vcair_org: [Your vCloud Air Organization ID]
      require_chef_omnibus: [e.g. 'true' or a version number if you need Chef]
    platforms:
      - name: [A PLATFORM NAME, e.g. 'centos-6']

By default, the driver will spawn a 1GB server on the base image for your
specified platform. Additional, optional overrides can be provided:

    image_id: [SERVER IMAGE ID]
    vcair_net: [ROUTED_NETWORK_WITH_ACCESS_TO_CHEF_SERVER]
    flavor_id: [SERVER FLAVOR ID]
    server_name: [A FRIENDLY SERVER NAME]
    public_key_path: [PATH TO YOUR PUBLIC SSH KEY]
    wait_for: [NUM OF SECONDS TO WAIT BEFORE TIMING OUT, DEFAULT 600]
    no_ssh_tcp_check: [DEFAULTS TO false, SKIPS TCP CHECK WHEN true]
    no_ssh_tcp_check_sleep: [NUM OF SECONDS TO SLEEP IF no_ssh_tcp_check IS SET]

If targeting windows, be sure to add ```transport``` and ```verifier`` options:

    transport:
      name: winrm
      connection_retries: 15
      connection_retry_sleep: 15
      max_wait_until_ready: 600
      username: 'administrator'
      password: 'Password1'
    verifier:
      name: pester

You also have the option of providing some configs via environment variables:

    export VCAIR_API_HOST='API_HOST.vchs.vmware.com'
    export VCAIR_VM_PASSWORD='SOME_INITIAL_PASSWORD'
    export VCAIR_ORG='MNNNNNNNNN-NNNN'
    export VCAIR_USERNAME='YOUR_USERNAME'
    export VCAIR_PASSWORD='YOUR_PASSWORD'

Execution:

    KITCHEN_YAML=.kitchen.vcair.yml kitchen test

Known Issues / Work Arounds
---------------------------

##### ssh authentication happens via password only and public_key auth isn't available

You must populate :vcair_vm_password in your kitchen.yml

##### vCloud Air VMs default to an isolated network

You must populate :vcair_net _OR_ create a non-isolated network (it will use the first available)

##### SSH access to nodes requires default firewall policy open port 22

You may find it easier to use a provisioning node within the same network you nodes will be provisioned on

##### Windows images do not turn on winrm by default

##### Windows images force login via rdp console requiring a password change

Both of these can be worked around by including a ```:customization_script``` that sets the password manually, removes the expiry, opens the firewall for and enables winrm.

```yaml
platforms:
  - name: win2012-chef12
    driver_config:
      image_id: W2K12-STD-64BIT
      size: 2gb
      customization_script: 'install-winrm-vcair.bat'
```

```bat
@echo off

@rem First Boot... 
if “%1%” == “precustomization” (

echo Do precustomization tasks
@rem during this boot the hostname is set, which requires a reboot

@rem we also enable winrm over http, plaintext, long timeout, more memory etc

cmd.exe /c winrm quickconfig -q
cmd.exe /c winrm quickconfig -transport:http
cmd.exe /c winrm set winrm/config @{MaxTimeoutms="1800000"}
cmd.exe /c winrm set winrm/config/winrs @{MaxMemoryPerShellMB="300"}
cmd.exe /c winrm set winrm/config/service @{AllowUnencrypted="true"}
cmd.exe /c winrm set winrm/config/service/auth @{Basic="true"}
cmd.exe /c winrm set winrm/config/client/auth @{Basic="true"}
cmd.exe /c winrm set winrm/config/listener?Address=*+Transport=HTTP @{Port="5985"} 

@rem Make sure winrm is off for this boot, but enabled on next
@rem as we don't want a tcp connection available until we are
@rem past postcustomization

cmd.exe /c net stop winrm
cmd.exe /c sc config winrm start= auto

@rem make sure the default on password age is unlimited
@rem this ensures we don't have a password change forced on us
cmd.exe /c net accounts /maxpwage:unlimited

@rem write out a timestamp for this first boot / customization completes
echo %DATE% %TIME% > C:\vm-is-customized

) else if “%1%” == “postcustomization” (

@rem Second Boot / start winrm, just incase, and fix firewall

cmd.exe /c net start winrm 
cmd.exe /c netsh advfirewall firewall set rule group="remote administration" new enable=yes
cmd.exe /c netsh firewall add portopening TCP 5985 "Port 5985 for WinRM"

@rem Password Setting and Autologin currently seem broken
@rem when done via the API, so we MUST set it in the postcustomization phase
cmd.exe /c net user administrator Password1

@rem in some environments we found the need to specify a DNS address
@rem cmd.exe /c netsh interface ipv4 add dnsserver "Ethernet" address=8.8.8.8
@rem cmd.exe /c netsh interface ipv4 add dnsserver "Ethernet0" address=8.8.8.8

@rem this is our 'ready' boot, password and winrm should be up
echo %DATE% %TIME% > C:\vm-is-ready

)
```

Feature Requests
----------------

##### Non CentOS64-64BIT image support

CentoOS64-64BIT is the only image that allowed setting the password
CentOS and Ubuntu failed to set the password correctly

##### NAT support

Only routed networks supported for now

Walkthru of kitchen-vcair for linux guests
------------------------------------------

* [github.com/vulk/kitchen-vcair](https://www.youtube.com/watch?v=5srDko69XJ0&t=03)
* [vchs.vmware.com](https://www.youtube.com/watch?v=5srDko69XJ0&t=15)
* [Walkthrough steps for cloning, building gem](https://www.youtube.com/watch?v=5srDko69XJ0&t=30)
* [git clone git@github.com:/vulk/kitchen-vcair.git](https://www.youtube.com/watch?v=5srDko69XJ0&t=68)
* [cd kitchen-vcair](https://www.youtube.com/watch?v=5srDko69XJ0&t=94)
* [gem build kitchen-vcair.gemspec](https://www.youtube.com/watch?v=5srDko69XJ0&t=100)
* [gem install ./kitchen-vcair-0.1.0.gem](https://www.youtube.com/watch?v=5srDko69XJ0&t=120)
* [quick look through code  ](https://www.youtube.com/watch?v=5srDko69XJ0&t=126)
* [git clone git@github.com:chef-cookbooks/httpd.git ](https://www.youtube.com/watch?v=5srDko69XJ0&t=173)
* [walkthrough of .kitchen.vcair.yml](https://www.youtube.com/watch?v=5srDko69XJ0&t=199)
* [walkthrough of environment variables](https://www.youtube.com/watch?v=5srDko69XJ0&t=247)
* [kitchen test](https://www.youtube.com/watch?v=5srDko69XJ0&t=282)
* [vchs.vmware.com virtualmachine list, showing creation of helloworldtest VM](https://www.youtube.com/watch?v=5srDko69XJ0&t=296)
* [knife vcair server list showing creation of helloworld test VM](https://www.youtube.com/watch?v=5srDko69XJ0&t=326)
* [instance provisionied, waiting for ssh](https://www.youtube.com/watch?v=5srDko69XJ0&t=355)
* [ssh available, installing chef-client](https://www.youtube.com/watch?v=5srDko69XJ0&t=400)
* [chef-client starting](https://www.youtube.com/watch?v=5srDko69XJ0&t=499)
* [chef-client finished, apache install completed](https://www.youtube.com/watch?v=5srDko69XJ0&t=515)
* [Kitchen Setup and Verify](https://www.youtube.com/watch?v=5srDko69XJ0&t=516)
* [Kitichen Destroy](https://www.youtube.com/watch?v=5srDko69XJ0&t=517)
* [Kitchen is finished](https://www.youtube.com/watch?v=5srDko69XJ0&t=525)
* [vchs.vmware.com and knife vcair shows vm destroyed](https://www.youtube.com/watch?v=5srDko69XJ0&t=530)


Walkthru of kitchen-vcair for windows guests
------------------------------------------

* [vmwair-vcair.env.example](https://www.youtube.com/watch?v=k8OZII4UGZs&t=09)
* [.kitchen.vcair.yml](https://www.youtube.com/watch?v=k8OZII4UGZs&t=20)
* [.yml / platforms:customization_script note](https://www.youtube.com/watch?v=k8OZII4UGZs&t=30)
* [customization_script install-winrm-vcair.bat](https://www.youtube.com/watch?v=k8OZII4UGZs&t=37)
* [git clone opscode-cookbooks/iis](https://www.youtube.com/watch?v=k8OZII4UGZs&t=54)
* [start coping files into iis cookbooks](https://www.youtube.com/watch?v=k8OZII4UGZs&t=60)
* [Add kitchen-vcair and kitchen-pester to the Gemfile](https://www.youtube.com/watch?v=k8OZII4UGZs&t=98)
* [bundle install kitchen vcair and pester](https://www.youtube.com/watch?v=k8OZII4UGZs&t=120)	
* [KITCHEN_YAML=.kitchen.vcair.yml bundle exec kitchen verify](https://www.youtube.com/watch?v=k8OZII4UGZs&t=150)
* [Server is allocated.](https://www.youtube.com/watch?v=k8OZII4UGZs&t=270)
* ['pre'/'post' customization script ](https://www.youtube.com/watch?v=k8OZII4UGZs&t=300)
* ['pre' customization reboot ](https://www.youtube.com/watch?v=k8OZII4UGZs&t=412)
* ['post' customization boot ](https://www.youtube.com/watch?v=k8OZII4UGZs&t=440)
* [winrm is online](https://www.youtube.com/watch?v=k8OZII4UGZs&t=555)
* [installing chef omnibus](https://www.youtube.com/watch?v=k8OZII4UGZs&t=560)
* [chef-client starts](https://www.youtube.com/watch?v=k8OZII4UGZs&t=600)
* [iis:default recipe runs](https://www.youtube.com/watch?v=k8OZII4UGZs&t=630)
* [verification via kitche-pester](https://www.youtube.com/watch?v=k8OZII4UGZs&t=647)
* [kitchen verify complete!](https://www.youtube.com/watch?v=k8OZII4UGZs&t=660)
* [iis default web page via links](https://www.youtube.com/watch?v=k8OZII4UGZs&t=695)
* [kitchen verify again](https://www.youtube.com/watch?v=k8OZII4UGZs&t=710)
* [kitchen destroy](https://www.youtube.com/watch?v=k8OZII4UGZs&t=735)

Contributing
------------

1. Fork it
2. `bundle install`
3. Create your feature branch (`git checkout -b my-new-feature`)
4. `bundle exec rake` must pass
5. Commit your changes (`git commit -am 'Add some feature'`)
6. Push to the branch (`git push origin my-new-feature`)
7. Create new Pull Request
