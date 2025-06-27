# Dockerfile for Fluent Bit on Windows Nano Server
FROM mcr.microsoft.com/windows/nanoserver:ltsc2025

# Create a working directory
WORKDIR C:/fluent-bit

# Create directories using CMD shell
SHELL ["cmd", "/S", "/C"]
RUN mkdir C:\opt\fluent-bit
RUN mkdir C:\PowerShell
RUN mkdir C:\download
RUN mkdir C:\opt\scripts

COPY install-fluent-bit.ps1 C:/opt/scripts/

# Download PowerShell Core directly in Nano Server using curl (which is available in Nano Server)
# Define PowerShell version and download URL
ENV POWERSHELL_VERSION=7.3.4 \
    POWERSHELL_PACKAGE=PowerShell-7.3.4-win-x64.zip \
    DOWNLOAD_URL=https://github.com/PowerShell/PowerShell/releases/download/v7.3.4/PowerShell-7.3.4-win-x64.zip

# Download PowerShell using curl and extract it
RUN curl.exe -L -o C:\download\%POWERSHELL_PACKAGE% %DOWNLOAD_URL% && \
    tar.exe -xf C:\download\%POWERSHELL_PACKAGE% -C C:\PowerShell && \
    del C:\download\%POWERSHELL_PACKAGE%


# Add PowerShell to the PATH
ENV PATH="C:\PowerShell;${PATH}"

# Switch to PowerShell for remaining commands
SHELL ["C:\\PowerShell\\pwsh.exe", "-Command"]

# install Fluent Bit
# Run setup.ps1
RUN & C:\opt\scripts\install-fluent-bit.ps1


# Set PATH environment variable using ENV instead of setx /M
ENV PATH="C:\opt\fluent-bit\bin;${PATH}"

ENTRYPOINT [ "fluent-bit.exe" ]
#CMD [ "fluent-bit.exe", "-c", "/fluent-bit/etc/fluent-bit.conf" ]
CMD [ "fluent-bit.exe", "-i", "dummy", "-o", "stdout"]