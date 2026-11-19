with Guikit.Mirroring;
separate (Files.Application.Windows.Render_Window)
   procedure Present_Frame
   is
      Snapshot : Files.Rendering.View_Snapshot renames Runtime.View.Snapshots (Runtime.View.Drawn_Slot);
      --  Whether an overlay is merged in below, so the frame shown differs
      --  from the cached one.
      Overlay_Merged : constant Boolean := Palette.Shown or else Settings.Shown;

      --  Give Frame to the screen reader, its path to the title bar, and present it.
      procedure Show (Frame : Files.Rendering.Frame_Commands) is separate;

      --  Reflect Frame for a right-to-left layout, in place.
      procedure Mirror (Frame : in out Files.Rendering.Frame_Commands) is
         W : constant Natural := Frame.Layout.Width;
      begin
         Guikit.Mirroring.Mirror (Frame.Rectangles, W);
         Guikit.Mirroring.Mirror (Frame.Triangles, W);
         Guikit.Mirroring.Mirror (Frame.Text, W);
         Guikit.Mirroring.Mirror (Frame.Icons, W);
         Guikit.Mirroring.Mirror (Frame.Overlay_Rectangles, W);
         Guikit.Mirroring.Mirror (Frame.Overlay_Text, W);
         Guikit.Mirroring.Mirror (Frame.Tooltips, W);
         Guikit.Mirroring.Mirror (Frame.Accessibility, W);
         Guikit.Mirroring.Mirror (Frame.Layout);
      end Mirror;

      Mirrored : constant Boolean := Guikit.Mirroring.Mirrored_Layout;
   begin
      --  The cached frame keeps the unmirrored coordinates hit tests use, so
      --  what is shown is the cached frame itself only when nothing is merged
      --  in and nothing is reflected; otherwise it is Shown_Frame, the cached
      --  frame with the overlays merged in and reflected, made again only
      --  when the cached frame was rebuilt, an overlay changed or the layout
      --  direction turned -- not copied on every present.
      if Overlay_Merged or else Mirrored then
         if Frame_Rebuilt
           or else Overlay_Changed
           or else not Runtime.Shown_Frame_Valid
           or else Runtime.Shown_Frame_Mirrored /= Mirrored
         then
            Runtime.Shown_Frame := Runtime.Cached_Frame;
            --  Settings remains logically open when Commands is invoked from it,
            --  but Commands is the active top-level modal and owns the pixels until
            --  it closes (Window_Overlay_Shown): only one is ever built.
            if Palette.Shown then
               Append_Modal_Backdrop (Runtime.Shown_Frame, Natural (Width), Natural (Height));
               Append_Overlay
                 (Runtime.Shown_Frame, Palette.Rectangles, Palette.Text, Palette.Accessibility, Palette.Icons);
            end if;
            if Settings.Shown then
               Append_Modal_Backdrop (Runtime.Shown_Frame, Natural (Width), Natural (Height));
               Append_Overlay
                 (Runtime.Shown_Frame, Settings.Rectangles, Settings.Text, Settings.Accessibility, Settings.Icons);
            end if;

            if Mirrored then
               Mirror (Runtime.Shown_Frame);
            end if;
            Runtime.Shown_Frame_Valid := True;
            Runtime.Shown_Frame_Mirrored := Mirrored;
         end if;
         Show (Runtime.Shown_Frame);
      else
         --  Nothing to keep beside the cached frame.
         if Runtime.Shown_Frame_Valid then
            Runtime.Shown_Frame := (others => <>);
            Runtime.Shown_Frame_Valid := False;
         end if;
         Show (Runtime.Cached_Frame);
      end if;

      --  Remember what we just put on screen so the next render's present gate
      --  can tell whether an overlay closed (a change that must be presented).
      --  Unchanged, they are what was presented last.
      Runtime.Presented_Once := True;
      if Overlay_Changed then
         Runtime.Last_Palette := Palette;
         Runtime.Last_Settings := Settings;
      end if;

      --  Burn down one frame of the grace window. It is refilled above on any
      --  visible change, so it only reaches zero after a genuine idle gap.
      if Runtime.Present_Grace > 0 then
         Runtime.Present_Grace := Runtime.Present_Grace - 1;
      end if;
   end Present_Frame;
