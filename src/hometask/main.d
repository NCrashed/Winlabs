module lab4;

import core.runtime;
import std.string;
import std.utf;
import resource;
import expression;

import win32.windef;
import win32.winuser;
import win32.wingdi;

auto toUTF16z(S)(S s)
{
    return toUTFz!(const(wchar)*)(s);
}

pragma(lib, "gdi32.lib");

extern (Windows)
BOOL dialogProc(HWND hDlg, UINT message, WPARAM wParam, LPARAM lParam)
{
    switch (message)
    {
        case WM_INITDIALOG:
            return TRUE;

        case WM_COMMAND:

            switch (LOWORD(wParam))
            {
                case IDOK:  
                    EndDialog(hDlg, 0);
                    return TRUE;
                case IDCANCEL:
                    if(HIWORD(wParam) == 0)
                    {
                        EndDialog(hDlg, 0);
                        return TRUE;
                    }
                    return FALSE;
                
                default:
            }

            break;

        default:
    }

    return FALSE;
}

void CreateDialogByVar(HINSTANCE hInstance, HWND hWnd)
{
     DialogBox(hInstance, "MYDIALOG", hWnd, &dialogProc);
}

extern(Windows)
int WinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    int result;
    void exceptionHandler(Throwable e) { throw e; }

    try
    {
        Runtime.initialize(&exceptionHandler);
        result = myWinMain(hInstance, hPrevInstance, lpCmdLine, iCmdShow);
        Runtime.terminate(&exceptionHandler);
    }
    catch(Throwable o)
    {
        MessageBox(null, o.toString().toUTF16z, "Error", MB_OK | MB_ICONEXCLAMATION);
        result = 0;
    }

    return result;
}

int myWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance, LPSTR lpCmdLine, int iCmdShow)
{
    string appName = "HelloWin";
    HWND hwnd;
    MSG  msg;
    WNDCLASS wndclass;

    wndclass.style         = CS_HREDRAW | CS_VREDRAW;
    wndclass.lpfnWndProc   = &WndProc;
    wndclass.cbClsExtra    = 0;
    wndclass.cbWndExtra    = 0;
    wndclass.hInstance     = hInstance;
    wndclass.hIcon         = LoadIcon(NULL, IDI_APPLICATION);
    wndclass.hCursor       = LoadCursor(NULL, IDC_ARROW);
    wndclass.hbrBackground = cast(HBRUSH)GetStockObject(GRAY_BRUSH);
    wndclass.lpszMenuName  = NULL;
    wndclass.lpszClassName = appName.toUTF16z;

    if(!RegisterClass(&wndclass))
    {
        MessageBox(NULL, "This program requires Windows NT!", appName.toUTF16z, MB_ICONERROR);
        return 0;
    }

    hwnd = CreateWindow(appName.toUTF16z,      // window class name
                         "Лабораторная работа 4",  // window caption
                         WS_OVERLAPPEDWINDOW,  // window style
                         CW_USEDEFAULT,        // initial x position
                         CW_USEDEFAULT,        // initial y position
                         CW_USEDEFAULT,        // initial x size
                         CW_USEDEFAULT,        // initial y size
                         NULL,                 // parent window handle
                         NULL,                 // window menu handle
                         hInstance,            // program instance handle
                         NULL);                // creation parameters

    ShowWindow(hwnd, iCmdShow);
    UpdateWindow(hwnd);

    while (GetMessage(&msg, NULL, 0, 0))
    {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    return msg.wParam;
}

extern(Windows)
LRESULT WndProc(HWND hwnd, UINT message, WPARAM wParam, LPARAM lParam)
{
    static HINSTANCE hInstance;

    switch (message)
    {
        case WM_CREATE:
            hInstance = (cast(LPCREATESTRUCT)lParam).hInstance;
            return 0;

        case WM_DESTROY:
            PostQuitMessage(0);
            return 0;

        case WM_LBUTTONDOWN:
            CreateDialogByVar(hInstance, hwnd);
            return 0;
        default:
    }

    return DefWindowProc(hwnd, message, wParam, lParam);
}
