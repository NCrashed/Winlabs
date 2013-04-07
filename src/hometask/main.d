//          Copyright Gushcha Anton 2013.
// Distributed under the Boost Software License, Version 1.0.
//    (See accompanying file LICENSE_1_0.txt or copy at
//          http://www.boost.org/LICENSE_1_0.txt)
/**
*   TODO: Сделать засечки на кратных единичному отрезках.
*   TODO: Сделать возможность ресайза.
*/
module lab4;

import core.runtime;
import std.string;
import std.utf;
import std.math;

import resource;
import expression;

import win32.windef;
import win32.winuser;
import win32.wingdi;
import win32.winbase;

ExprTree testTree;
string exprString = "x ^ 2";
static this()
{
    testTree = parseString(exprString);
}

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
        {
            SetDlgItemText(hDlg, IDC_EDIT1, exprString.toUTF16z);
            return TRUE;
        }
        case WM_COMMAND:
        {
            switch (LOWORD(wParam))
            {
                case IDOK:  
                {
                    HWND hCtrl = GetDlgItem(hDlg, IDC_EDIT1);
                    wchar[1024] buff;
                    auto l = GetWindowText(hCtrl, buff, 1024);

                    exprString = buff[0..l].toUTF8;
                    bool result = FALSE;
                    try
                    {
                        scope(success)
                        {
                            EndDialog(hDlg, 0);
                            result = true;
                        }
                        testTree = parseString(exprString);
                    } catch(ExpressionException e)
                    {
                         MessageBox(null, ("Failed to parser '"~exprString~"'"~e.msg).toUTF16z, "Error", MB_OK | MB_ICONEXCLAMATION);
                    }

                    return result;
                }
                case IDCANCEL:
                {
                    if(HIWORD(wParam) == 0)
                    {
                        EndDialog(hDlg, 0);
                        return TRUE;
                    }
                    return FALSE;
                }
                default:
            }

            break;
        }
        default:
    }

    return FALSE;
}

void CreateExprDialog(HINSTANCE hInstance, HWND hWnd)
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
    wndclass.hbrBackground = cast(HBRUSH)GetStockObject(WHITE_BRUSH);
    wndclass.lpszMenuName  = NULL;
    wndclass.lpszClassName = appName.toUTF16z;

    if(!RegisterClass(&wndclass))
    {
        MessageBox(NULL, "This program requires Windows NT!", appName.toUTF16z, MB_ICONERROR);
        return 0;
    }

    hwnd = CreateWindow(appName.toUTF16z,      // window class name
                         "Домашнее задание".toUTF16z,  // window caption
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
    static int sx, sy, width, height;
    static bool hideGraph = false;

    static HWND hideButton;
    enum HIDE_BUTTON_WIDTH = 120;
    enum HIDE_BUTTON_HEIGHT = 30;
    enum HIDE_BUTTON_MARGIN = 10;

    HDC hdc;
    static HMENU hMenu;
    static HMENU hMenuFile;
    PAINTSTRUCT ps;

    switch (message)
    {
        case WM_CREATE:
        {
            hInstance = (cast(LPCREATESTRUCT)lParam).hInstance;

            hMenu = LoadMenu(hInstance, "MAINMENU");
            hMenuFile = GetSubMenu(hMenu, 0);
            SetMenu(hwnd, hMenu);

            RECT rect;
            if(GetWindowRect(hwnd, &rect))
            {
                width = rect.right - rect.left;
                height = rect.bottom - rect.top;
                sx = width/2;
                sy = height/2;                
            }

            hideButton = CreateWindow(
                "button".toUTF16z, 
                "Скрыть график".toUTF16z, 
                WS_CHILD | WS_VISIBLE | BS_PUSHBUTTON, 
                width - HIDE_BUTTON_MARGIN - HIDE_BUTTON_WIDTH, 
                height - HIDE_BUTTON_MARGIN - HIDE_BUTTON_HEIGHT, 
                HIDE_BUTTON_WIDTH,
                HIDE_BUTTON_HEIGHT,
                hwnd, 
                cast(HMENU)IDB_HIDEBTN, 
                hInstance, 
                NULL
                );

            return 0;
        }
        case WM_SIZE:
        {
            width = LOWORD(lParam);
            height = HIWORD(lParam);
            sx = width/2;
            sy = height/2;  

            MoveWindow(
                hideButton,
                width - HIDE_BUTTON_MARGIN - HIDE_BUTTON_WIDTH, 
                height - HIDE_BUTTON_MARGIN - HIDE_BUTTON_HEIGHT, 
                HIDE_BUTTON_WIDTH,
                HIDE_BUTTON_HEIGHT,
                TRUE                
                );
            return 0;
        }
        case WM_DESTROY:
        {
            DestroyMenu(hMenu);
            PostQuitMessage(0);
            return 0;
        }
        case WM_LBUTTONDOWN:
        {
            return 0;
        }
        case WM_PAINT:
        {
            if (!hideGraph)
            {
                hdc = BeginPaint(hwnd, &ps);
                scope(exit) EndPaint(hwnd, &ps);

                DrawGraphic(hdc, testTree, sx, sy, width, height, 0.05f);
                return 0;
            }
            break;
        }
        case WM_COMMAND:
        {
            hMenu = GetMenu(hwnd);
            switch(LOWORD(wParam))
            {
                case IDM_SET_EQUATION:
                {
                    CreateExprDialog(hInstance, hwnd);
                    RECT rect;
                    rect.right  = 0;
                    rect.top    = 0;
                    rect.left   = width; 
                    rect.bottom = height;
                    InvalidateRect(hwnd, &rect, TRUE);
                    return 0;
                }
                case IDM_EXIT:
                {
                    DestroyMenu(hMenu);
                    PostQuitMessage(0);                    
                    return 0;
                }
                case IDB_HIDEBTN:
                {
                    hideGraph = !hideGraph;
                    RECT rect;
                    rect.right  = 0;
                    rect.top    = 0;
                    rect.left   = width; 
                    rect.bottom = height;
                    InvalidateRect(hwnd, &rect, TRUE);                    
                }
                default:
            }
        }
        default:
    }

    return DefWindowProc(hwnd, message, wParam, lParam);
}

void DrawGraphic(HDC hdc, ExprTree tree, int sx, int sy, int width, int height, float scale)
{
    enum DRAW_STEP = 0.1;
    enum PEN_TYPE = RGB(255, 0, 0);

    // Draw axis
    SelectObject(hdc, GetStockObject(BLACK_PEN));
    MoveToEx(hdc, 0, sy, NULL);
    LineTo(hdc, width, sy);

    MoveToEx(hdc, sx, 0, NULL);
    LineTo(hdc, sx, height);

    // Draw graphic
    SelectObject(hdc, GetStockObject(DC_PEN));
    SetDCPenColor(hdc, PEN_TYPE);
    double minX = - sx * scale;
    double maxX = (width-sx)*scale;
    double preX = minX;
    double preY = tree.compute(preX);
    for(double x = minX; x <= maxX; x += DRAW_STEP)
    {
        MoveToEx(hdc, sx + cast(int)(preX/scale), sy + cast(int)(-preY/scale), NULL);
        preX = x;
        preY = tree.compute(x);
        LineTo(hdc, sx + cast(int)(preX/scale), sy + cast(int)(-preY/scale));
    }
}