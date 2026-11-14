separate (Files.Application.Windows.Render_Window)
   procedure Present_Frame
   is
      Snapshot : Files.Rendering.View_Snapshot renames Runtime.View.Snapshots (Runtime.View.Drawn_Slot);
      --  Whether an overlay is merged in below, so the frame shown differs
      --  from the cached one.
      Overlay_Merged : constant Boolean := Palette.Shown or else Settings.Shown;

      procedure Present (Frame : Files.Rendering.Frame_Commands) is separate;
   begin
      if Overlay_Merged then
         declare
            --  A working copy of the cached frame, so an overlay (whose state
            --  lives in its component and changes every frame) is merged in
            --  fresh without polluting the cache.
            Frame : Files.Rendering.Frame_Commands := Runtime.Cached_Frame;
         begin
            --  Settings remains logically open when Commands is invoked from it,
            --  but Commands is the active top-level modal and owns the pixels until
            --  it closes (Window_Overlay_Shown): only one is ever built.
            if Palette.Shown then
               Append_Modal_Backdrop (Frame, Natural (Width), Natural (Height));
               Append_Overlay (Frame, Palette.Rectangles, Palette.Text, Palette.Accessibility, Palette.Icons);
            end if;
            if Settings.Shown then
               Append_Modal_Backdrop (Frame, Natural (Width), Natural (Height));
               Append_Overlay (Frame, Settings.Rectangles, Settings.Text, Settings.Accessibility, Settings.Icons);
            end if;

            Present (Frame);
         end;
      else
         --  Nothing to merge: present the cached frame itself, uncopied.
         Present (Runtime.Cached_Frame);
      end if;

      --  Remember what we just put on screen so the next render's present gate
      --  can tell whether an overlay closed (a change that must be presented).
      Runtime.Presented_Once := True;
      Runtime.Last_Palette := Palette;
      Runtime.Last_Settings := Settings;

      --  Burn down one frame of the grace window. It is refilled above on any
      --  visible change, so it only reaches zero after a genuine idle gap.
      if Runtime.Present_Grace > 0 then
         Runtime.Present_Grace := Runtime.Present_Grace - 1;
      end if;
   end Present_Frame;
