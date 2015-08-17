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
