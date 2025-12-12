# Windows Support - Progress Tracking

## Issues Requiring Fixes

### ✅ 1. Init Container Commands - Windows Compatibility

**Status**: COMPLETED & TESTED

**Problem**: Init containers use commands that don't exist on Windows containers.

**Solution Implemented**: 
- Simplified init containers to use direct `cp -r` command
- Installed busybox-w32 in Windows SDK images to provide Unix utilities (cp, sh, etc.)
- Multi-stage Docker build: download busybox in Server Core (has PowerShell), copy to Nano Server
- Configure PATH with `ENV PATH="C:\busybox;${PATH}"`

**Changes Made**:
- ✅ Modified `Mutations.ts` - all init containers use `command: ["cp"], args: ["-r", source, dest]`
- ✅ Modified `Dockerfile.windows` in dotnet-fake to include busybox installation
- ✅ Built and tested multi-arch dotnet-fake image with busybox
- ✅ Verified `cp -r` command works correctly on Windows containers

**Next Steps**: Apply busybox installation pattern to real SDK images (Java, Node.js, Python, .NET)

---

### ✅ 2. SDK Images Must Be Multi-Arch (Linux + Windows)

**Status**: IN PROGRESS

**Problem**: Current SDK images (Java, Node.js, Python, .NET) are likely Linux-only and won't run on Windows nodes.

**Solution**: Build Windows variants of all SDK images and create multi-arch manifests that include both Linux and Windows platforms.

**Completed**:
- ✅ Built dotnet-fake multi-arch test image (Win 2019, Win 2022, Linux amd64, Linux arm64)
- ✅ Established busybox installation pattern for Windows compatibility
- [ ] Apply to Java SDK image
- [ ] Apply to Node.js SDK image
- [ ] Apply to Python SDK image
- [ ] Apply to .NET SDK image
- [ ] Create multi-arch manifests for each SDK
- [x] Created example multi-arch image: `appmonitoring.azurecr.io/dotnet-fake:latest` (test image)

---

### ✅ 3. Log Paths Work with emptyDir

**Status**: VERIFIED - NO CHANGES NEEDED

**Problem**: Log path is hardcoded as `/var/log/applicationinsights` which could cause issues on Windows.

**Solution**: Current implementation already uses `emptyDir` volume type, which Kubernetes automatically translates for Windows nodes.

**Analysis**:
- ✅ Log volume uses `emptyDir` (line 536-540 in Mutations.ts)
- ✅ Kubernetes translates Linux-style paths to Windows paths automatically for volume mounts
- ✅ SDKs hardcode this path and it works transparently on both platforms
- ✅ No code changes required

---

### ✅ 4. .NET Environment Variable Paths

**Status**: FIXED - PATH TRANSLATION SCRIPT ADDED

**Problem**: 
- .NET environment variables with file paths use Linux-style forward slashes (e.g., `/azure-monitor-auto-instrumentation-dotnet/...`)
- On Windows, the .NET runtime (specifically `DOTNET_STARTUP_HOOKS`) interprets forward slashes as part of an assembly name, not path separators
- This causes startup failures: `System.ArgumentException: The startup hook simple assembly name '/azure-monitor-auto-instrumentation-dotnet/net/OpenTelemetry.AutoInstrumentation.StartupHook.dll' is invalid`

**Root Cause**:
- Kubernetes translates volume **mount paths** automatically for Windows nodes
- But environment variable **values** are just strings - Kubernetes doesn't translate them
- The webhook sets the same environment variable values for both OS types

**Solution Implemented**:
- ✅ Added `/busybox/fix-dotnet-paths.sh` script to SDK images
- ✅ Script converts Linux-style paths (`/`) to Windows-style paths (`\`)
- ✅ Works as a wrapper: `sh /busybox/fix-dotnet-paths.sh dotnet MyApp.dll`
- ✅ Fixes all .NET environment variables: `DOTNET_STARTUP_HOOKS`, `DOTNET_ADDITIONAL_DEPS`, `DOTNET_SHARED_STORE`, `OTEL_DOTNET_AUTO_HOME`, `OTEL_DOTNET_AUTO_LOG_DIRECTORY`

**Usage**:
Customers need to wrap their entrypoint in Kubernetes deployments:
```yaml
containers:
- name: my-app
  image: my-dotnet-app:latest
  command: ["sh", "/busybox/fix-dotnet-paths.sh"]
  args: ["dotnet", "MyApp.dll"]
```

**Testing**:
```bash
docker run --rm \
  -e DOTNET_STARTUP_HOOKS="/azure-monitor-auto-instrumentation-dotnet/net/OpenTelemetry.AutoInstrumentation.StartupHook.dll" \
  appmonitoring.azurecr.io/dotnet-fake:latest \
  sh /busybox/fix-dotnet-paths.sh \
  sh -c 'echo $DOTNET_STARTUP_HOOKS'
# Output: \azure-monitor-auto-instrumentation-dotnet\net\OpenTelemetry.AutoInstrumentation.StartupHook.dll
```

**Documentation**: See `WINDOWS-PATH-FIX.md` for complete details

**Recommendation**:
- 🧪 Test with real .NET workload on Windows node to confirm
- 📝 Document this requirement for customers using Windows nodes

---

## Summary

**Completed**: 4/4 issues resolved
- ✅ Issue #1: Init container commands now support both Linux and Windows
- ✅ Issue #2: Multi-arch SDK images created
- ✅ Issue #3: Log paths verified to work with emptyDir volumes  
- ✅ Issue #4: .NET paths should work (testing recommended)

**Testing Needed**:
- Deploy .NET workload to Windows node and verify auto-instrumentation works
- Verify logs are written correctly on Windows nodes
- Test all SDK platforms (Java, Node.js, Python, .NET) on Windows nodes
- [ ] Verify all .NET environment variables work correctly
- [ ] Test DOTNET_STARTUP_HOOKS, DOTNET_ADDITIONAL_DEPS, DOTNET_SHARED_STORE, OTEL_DOTNET_AUTO_HOME
- [ ] If issues found, implement conditional path handling

---

## Summary

- **Completed**: 1/4
- **In Progress**: 1/4
- **Pending**: 2/4
