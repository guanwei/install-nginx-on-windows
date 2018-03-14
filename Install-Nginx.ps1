Param(
    [Parameter(Mandatory=$False)]
    [String]$Version,
    [Parameter(Mandatory=$False)]
	[String]$DownloadPath,
    [Parameter(Mandatory=$False)]
	[String]$InstallPath = "C:\nginx"
)

$here = Split-Path $MyInvocation.MyCommand.Path -Parent

$nginxDownloadUrl = "http://nginx.org/download/nginx-${Version}.zip"
$winswDownloadUrl = "http://repo.jenkins-ci.org/releases/com/sun/winsw/winsw/2.1.2/winsw-2.1.2-bin.exe"

if(!$DownloadPath)
{
	$DownloadPath = $here
}

if(!(Test-Path $DownloadPath))
{
    New-Item $DownloadPath -Force -ItemType Directory
}

if(!$Version)
{
	$nginxDownloadFile = Get-ChildItem $DownloadPath -Filter nginx-*.zip |
		Sort-Object Name -Descending | Select-Object -ExpandProperty FullName -First 1
	if($nginxDownloadFile)
	{
		Write-Output "Found nginx package `'$nginxDownloadFile`'"
	}
	else
	{
		throw "Can not find nginx package as 'nginx-*.zip' in $DownloadPath"
	}
}
else
{
	$nginxDownloadFile = Join-Path $DownloadPath "nginx-${Version}.zip"
	if(!(Test-Path $nginxDownloadFile))
	{
		# downlaod nginx
		Write-Output "Downloading Nginx from $nginxDownloadUrl to $nginxDownloadFile"
		Invoke-WebRequest -Uri $nginxDownloadUrl -OutFile $nginxDownloadFile
	}
}

New-Item $InstallPath -ItemType Directory -Force | Out-Null

$winswDownloadFile = Get-ChildItem $DownloadPath -Filter winsw-*.exe |
		Sort-Object Name -Descending | Select-Object -ExpandProperty FullName -First 1
if($winswDownloadFile)
{
	Write-Output "Found winsw package `'$winswDownloadFile`'"
}
else
{
    # download winsw
    Write-Output "Downloading winsw from $winswDownloadUrl to $winswDownloadFile"
    Invoke-WebRequest -Uri $winswDownloadUrl -OutFile $winswDownloadFile
}

$winswFile = Join-Path "$InstallPath" "nginx-service.exe"

if(Test-Path $winswFile)
{
    # stop nginx service
    Write-Output "Stopping Nginx service..."
    cmd /c "$winswFile" stop
}
Copy-Item $winswDownloadFile $winswFile -Force

# extract nginx
Write-Output "Extracting $nginxDownloadFile to $DownloadPath..."
$shellApplication = new-object -com shell.application
$zipPackage = $shellApplication.NameSpace($nginxDownloadFile)
$destinationFolder = $shellApplication.NameSpace($DownloadPath)
$destinationFolder.CopyHere($zipPackage.Items(),0x10)

# backup old nginx config
$nginxConf = Join-Path $InstallPath "conf\nginx.conf"
$backuped = $False
if(Test-Path $nginxConf)
{
	Write-Output "Backing up nginx config to ${nginxConf}.bak..."
	Copy-Item "$nginxConf" "${nginxConf}.bak" -Force
	$backuped = $True
}

# copy to install path
$nginxUnzipedDir = $nginxDownloadFile -replace '.zip',''
Write-Output "Copying files from $nginxUnzipedDir to $InstallPath..."
Copy-Item "$nginxUnzipedDir\*" "$InstallPath" -Force -Recurse

# restore nginx config
if($backuped)
{
	Write-Output "Restoring nginx config from ${nginxConf}.bak..."
	Move-Item "${nginxConf}.bak" "$nginxConf" -Force
}

# remove unzip folder
Write-Output "Removing folder $nginxUnzipedDir..."
Remove-Item $nginxUnzipedDir -Force -Recurse

# create nginx-service.xml
$str = @"
<service>
  <id>nginx</id>
  <name>Nginx Service</name>
  <description>High Performance Nginx Service</description>
  <logpath>$InstallPath\logs</logpath>
  <log mode="roll-by-size">
    <sizeThreshold>10240</sizeThreshold>
    <keepFiles>8</keepFiles>
  </log>
  <executable>$InstallPath\nginx.exe</executable>
  <startarguments>-p "$InstallPath"</startarguments>
  <stopexecutable>$InstallPath\nginx.exe</stopexecutable>
  <stoparguments>-p "$InstallPath" -s stop</stoparguments>
</service>
"@
$file = Join-Path "$InstallPath" "nginx-service.xml"
Write-Output "Creating $file..."
$str | Out-File $file -Force

# create nginx-service.exe.config
$str = @"
<configuration>
  <startup>
    <supportedRuntime version="v2.0.50727" />
    <supportedRuntime version="v4.0" />
  </startup>
  <runtime>
    <generatePublisherEvidence enabled="false" />
  </runtime>
</configuration>
"@
$file = Join-Path "$InstallPath" "nginx-service.exe.config"
Write-Output "Creating $file..."
$str | Out-File $file -Force

# install nginx service
Write-Output "Installing Nginx service..."
if((cmd /c "$winswFile" status) -ne "NonExistent")
{
    cmd /c "$winswFile" uninstall
}
cmd /c "$winswFile" install

if ((Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\HTTP" | Select-Object -ExpandProperty Start) -ne "0")
{
    Set-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\HTTP" -Name Start -Value 0 -Type DWord
    Write-Output "You need restart your computer."
}
else
{
    Write-Output "Starting Nginx service..."
    cmd /c "$winswFile" start
}