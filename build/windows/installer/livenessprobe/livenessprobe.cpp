#ifndef UNICODE
#define UNICODE
#endif

#ifndef _UNICODE
#define _UNICODE
#endif

#include <Windows.h>
#include <tlhelp32.h>
#include <tchar.h>

#define SUCCESS 0x00000000
#define NO_FLUENT_BIT_PROCESS 0x00000001
#define FILESYSTEM_WATCHER_FILE_EXISTS 0x00000002
#define CERTIFICATE_RENEWAL_REQUIRED 0x00000003
#define FLUENTDWINAKS_SERVICE_NOT_RUNNING 0x00000004
#define NO_WINDOWS_AMA_MONAGENTCORE_PROCESS 0x00000005
#define UNEXPECTED_ERROR 0xFFFFFFFF

/*
  check if the process running or not for given exe file name
*/
bool IsProcessRunning(const wchar_t *const executableName)
{
    PROCESSENTRY32 entry;
    entry.dwSize = sizeof(PROCESSENTRY32);

    const auto snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, NULL);

    if (!Process32First(snapshot, &entry))
    {
        CloseHandle(snapshot);
        wprintf_s(L"ERROR:IsProcessRunning::Process32First failed");
        return false;
    }

    do
    {
        if (!_wcsicmp(entry.szExeFile, executableName))
        {
            CloseHandle(snapshot);
            return true;
        }
    } while (Process32Next(snapshot, &entry));

    CloseHandle(snapshot);
    return false;
}

/*
  check if the file exists
*/
bool IsFileExists(const wchar_t *const fileName)
{
    DWORD dwAttrib = GetFileAttributes(fileName);
    return dwAttrib != INVALID_FILE_SIZE;
}

/*
 Get the status of the service for given service name
*/
int GetServiceStatus(const wchar_t *const serivceName)
{
    SC_HANDLE theService, scm;
    SERVICE_STATUS_PROCESS ssStatus;
    DWORD dwBytesNeeded;

    scm = OpenSCManager(nullptr, nullptr, SC_MANAGER_ENUMERATE_SERVICE);
    if (!scm)
    {
        wprintf_s(L"ERROR:GetServiceStatus::OpenSCManager failed");
        return UNEXPECTED_ERROR;
    }

    theService = OpenService(scm, serivceName, SERVICE_QUERY_STATUS);
    if (!theService)
    {
        CloseServiceHandle(scm);
        wprintf_s(L"ERROR:GetServiceStatus::OpenService failed");
        return UNEXPECTED_ERROR;
    }

    auto result = QueryServiceStatusEx(theService, SC_STATUS_PROCESS_INFO,
                                       reinterpret_cast<LPBYTE>(&ssStatus), sizeof(SERVICE_STATUS_PROCESS),
                                       &dwBytesNeeded);

    CloseServiceHandle(theService);
    CloseServiceHandle(scm);

    if (result == 0)
    {
        wprintf_s(L"ERROR:GetServiceStatus:QueryServiceStatusEx failed");
        return UNEXPECTED_ERROR;
    }

    return ssStatus.dwCurrentState;
}

/**
 <exe> <servicename> <filesystemwatcherfilepath> <certificaterenewalpath>
**/
int _tmain(int argc, wchar_t *argv[])
{
    if (argc < 5)
    {
        wprintf_s(L"ERROR:unexpected number arguments and expected is 5");
        return UNEXPECTED_ERROR;
    }

    if (!IsProcessRunning(argv[1]))
    {
        wprintf_s(L"ERROR:Process:%s is not running\n", argv[1]);
        return NO_FLUENT_BIT_PROCESS;
    }

    DWORD dwStatus = GetServiceStatus(argv[2]);

    if (dwStatus != SERVICE_RUNNING)
    {
        wprintf_s(L"ERROR:Service:%s is not running\n", argv[2]);
        return FLUENTDWINAKS_SERVICE_NOT_RUNNING;
    }

    if (IsFileExists(argv[3]))
    {
        wprintf_s(L"INFO:File:%s exists indicates Config Map Updated since agent started.\n", argv[3]);
        return FILESYSTEM_WATCHER_FILE_EXISTS;
    }

    if (IsFileExists(argv[4]))
    {
        wprintf_s(L"INFO:File:%s exists indicates Certificate needs to be renewed.\n", argv[4]);
        return CERTIFICATE_RENEWAL_REQUIRED;
    }

    if (argc > 5) {
        if (!IsProcessRunning(argv[5]))
        {
            wprintf_s(L"ERROR:Process:%s is not running\n", argv[5]);
            return NO_WINDOWS_AMA_MONAGENTCORE_PROCESS;
        }
    }

    return SUCCESS;
}
