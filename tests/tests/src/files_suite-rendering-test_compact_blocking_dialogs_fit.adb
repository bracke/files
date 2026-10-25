separate (Files_Suite.Rendering)
   --  Blocking dialogs must remain fully operable in a short/narrow window:
   --  previously their fixed desktop height left live controls below the
   --  framebuffer even though the panel started at its top edge.
   procedure Test_Compact_Blocking_Dialogs_Fit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      LH     : constant Positive := 20;
      Compact_W : constant Natural := 80;
      Compact_H : constant Natural := 100;
      Snap      : View_Snapshot := Sample_Snapshot (1, Files.Types.Small_Icons);
      Layout    : Guikit.Draw.Layout_Metrics;
   begin
      Snap.Paste_Conflict_Open := True;
      Snap.Paste_Conflict_Name := To_Unbounded_String ("conflict.txt");
      Layout := Calculate_Layout (Snap, Compact_W, Compact_H, LH);
      declare
         Dialog : constant Conflict_Dialog_Layout :=
           Calculate_Conflict_Dialog_Layout (Snap, Layout, LH);
         Frame : constant Frame_Commands :=
           Build_Frame_Commands (Snap, Compact_W, Compact_H, LH);
      begin
         Assert
           (Dialog.X + Dialog.Width <= Compact_W
            and then Dialog.Y + Dialog.Height <= Compact_H,
            "the compact conflict dialog stays inside the framebuffer");
         Assert
           (Dialog.Cancel_X + Dialog.Button_Width <= Dialog.X + Dialog.Width
            and then Dialog.Button_Y + Dialog.Button_Height <= Dialog.Y + Dialog.Height,
            "the compact conflict action row stays inside its panel");
         for Node of Frame.Accessibility loop
            Files_Suite.Support.Assert_Inside
              (Node.X, Node.Y, Node.Width, Node.Height, Dialog.X, Dialog.Y, Dialog.Width, Dialog.Height,
               "compact conflict accessibility controls stay inside the panel");
         end loop;
      end;

      Snap.Paste_Conflict_Open := False;
      Snap.Paste_Progress_Open := True;
      Snap.Paste_Progress_Total := 2;
      Snap.Paste_Progress_Done := 1;
      Layout := Calculate_Layout (Snap, Compact_W, Compact_H, LH);
      declare
         Panel : constant Paste_Progress_Layout :=
           Calculate_Paste_Progress_Layout (Snap, Layout, LH);
         Frame : constant Frame_Commands :=
           Build_Frame_Commands (Snap, Compact_W, Compact_H, LH);
      begin
         Assert
           (Panel.X + Panel.Width <= Compact_W
            and then Panel.Y + Panel.Height <= Compact_H,
            "the compact paste-progress panel stays inside the framebuffer");
         Assert
           (Panel.Cancel_X + Panel.Cancel_Width <= Panel.X + Panel.Width
            and then Panel.Cancel_Y + Panel.Cancel_Height <= Panel.Y + Panel.Height,
            "the compact progress Cancel button stays inside its panel");
         for Node of Frame.Accessibility loop
            Files_Suite.Support.Assert_Inside
              (Node.X, Node.Y, Node.Width, Node.Height, Panel.X, Panel.Y, Panel.Width, Panel.Height,
               "compact progress accessibility controls stay inside the panel");
         end loop;
      end;
   end Test_Compact_Blocking_Dialogs_Fit;
