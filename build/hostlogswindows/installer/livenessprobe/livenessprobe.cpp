#ifndef UNICODE
#define UNICODE
#endif

#ifndef _UNICODE
#define _UNICODE
#endif

#include <Windows.h>
#include <tlhelp32.h>
#include <iostream>
#include <shlwapi.h>

#pragma comment(lib, "Shlwapi.lib")

#define SUCCESS 0x00000000
#define NO_MONAGENT_LAUNCHER_PROCESS 0x00000001
#define FILESYSTEM_WATCHER_FILE_EXISTS 0x00000002
#define UNEXPECTED_ERROR 0xFFFFFFFF

/*
*  Function to check if the given file exists
*/
bool IsFileExists(const wchar_t* const fileName)
{
    DWORD dwAttrib = GetFileAttributes(fileName);
    return dwAttrib != INVALID_FILE_SIZE;
}

/*
* Function to check if a process is running based on its full path
*/
bool IsProcessRunningWithSpecifcPath(const wchar_t* executableFullPath)
{
    PROCESSENTRY32 processEntry{};  // struct to hold process details
    processEntry.dwSize = sizeof(PROCESSENTRY32);  // set size of struct

    // Handle to snapshot of all processes currently running on the system
    HANDLE processSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);

    if (processSnapshot == INVALID_HANDLE_VALUE)
    {
        throw std::runtime_error("Failed to create process snapshot"); // or just exit the program with UNEXPECTED_ERROR ?
    }

    wchar_t* executableName = PathFindFileName(executableFullPath);

    // Traverse through the list of processes in the snapshot
    if (Process32First(processSnapshot, &processEntry))
    {
        do
        {
            if (!_wcsicmp(processEntry.szExeFile, executableName))
            {
                // For each process that matches our executableName, capture a snapshot of all modules
                HANDLE moduleSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPMODULE, processEntry.th32ProcessID);

                MODULEENTRY32 moduleEntry{}; // struct to hold details of a module (exe) associated with a process
                moduleEntry.dwSize = sizeof(MODULEENTRY32); // set size of struct

                // If the module (exe) path matches with the given path, process is running
                if (Module32First(moduleSnapshot, &moduleEntry) && !_wcsicmp(moduleEntry.szExePath, executableFullPath)) {
                    CloseHandle(moduleSnapshot);
                    CloseHandle(processSnapshot);
                    return true;
                }

                CloseHandle(moduleSnapshot);
            }
        } while (Process32Next(processSnapshot, &processEntry));
    }

    CloseHandle(processSnapshot);
    return false;
}

/**
 <exe> <monAgentLauncherExe> <filesystemwatcherfilepath>
**/
int wmain(int argc, wchar_t* argv[])
{
    try
    {
        if (argc < 2 || argc > 3)
        {
            wprintf_s(L"ERROR:unexpected number of arguments give. The expectation is at least 2 and no more then 3 agruments");
            return UNEXPECTED_ERROR;
        }
        else if (argc == 3)
        {
            if (IsFileExists(argv[2]))
            {
                wprintf_s(L"INFO:File:%s exists indicates ConfigMap has been deployed/updated after the container started.\n", argv[2]);
                return FILESYSTEM_WATCHER_FILE_EXISTS;
            }
        }

        if (!IsProcessRunningWithSpecifcPath(argv[1]))
        {
            wprintf_s(L"ERROR:Process:%s is not running\n", argv[1]);
            return NO_MONAGENT_LAUNCHER_PROCESS;
        }

        return SUCCESS;
    }
    catch (...)
    {
        wprintf_s(L"An unexpected error occurred.\n");
        return UNEXPECTED_ERROR;
    }
}