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
bool IsProcessRunningWithSpecificPath(const wchar_t* executableFullPath)
{
    PROCESSENTRY32 processEntry{};  // struct to hold process details
    processEntry.dwSize = sizeof(PROCESSENTRY32);  // set size of struct

    // Handle to snapshot of all processes currently running on the system
    HANDLE processSnapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);

    if (processSnapshot == INVALID_HANDLE_VALUE)
    {
        throw std::runtime_error("Failed to create process snapshot"); 
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

                if (moduleSnapshot == INVALID_HANDLE_VALUE)
                {
                    throw std::runtime_error("Failed to create module snapshot"); 
                }

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
Usage: livesnessprobe.exe <monitoringAgentLauncherPath> [fileSystemWatcherTextFilePath]
Description: 
    - monitoringAgentLauncherPath: The mandatory path to the Monitoring Agent Launcher exe. The program will return exit code 1 if a process with this full path is not running.
    - fileSystemWatcherTextFilePath: The optional path to the file system watcher text file. If provided, the program will return exit code 2 if this file exists.
**/
int wmain(int argc, wchar_t* argv[])
{
    try
    {
        const wchar_t* USAGE_INFO = L"Usage: livenessprobe.exe <monitoringAgentLauncherPath> [fileSystemWatcherTextFilePath]\n"
                             "Description: \n"
                             "- monitoringAgentLauncherPath: The mandatory path to the Monitoring Agent Launcher exe. The program will return exit code 1 if a process with this full path is not running.\n"
                             "- fileSystemWatcherTextFilePath: The optional path to the watcher. If provided, the program will fail if this file exists.\n";

        if (argc < 2)
        {
            wprintf_s(L"ERROR: No arguments provided.");
            wprintf_s(USAGE_INFO);
            return UNEXPECTED_ERROR;
        }
        else if(argc == 2)
        {
            wprintf_s(L"INFO: Only the agentPath provided. The program won't check the watcher file.\n");
        }
        else if (argc == 3 && IsFileExists(argv[2]))
        {
            wprintf_s(L"INFO: File:%s exists indicates ConfigMap has been deployed/updated after the container started.\n", argv[2]);
            return FILESYSTEM_WATCHER_FILE_EXISTS;
        }
        else if(argc > 3)
        {
            wprintf_s(L"ERROR: Too many arguments provided.");
            wprintf_s(USAGE_INFO);
            return UNEXPECTED_ERROR;
        }

        if (!IsProcessRunningWithSpecificPath(argv[1]))
        {
            wprintf_s(L"ERROR: Process:%s is not running\n", argv[1]);
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