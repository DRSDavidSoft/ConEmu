#define HIDE_USE_EXCEPTION_INFO
#include "Header.h"
#include "ConEmu.h"
#include "DarkMode.h"

namespace DarkMode
{
namespace
{
constexpr UINT_PTR SubclassId = 0xCEda;
constexpr COLORREF Border = RGB(100, 100, 100);
constexpr COLORREF Accent = RGB(110, 170, 220);

bool IsClass(HWND window, LPCWSTR expected)
{
	wchar_t name[64] = {};
	GetClassName(window, name, countof(name));
	return lstrcmpi(name, expected) == 0;
}

void PaintButton(HWND window, HDC dc)
{
	const int saved = SaveDC(dc);
	RECT rc; GetClientRect(window, &rc);
	const DWORD style = GetWindowLong(window, GWL_STYLE);
	const DWORD type = style & BS_TYPEMASK;
	const LRESULT state = SendMessage(window, BM_GETSTATE, 0, 0);
	const bool enabled = IsWindowEnabled(window) != FALSE;
	const bool pressed = (state & BST_PUSHED) != 0;
	POINT cursor; GetCursorPos(&cursor); ScreenToClient(window, &cursor);
	const bool hot = enabled && PtInRect(&rc, cursor);
	const bool check = type == BS_CHECKBOX || type == BS_AUTOCHECKBOX || type == BS_3STATE || type == BS_AUTO3STATE;
	const bool radio = type == BS_RADIOBUTTON || type == BS_AUTORADIOBUTTON;
	const bool group = type == BS_GROUPBOX;
	const bool push = !group && (!(check || radio) || (style & BS_PUSHLIKE));
	FillRect(dc, &rc, Brush(dc, push ? (pressed ? RGB(80,80,80) : hot ? Hover : Control) : Background));
	SelectObject(dc, reinterpret_cast<HFONT>(SendMessage(window, WM_GETFONT, 0, 0)));
	SetTextColor(dc, enabled ? Text : Hint);
	SetBkMode(dc, TRANSPARENT);
	wchar_t text[1024] = {}; GetWindowText(window, text, countof(text));
	TEXTMETRIC metrics = {}; GetTextMetrics(dc, &metrics);
	const int unit = std::max(13L, metrics.tmHeight);
	HPEN pen = CreatePen(PS_SOLID, 1, (hot || GetFocus() == window || type == BS_DEFPUSHBUTTON) ? Accent : Border);
	HGDIOBJ oldPen = SelectObject(dc, pen);
	HGDIOBJ oldBrush = SelectObject(dc, GetStockObject(NULL_BRUSH));
	RECT label = rc;
	if (group)
	{
		Rectangle(dc, 0, metrics.tmHeight/2, rc.right, rc.bottom);
		label.left += unit / 2; label.bottom = label.top + metrics.tmHeight;
		RECT bounds = label; DrawText(dc, text, -1, &bounds, DT_CALCRECT | DT_SINGLELINE);
		bounds.right += 4; FillRect(dc, &bounds, Brush(dc, Background));
	}
	else if (push)
	{
		RoundRect(dc, 0, 0, rc.right, rc.bottom, 5, 5);
		InflateRect(&label, -4, -2);
	}
	else
	{
		const int x = (style & BS_LEFTTEXT) ? rc.right - unit : 1;
		const int y = (rc.bottom - unit) / 2;
		if (radio) Ellipse(dc, x, y, x + unit, y + unit);
		else Rectangle(dc, x, y, x + unit, y + unit);
		const LRESULT checked = SendMessage(window, BM_GETCHECK, 0, 0);
		if (checked)
		{
			RECT mark = {x + 3, y + 3, x + unit - 3, y + unit - 3};
			if (radio)
			{
				SelectObject(dc, Brush(dc, enabled ? Accent : Hint));
				Ellipse(dc, mark.left, mark.top, mark.right, mark.bottom);
				SelectObject(dc, GetStockObject(NULL_BRUSH));
			}
			else if (checked == BST_INDETERMINATE)
				FillRect(dc, &mark, Brush(dc, Hint));
			else
			{
				MoveToEx(dc, x+3, y+unit/2, nullptr);
				LineTo(dc, x+unit/2, y+unit-4); LineTo(dc, x+unit-3, y+3);
			}
		}
		if (style & BS_LEFTTEXT) label.right -= unit + 5;
		else label.left += unit + 5;
	}
	UINT flags = DT_VCENTER | ((style & BS_MULTILINE) ? DT_WORDBREAK : DT_SINGLELINE);
	if (push) flags |= DT_CENTER;
	if (SendMessage(window, WM_QUERYUISTATE, 0, 0) & UISF_HIDEACCEL) flags |= DT_HIDEPREFIX;
	DrawText(dc, text, -1, &label, flags);
	if (!group && GetFocus() == window && !(SendMessage(window, WM_QUERYUISTATE, 0, 0) & UISF_HIDEFOCUS))
	{
		RECT focus = push ? rc : label; InflateRect(&focus, -3, -3); DrawFocusRect(dc, &focus);
	}
	SelectObject(dc, oldBrush); SelectObject(dc, oldPen); DeleteObject(pen);
	RestoreDC(dc, saved);
}

void PaintTabs(HWND window, HDC dc)
{
	const int saved = SaveDC(dc);
	RECT client; GetClientRect(window, &client);
	FillRect(dc, &client, Brush(dc, Background));
	SelectObject(dc, reinterpret_cast<HFONT>(SendMessage(window, WM_GETFONT, 0, 0)));
	SetBkMode(dc, TRANSPARENT); SetTextColor(dc, Text);
	POINT cursor; GetCursorPos(&cursor); ScreenToClient(window, &cursor);
	for (int i = 0; i < TabCtrl_GetItemCount(window); ++i)
	{
		RECT rc; if (!TabCtrl_GetItemRect(window, i, &rc)) continue;
		wchar_t text[256] = {}; TCITEM item = {};
		item.mask = TCIF_TEXT; item.pszText = text; item.cchTextMax = countof(text);
		TabCtrl_GetItem(window, i, &item);
		bool selected = i == TabCtrl_GetCurSel(window);
		FillRect(dc, &rc, Brush(dc, selected ? Hover : PtInRect(&rc,cursor) ? Control : Background));
		if (selected)
		{
			RECT line = rc; line.right = line.left + 2; FillRect(dc, &line, Brush(dc, Accent));
		}
		DrawText(dc, text, -1, &rc, DT_CENTER | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS | DT_NOPREFIX);
		if (selected && GetFocus() == window && !(SendMessage(window, WM_QUERYUISTATE, 0, 0) & UISF_HIDEFOCUS))
		{
			InflateRect(&rc, -3, -3); DrawFocusRect(dc, &rc);
		}
	}
	RestoreDC(dc, saved);
}

LRESULT CALLBACK ControlProc(HWND window, UINT message, WPARAM wp, LPARAM lp, UINT_PTR id, DWORD_PTR kind)
{
	if (message == WM_NCDESTROY) RemoveWindowSubclass(window, ControlProc, id);
	if (global::g_darkModeEnabled)
	{
		if (message >= WM_CTLCOLORMSGBOX && message <= WM_CTLCOLORSTATIC)
			return reinterpret_cast<LRESULT>(ControlColor(reinterpret_cast<HWND>(lp), reinterpret_cast<HDC>(wp), message));
		if (kind && (message == WM_PAINT || message == WM_PRINTCLIENT))
		{
			PAINTSTRUCT ps = {};
			HDC dc = message == WM_PAINT ? BeginPaint(window, &ps) : reinterpret_cast<HDC>(wp);
			if (kind == 1) PaintButton(window, dc); else PaintTabs(window, dc);
			if (message == WM_PAINT) EndPaint(window, &ps);
			return 0;
		}
		if (kind && message == WM_ERASEBKGND) return 1;
		if (kind && message == WM_MOUSEMOVE)
		{
			TRACKMOUSEEVENT track = {sizeof(track), TME_LEAVE, window, 0}; TrackMouseEvent(&track);
		}
	}
	const LRESULT result = DefSubclassProc(window, message, wp, lp);
	if (kind && (message == WM_MOUSEMOVE || message == WM_MOUSELEAVE || message == WM_LBUTTONDOWN
		|| message == WM_LBUTTONUP || message == WM_KEYDOWN || message == WM_KEYUP || message == WM_ENABLE
		|| message == BM_SETCHECK || message == BM_SETSTATE || message == WM_SETFOCUS || message == WM_KILLFOCUS))
		InvalidateRect(window, nullptr, FALSE);
	return result;
}

BOOL CALLBACK ApplyControl(HWND window, LPARAM)
{
	if (IsClass(window, L"#32770")) return TRUE;
	const bool dark = global::g_darkModeEnabled;
	AllowDarkModeForWindow(window, dark);
	DWORD_PTR kind = 0;
	if (IsClass(window, L"Button"))
	{
		const DWORD style = GetWindowLong(window, GWL_STYLE);
		if ((style & BS_TYPEMASK) != BS_OWNERDRAW && !(style & (BS_BITMAP | BS_ICON))) kind = 1;
	}
	else if (IsClass(window, WC_TABCONTROL)) kind = 2;
	SetWindowSubclass(window, ControlProc, SubclassId, kind);
	const wchar_t* theme = dark ? L"DarkMode_Explorer" : nullptr;
	if (IsClass(window, L"Edit") || IsClass(window, L"ComboBox")) theme = dark ? L"DarkMode_CFD" : nullptr;
	gpConEmu->SetWindowTheme(window, theme, nullptr);
	if (IsClass(window, WC_TREEVIEW))
	{
		TreeView_SetBkColor(window, dark ? Control : GetSysColor(COLOR_WINDOW));
		TreeView_SetTextColor(window, dark ? Text : GetSysColor(COLOR_WINDOWTEXT));
	}
	if (IsClass(window, WC_LISTVIEW))
	{
		ListView_SetBkColor(window, dark ? Control : GetSysColor(COLOR_WINDOW));
		ListView_SetTextBkColor(window, dark ? Control : GetSysColor(COLOR_WINDOW));
		ListView_SetTextColor(window, dark ? Text : GetSysColor(COLOR_WINDOWTEXT));
	}
	RedrawWindow(window, nullptr, nullptr, RDW_INVALIDATE | RDW_ERASE | RDW_FRAME);
	return TRUE;
}
}

HBRUSH ControlColor(HWND control, HDC dc, UINT message)
{
	if (!global::g_darkModeEnabled) return nullptr;
	const bool edit = IsClass(control, L"Edit") || IsClass(control, L"ListBox") || IsClass(control, L"ComboBox");
	const COLORREF background = edit ? Control : Background;
	SetTextColor(dc, IsWindowEnabled(control) ? Text : Hint);
	SetBkColor(dc, background);
	return Brush(dc, background);
}

void ApplyDialog(HWND dialog)
{
	if (!global::g_darkModeSupported) return;
	gpConEmu->RefreshTitleBarThemeColor(dialog);
	EnumChildWindows(dialog, ApplyControl, 0);
	RedrawWindow(dialog, nullptr, nullptr, RDW_INVALIDATE | RDW_ERASE | RDW_FRAME | RDW_ALLCHILDREN);
}

bool ProcessDialogMessage(HWND dialog, UINT message, WPARAM wp, LPARAM lp, INT_PTR& result)
{
	if (message == WM_THEMECHANGED || (message == WM_SETTINGCHANGE
		&& (IsColorSchemeChangeMessage(lp) || wp == SPI_SETHIGHCONTRAST)))
		ApplyDialog(dialog);
	if (global::g_darkModeEnabled && (message == WM_CTLCOLORDLG || message == WM_CTLCOLOREDIT
		|| message == WM_CTLCOLORLISTBOX || message == WM_CTLCOLORBTN))
	{
		result = reinterpret_cast<INT_PTR>(ControlColor(reinterpret_cast<HWND>(lp), reinterpret_cast<HDC>(wp), message));
		return true;
	}
	return false;
}
}
