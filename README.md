** this script is for install nginx on windows **

#### run the script

open powershell command window run as Administrator.

you can just run `.\Install-Nginx.ps1` without any parameters, it will search nginx package in the script folder, it will use the biggest version package if found, else it will throw an exception and it will be installed to `C:\nginx` by default.

you can install specific version of nginx and install to soecific path. For example, you can install nginx-1.11.10 to `D:\nginx` by below command, the script will download `nginx-1.11.10.zip` from nginx site if not found in the script directory.
```
.\Install-Nginx.ps1 -Version 1.11.10 -InstallPath D:\nginx
```

#### check nginx service

open services windows by run `services.msc`, you can find a service called 'Nginx Service'.