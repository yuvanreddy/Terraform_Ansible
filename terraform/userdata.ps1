<powershell>
# Windows Server Initial Setup for JDK Installation
Write-Output "Starting Windows Server setup for JDK installation..."

# Set execution policy
Set-ExecutionPolicy Bypass -Scope Process -Force

# Set Administrator password (if provided)
$adminPassword = "${admin_password}"
if ($adminPassword -and $adminPassword -ne "") {
    try {
        $securePassword = ConvertTo-SecureString $adminPassword -AsPlainText -Force
        $adminUser = Get-LocalUser -Name "Administrator"
        $adminUser | Set-LocalUser -Password $securePassword
        Write-Output "Administrator password updated successfully"
    }
    catch {
        Write-Output "Failed to set Administrator password: $($_.Exception.Message)"
    }
}

# Enable Windows Remote Management (WinRM)
try {
    Write-Output "Configuring WinRM..."
    Enable-PSRemoting -Force
    winrm quickconfig -q
    winrm set winrm/config/winrs '@{MaxMemoryPerShellMB="512"}'
    winrm set winrm/config '@{MaxTimeoutms="1800000"}'
    winrm set winrm/config/service '@{AllowUnencrypted="true"}'
    winrm set winrm/config/service/auth '@{Basic="true"}'
    Write-Output "WinRM configured successfully"
}
catch {
    Write-Output "Failed to configure WinRM: $($_.Exception.Message)"
}

# Configure Windows Firewall for WinRM and RDP
try {
    Write-Output "Configuring Windows Firewall..."
    netsh advfirewall firewall add rule name="WinRM-HTTP" dir=in localport=5985 protocol=TCP action=allow
    netsh advfirewall firewall add rule name="WinRM-HTTPS" dir=in localport=5986 protocol=TCP action=allow
    netsh advfirewall firewall add rule name="RDP" dir=in localport=3389 protocol=TCP action=allow
    Write-Output "Firewall rules configured successfully"
}
catch {
    Write-Output "Failed to configure firewall: $($_.Exception.Message)"
}

# Install necessary Windows features
try {
    Write-Output "Installing Windows features..."
    # Install IIS for web-based management (optional)
    # Enable-WindowsOptionalFeature -Online -FeatureName IIS-WebServerRole -All -NoRestart
    
    # Install .NET Framework 4.8 (if not already installed)
    $dotNetVersion = Get-ItemProperty "HKLM:SOFTWARE\Microsoft\NET Framework Setup\NDP\v4\Full\" -Name Release -ErrorAction SilentlyContinue
    if ($dotNetVersion.Release -lt 528040) {
        Write-Output ".NET Framework 4.8 not found, will be installed via Windows Update"
    }
    Write-Output "Windows features check completed"
}
catch {
    Write-Output "Error checking Windows features: $($_.Exception.Message)"
}

# Create directory for JDK installation
try {
    $jdkDir = "C:\Program Files\Java"
    if (!(Test-Path $jdkDir)) {
        New-Item -ItemType Directory -Path $jdkDir -Force
        Write-Output "Created JDK directory: $jdkDir"
    }
}
catch {
    Write-Output "Failed to create JDK directory: $($_.Exception.Message)"
}

# Create temporary directory for downloads
try {
    $tempDir = "C:\Temp"
    if (!(Test-Path $tempDir)) {
        New-Item -ItemType Directory -Path $tempDir -Force
        Write-Output "Created temp directory: $tempDir"
    }
}
catch {
    Write-Output "Failed to create temp directory: $($_.Exception.Message)"
}

# Install AWS CLI (for S3 access)
try {
    Write-Output "Installing AWS CLI..."
    $awsCliUrl = "https://awscli.amazonaws.com/AWSCLIV2.msi"
    $awsCliPath = "C:\Temp\AWSCLIV2.msi"
    
    # Download AWS CLI
    Invoke-WebRequest -Uri $awsCliUrl -OutFile $awsCliPath -UseBasicParsing
    
    # Install AWS CLI silently
    Start-Process msiexec.exe -Wait -ArgumentList "/i $awsCliPath /quiet /norestart"
    
    # Add AWS CLI to PATH
    $env:Path += ";C:\Program Files\Amazon\AWSCLIV2\"
    [System.Environment]::SetEnvironmentVariable("Path", $env:Path, [System.EnvironmentVariableTarget]::Machine)
    
    Write-Output "AWS CLI installed successfully"
}
catch {
    Write-Output "Failed to install AWS CLI: $($_.Exception.Message)"
}

# Install PowerShell 7 (for better compatibility)
try {
    Write-Output "Installing PowerShell 7..."
    $ps7Url = "https://github.com/PowerShell/PowerShell/releases/latest/download/PowerShell-7.4.0-win-x64.msi"
    $ps7Path = "C:\Temp\PowerShell-7.msi"
    
    Invoke-WebRequest -Uri $ps7Url -OutFile $ps7Path -UseBasicParsing
    Start-Process msiexec.exe -Wait -ArgumentList "/i $ps7Path /quiet /norestart"
    
    Write-Output "PowerShell 7 installed successfully"
}
catch {
    Write-Output "Failed to install PowerShell 7: $($_.Exception.Message)"
}

# Configure System for JDK Installation
try {
    Write-Output "Configuring system for JDK installation..."
    
    # Set JAVA_HOME environment variable (placeholder)
    [System.Environment]::SetEnvironmentVariable("JAVA_HOME", "C:\Program Files\Java\jdk-21", [System.EnvironmentVariableTarget]::Machine)
    
    # Add Java to PATH (placeholder)
    $currentPath = [System.Environment]::GetEnvironmentVariable("Path", [System.EnvironmentVariableTarget]::Machine)
    if ($currentPath -notlike "*Java\jdk-21\bin*") {
        $newPath = $currentPath + ";C:\Program Files\Java\jdk-21\bin"
        [System.Environment]::SetEnvironmentVariable("Path", $newPath, [System.EnvironmentVariableTarget]::Machine)
    }
    
    Write-Output "System configured for JDK installation"
}
catch {
    Write-Output "Failed to configure system: $($_.Exception.Message)"
}

# Create installation log
try {
    $logContent = @"
JDK Installation Server Setup Completed
======================================
Timestamp: $(Get-Date)
Server: $env:COMPUTERNAME
OS: $(Get-CimInstance Win32_OperatingSystem | Select-Object -ExpandProperty Caption)
PowerShell Version: $($PSVersionTable.PSVersion)
AWS CLI: $(if (Get-Command aws -ErrorAction SilentlyContinue) { "Installed" } else { "Not Found" })

Ready for JDK installation via Ansible/SSM
"@
    
    $logContent | Out-File -FilePath "C:\Temp\setup-log.txt" -Encoding UTF8
    Write-Output "Setup log created at C:\Temp\setup-log.txt"
}
catch {
    Write-Output "Failed to create setup log: $($_.Exception.Message)"
}

Write-Output "Windows Server setup completed successfully!"
Write-Output "Server is ready for JDK installation via Ansible and SSM."
</powershell>