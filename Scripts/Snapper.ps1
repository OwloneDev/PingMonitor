# Snapper.ps1

# Класс для прилипания окна к краям экрана
Add-Type -TypeDefinition @"
using System;
using System.Drawing;
using System.Runtime.InteropServices;
using System.Windows.Forms;

public class WindowSnapper : NativeWindow
{
    private const int WM_MOVING = 0x0216;
    private const int SnapDistance = 20;
    private const int ReleaseDistance = 5;

    private bool snappedLeft = false;
    private bool snappedRight = false;
    private bool snappedTop = false;
    private bool snappedBottom = false;

    private int anchorX = 0;
    private int anchorY = 0;

    [DllImport("user32.dll")]
    private static extern bool GetCursorPos(out POINT lpPoint);

    [StructLayout(LayoutKind.Sequential)]
    private struct RECT
    {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }

    [StructLayout(LayoutKind.Sequential)]
    private struct POINT
    {
        public int X;
        public int Y;
    }

    public WindowSnapper(IntPtr handle)
    {
        AssignHandle(handle);
    }

    protected override void WndProc(ref Message m)
    {
        if (m.Msg == WM_MOVING)
        {
            RECT rect = (RECT)Marshal.PtrToStructure(m.LParam, typeof(RECT));
            int width = rect.Right - rect.Left;
            int height = rect.Bottom - rect.Top;

            Rectangle wa = Screen.FromRectangle(
                new Rectangle(rect.Left, rect.Top, width, height)
            ).WorkingArea;

            POINT cursor;
            GetCursorPos(out cursor);

            // ============ ЛЕВЫЙ КРАЙ ============
            if (snappedLeft)
            {
                if (cursor.X > anchorX + ReleaseDistance)
                {
                    snappedLeft = false;
                    rect.Left = wa.Left + SnapDistance + 1;
                    rect.Right = rect.Left + width;
                }
                else
                {
                    if (cursor.X < anchorX) anchorX = cursor.X;
                    rect.Left = wa.Left;
                    rect.Right = rect.Left + width;
                }
            }
            else if (Math.Abs(rect.Left - wa.Left) < SnapDistance)
            {
                snappedLeft = true;
                anchorX = cursor.X;
                rect.Left = wa.Left;
                rect.Right = rect.Left + width;
            }

            // ============ ПРАВЫЙ КРАЙ ============
            if (snappedRight)
            {
                if (cursor.X < anchorX - ReleaseDistance)
                {
                    snappedRight = false;
                    rect.Right = wa.Right - SnapDistance - 1;
                    rect.Left = rect.Right - width;
                }
                else
                {
                    if (cursor.X > anchorX) anchorX = cursor.X;
                    rect.Right = wa.Right;
                    rect.Left = rect.Right - width;
                }
            }
            else if (Math.Abs(rect.Right - wa.Right) < SnapDistance)
            {
                snappedRight = true;
                anchorX = cursor.X;
                rect.Right = wa.Right;
                rect.Left = rect.Right - width;
            }

            // ============ ВЕРХНИЙ КРАЙ ============
            if (snappedTop)
            {
                if (cursor.Y > anchorY + ReleaseDistance)
                {
                    snappedTop = false;
                    rect.Top = wa.Top + SnapDistance + 1;
                    rect.Bottom = rect.Top + height;
                }
                else
                {
                    if (cursor.Y < anchorY) anchorY = cursor.Y;
                    rect.Top = wa.Top;
                    rect.Bottom = rect.Top + height;
                }
            }
            else if (Math.Abs(rect.Top - wa.Top) < SnapDistance)
            {
                snappedTop = true;
                anchorY = cursor.Y;
                rect.Top = wa.Top;
                rect.Bottom = rect.Top + height;
            }

            // ============ НИЖНИЙ КРАЙ ============
            if (snappedBottom)
            {
                if (cursor.Y < anchorY - ReleaseDistance)
                {
                    snappedBottom = false;
                    rect.Bottom = wa.Bottom - SnapDistance - 1;
                    rect.Top = rect.Bottom - height;
                }
                else
                {
                    if (cursor.Y > anchorY) anchorY = cursor.Y;
                    rect.Bottom = wa.Bottom;
                    rect.Top = rect.Bottom - height;
                }
            }
            else if (Math.Abs(rect.Bottom - wa.Bottom) < SnapDistance)
            {
                snappedBottom = true;
                anchorY = cursor.Y;
                rect.Bottom = wa.Bottom;
                rect.Top = rect.Bottom - height;
            }

            Marshal.StructureToPtr(rect, m.LParam, false);
        }

        base.WndProc(ref m);
    }
}
"@ -ReferencedAssemblies System.Windows.Forms, System.Drawing -WarningAction SilentlyContinue