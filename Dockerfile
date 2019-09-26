FROM mcr.microsoft.com/powershell:latest

RUN apt-get update && apt-get install -y vim

RUN pwsh -command "Set-PSRepository -Name PSGallery -InstallationPolicy Trusted;Install-Module VMware.PowerCLI;Install-Module powershell-yaml" > /dev/null

COPY install-openshift.ps1 /root
COPY scripts /root
