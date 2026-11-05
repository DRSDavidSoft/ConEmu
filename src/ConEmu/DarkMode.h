#pragma once

// Custom-control palette; light and high-contrast modes use system rendering.
namespace DarkMode
{
	constexpr COLORREF Background = RGB(32, 32, 32);
	constexpr COLORREF Control = RGB(48, 48, 48);
	constexpr COLORREF Hover = RGB(64, 64, 64);
	constexpr COLORREF Text = RGB(240, 240, 240);
	constexpr COLORREF Hint = RGB(180, 180, 180);
	inline HBRUSH Brush(HDC dc, COLORREF color)
	{
		SetDCBrushColor(dc, color);
		return static_cast<HBRUSH>(GetStockObject(DC_BRUSH));
	}
}
