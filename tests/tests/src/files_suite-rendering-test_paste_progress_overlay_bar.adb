separate (Files_Suite.Rendering)
   --  Paste-progress overlay: exposes a Cancel affordance and a proportional
   --  progress bar while a long copy/move is in flight.
   procedure Test_Paste_Progress_Overlay_Bar (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
      Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
      Layout : Guikit.Draw.Layout_Metrics;
      Panel  : Paste_Progress_Layout;
      Frame  : Frame_Commands;
      Expected_Fill : Natural;
      Backdrop_Seen : Boolean := False;
      Shadow_Count  : Natural := 0;
      Accessibility_Count : Natural := 0;
   begin
      Snap.Paste_Progress_Open := True;
      Snap.Paste_Progress_Done := 3;
      Snap.Paste_Progress_Total := 10;
      Snap.Paste_Progress_Name := To_Unbounded_String ("bigfile.bin");
      Layout := Calculate_Layout (Snap, Width, Height, LH);
      Panel  := Calculate_Paste_Progress_Layout (Snap, Layout, LH);
      Frame  := Build_Frame_Commands (Snap, Width, Height, LH);
      Expected_Fill := (Panel.Bar_Width * Snap.Paste_Progress_Done) / Snap.Paste_Progress_Total;
      Assert
        (Conflict_Hit_At (Frame, Panel.Cancel_X + Panel.Cancel_Width / 2,
           Panel.Cancel_Y + Panel.Cancel_Height / 2).Kind = Conflict_Hit_Progress_Cancel,
         "the paste-progress overlay exposes a hit-testable Cancel button");
      Assert (Expected_Fill > 0, "a partial progress produces a non-empty filled bar");
      Assert
        (Has_Overlay_Rect_At (Frame, Panel.Bar_X, Panel.Bar_Y, Expected_Fill, Panel.Bar_Height),
         "the progress bar's filled width is proportional to Done / Total");
      Assert
        (Frame_Has_Text (Frame, "3 of 10"),
         "the progress overlay keeps the completed and total item counts when no label is present");
      for Rect of Frame.Overlay_Rectangles loop
         if Rect.Color = Modal_Backdrop_Color
           and then Rect.X = 0
           and then Rect.Y = 0
           and then Rect.Width = Width
           and then Rect.Height = Height
         then
            Backdrop_Seen := True;
         elsif Rect.Color = Shadow_Color then
            Shadow_Count := Shadow_Count + 1;
         end if;
      end loop;
      Assert (Backdrop_Seen, "blocking paste progress dims the inactive file view");
      Files_Suite.Support.Assert_Equal
        (Shadow_Count,
         Shadow_Rectangles,
         "paste progress uses the shared banded panel shadow");

      for Node of Frame.Accessibility loop
         Accessibility_Count := Accessibility_Count + 1;
         Files_Suite.Support.Assert_Inside
           (Node.X, Node.Y, Node.Width, Node.Height, Panel.X, Panel.Y, Panel.Width, Panel.Height,
            "blocking paste progress exposes no background accessibility nodes");
      end loop;
      Assert
        (Accessibility_Count > 0,
         "blocking paste progress retains its dialog and Cancel accessibility nodes");
   end Test_Paste_Progress_Overlay_Bar;
