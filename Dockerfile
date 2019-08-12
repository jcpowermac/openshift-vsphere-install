FROM mcr.microsoft.com/powershell:latest

RUN pwsh -command "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted;Install-Module VMware.PowerCLI;Install-Module powershell-yaml"

COPY install-openshift.ps1 /root
