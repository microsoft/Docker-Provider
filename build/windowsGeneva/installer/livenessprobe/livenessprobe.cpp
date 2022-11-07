#ifndef UNICODE
#define UNICODE
#endif

#ifndef _UNICODE
#define _UNICODE
#endif

#include <Windows.h>
#include <tchar.h>

#define SUCCESS 0x00000000
#define FILESYSTEM_WATCHER_FILE_EXISTS 0x00000001
#define UNEXPECTED_ERROR 0xFFFFFFFF

/*
  check if the file exists
*/
bool IsFileExists(const wchar_t *const fileName)
{
    DWORD dwAttrib = GetFileAttributes(fileName);
    return dwAttrib != INVALID_FILE_SIZE;
}

/**
 <exe> <filesystemwatcherfilepath>
**/
int _tmain(int argc, wchar_t *argv[])
{
    if (argc < 2)
    {
        wprintf_s(L"ERROR:unexpected number arguments and expected is 5");
        return UNEXPECTED_ERROR;
    }

    if (IsFileExists(argv[1]))
    {
        wprintf_s(L"INFO:File:%s exists indicates Config Map Updated since agent started.\n", argv[1]);
        return FILESYSTEM_WATCHER_FILE_EXISTS;
    }

    return SUCCESS;
}
