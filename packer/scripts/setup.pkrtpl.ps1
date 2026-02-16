Write-Host "Downloading Cloudbase-Init..."
$url = "https://github.com/cloudbase/cloudbase-init/releases/download/1.1.4/CloudbaseInitSetup_1_1_4_x64.msi"
$output = "C:\Windows\Temp\cloudbase-init.msi"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Invoke-WebRequest -Uri $url -OutFile $output

Write-Host "Installing Cloudbase-Init..."
$logPath = "C:\Windows\Temp\install.log"
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $output /qn /l*v $logPath" -Wait

$confPath = "C:\Program Files\Cloudbase Solutions\Cloudbase-Init\conf\cloudbase-init.conf"

$retries = 0
while (!(Test-Path $confPath) -and ($retries -lt 10)) {
    Write-Host "Waiting for Cloudbase-Init config file... ($retries)"
    Start-Sleep -Seconds 2
    $retries++
}

if (Test-Path $confPath) {
    Write-Host "Configuring Cloudbase-Init..."
    $confContent = @"
[DEFAULT]
username=Administrator
groups=Administrators
inject_user_password=true
first_logon_behaviour=no
config_drive_cdrom=true
config_drive_vfat=true

# CRITICAL FIX 1: Enable BOTH services
# 'config-2' label = ConfigDriveService (This matches your screenshot!)
# 'cidata' label   = NoCloudConfigDriveService (Backup)
metadata_services=cloudbaseinit.metadata.services.configdrive.ConfigDriveService,cloudbaseinit.metadata.services.nocloudservice.NoCloudConfigDriveService

# CRITICAL FIX 2: Wait for the drive to mount (Race Condition Fix)
retry_count=40
retry_count_interval=5

# Logging/Debug
verbose=true
debug=true
log_dir=C:\Program Files\Cloudbase Solutions\Cloudbase-Init\log\
logfile=cloudbase-init.log
default_log_levels=comtypes=INFO,suds=INFO,iso8601=WARN,requests=WARN

# Network Configuration
plugins=cloudbaseinit.plugins.common.networkconfig.NetworkConfigPlugin,cloudbaseinit.plugins.windows.createuser.CreateUserPlugin,cloudbaseinit.plugins.common.setuserpassword.SetUserPasswordPlugin,cloudbaseinit.plugins.common.userdata.UserDataPlugin,cloudbaseinit.plugins.common.localscripts.LocalScriptsPlugin
allow_reboot=true
stop_service_on_exit=false
"@
    Set-Content -Path $confPath -Value $confContent
} else {
    Write-Error "Cloudbase-Init install failed! Log available at $logPath"
    Exit 1
}
Write-Host "Stopping Cloudbase-Init..."
Stop-Service cloudbase-init -ErrorAction SilentlyContinue

Write-Host "Setup complete."

# Create a robust admin user that Sysprep won't touch
net user Dorb ${build_password} /add
net localgroup Administrators Dorb /add
