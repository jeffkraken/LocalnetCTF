# LocalnetCTF

## Description
This repo contains the configuration scripts for a CTF that was ran on 3/25/26 for Centriq Training Alumni. This has been made available here for anyone that attended the event and would like to rebuild the challenge locally. The build scripts are written in PowerShell work on Windows Server 2022 and could be configured as a physical server or a Virtual Machine.

## Set up steps
1. Install a basic Windows Server 2022 with Desktop Experience (Either as a physical server or a VM)
2. Copy entire CTFSetup folder from this repo to the root of the C:\ drive. (I was lazy, so the scripts call to C:\CTFSetup directly instead of identifying the location with something like Join-Path.)
3. Run the first script. C:\CTFSetup\init-config.ps1
4. Monitor the script. (It will restart automatically and after you log in, the next script starts automatically.)
5. After the final script, the default Administrator should be disabled. (This is a sign that the scripts worked fine.)
6. Connect your attacker machine to the server. (either with a virtual switch or a physical cable)
7. Verfiy that your attacker machine received an IP from DHCP.


## Disclaimer
This is a Challenge/CTF environment. These scripts are insecure to use in production and should not be deployed outside of test environments.
