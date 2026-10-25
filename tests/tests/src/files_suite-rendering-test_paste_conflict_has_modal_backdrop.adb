separate (Files_Suite.Rendering)
   --  Conflict resolution consumes every click while it is open.  Dim the
   --  inactive file view so the visual hierarchy communicates the same modal
   --  state as the event reducer, and place the dialog above that scrim.
   procedure Test_Paste_Conflict_Has_Modal_Backdrop
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Width  : constant Natural  := 640;
      Height : constant Natural  := 480;
      LH     : constant Positive := 20;
      Snap   : View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Layout : Guikit.Draw.Layout_Metrics;
      Dialog : Conflict_Dialog_Layout;
      Backdrop_Seen     : Boolean := False;
      Panel_Seen        : Boolean := False;
      Shadow_Before_Panel : Natural := 0;
      Accessibility_Count : Natural := 0;
   begin
      Snap.Paste_Conflict_Open := True;
      Snap.Paste_Conflict_Name := To_Unbounded_String ("report.txt");
      Layout := Calculate_Layout (Snap, Width, Height, LH);
      Dialog := Calculate_Conflict_Dialog_Layout (Snap, Layout, LH);

      declare
         Frame : constant Frame_Commands := Build_Frame_Commands (Snap, Width, Height, LH);
      begin
         for Rect of Frame.Overlay_Rectangles loop
            if Rect.Color = Modal_Backdrop_Color
              and then Rect.X = 0
              and then Rect.Y = 0
              and then Rect.Width = Width
              and then Rect.Height = Height
            then
               Backdrop_Seen := True;
            elsif Rect.Color = Shadow_Color and then not Panel_Seen then
               Shadow_Before_Panel := Shadow_Before_Panel + 1;
            elsif Rect.Color = Overlay_Color
              and then Rect.X = Dialog.X
              and then Rect.Y = Dialog.Y
              and then Rect.Width = Dialog.Width
              and then Rect.Height = Dialog.Height
            then
               Assert
                 (Backdrop_Seen,
                  "the modal backdrop is emitted before the conflict-dialog surface");
               Panel_Seen := True;
            end if;
         end loop;

         for Node of Frame.Accessibility loop
            Accessibility_Count := Accessibility_Count + 1;
            Files_Suite.Support.Assert_Inside
              (Node.X, Node.Y, Node.Width, Node.Height, Dialog.X, Dialog.Y, Dialog.Width, Dialog.Height,
               "a modal conflict dialog exposes no background accessibility nodes");
         end loop;
      end;

      Assert (Backdrop_Seen, "the paste-conflict dialog emits a full-window modal backdrop");
      Assert (Panel_Seen, "the paste-conflict dialog emits its panel surface");
      Files_Suite.Support.Assert_Equal
        (Shadow_Before_Panel,
         Shadow_Rectangles,
         "the paste-conflict dialog emits the shared shadow before its panel surface");
      Assert
        (Accessibility_Count > 0,
         "the modal conflict dialog retains its own accessibility nodes");
   end Test_Paste_Conflict_Has_Modal_Backdrop;
