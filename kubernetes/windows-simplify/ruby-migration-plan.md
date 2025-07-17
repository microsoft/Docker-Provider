# Ruby Usage Review and PowerShell Migration Plan

This document lists all usages of Ruby in `main.ps1` and provides a plan for replacing each with PowerShell.

## Ruby Script Usages in main.ps1

### 1. TOML Parsing and Environment Variable Generation

- **Scripts:**
  - `tomlparser-common-agent-config.rb`
  - `tomlparser.rb`
  - `tomlparser-agent-config.rb`
  - `tomlparser-geneva-config.rb`
  - `tomlparser-mdm-metrics-config.rb`
  - `tomlparser-prom-customconfig.rb`
- **Purpose:** Parse TOML config files and output environment variable files for PowerShell to consume.
- **Plan:** Rewrite each parser in PowerShell using a TOML parsing module or custom logic. Output the same environment variable files.

### 2. Fluent Bit and Geneva Config Customization

- **Scripts:**
  - `fluent-bit-conf-customizer.rb`
  - `fluent-bit-geneva-conf-customizer.rb`
- **Purpose:** Customize Fluent Bit and Geneva config files based on environment variables.
- **Plan:** Rewrite customization logic in PowerShell, using string replacement and file manipulation.

### 3. Ruby Plugins for Fluentd

- **Scripts:** Ruby files in `/etc/fluent/plugin/`
- **Purpose:** Fluentd plugins for log processing.
- **Plan:** If Fluentd is still used, port essential plugins to PowerShell or replace with native Fluent Bit/PowerShell logic.

## Next Steps

1. For each script above, analyze its logic and rewrite in PowerShell.
2. Update `main.ps1` to call the new PowerShell scripts/functions.
3. Test and validate output matches the original Ruby-based workflow.
4. Remove Ruby from the Docker image after migration is complete.
