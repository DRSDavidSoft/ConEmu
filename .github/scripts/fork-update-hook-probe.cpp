#include <windows.h>
#include <cwchar>

int wmain(int argc, wchar_t** argv)
{
    if (argc != 2)
        return 1;

    wchar_t path[MAX_PATH]{};
    const wchar_t* hookName = sizeof(void*) == 8 ? L"ConEmuHk64.dll" : L"ConEmuHk.dll";
    const HMODULE hook = GetModuleHandleW(hookName);
    if (hook)
        GetModuleFileNameW(hook, path, MAX_PATH);

    const HANDLE report = CreateFileW(argv[1], GENERIC_WRITE, FILE_SHARE_READ, nullptr,
        CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, nullptr);
    if (report == INVALID_HANDLE_VALUE)
        return 2;

    const auto size = static_cast<DWORD>(wcslen(path) * sizeof(wchar_t));
    DWORD written = 0;
    const bool saved = WriteFile(report, path, size, &written, nullptr) && written == size;
    CloseHandle(report);
    return (hook && saved) ? 0 : 3;
}
