separate (Files_Suite.Rendering)
   procedure Test_Dialog_Overlays_Expose_Close_Button (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
   begin
      --  Quick Look overlay.
      declare
         Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout : Guikit.Draw.Layout_Metrics;
         QL     : Quick_Look_Layout;
         Close  : Close_Button_Layout;
         Frame  : Frame_Commands;
      begin
         Snap.Quick_Look_Open := True;
         Snap.Quick_Look_Kind := Files.Quick_Look.Info_Content;
         Snap.Quick_Look_Name := To_Unbounded_String ("notes.txt");
         Layout := Calculate_Layout (Snap, Width, Height, LH);
         QL     := Calculate_Quick_Look_Layout (Layout, LH);
         Close  := Panel_Close_Button (QL.X, QL.Y, QL.Width, QL.Height, LH);
         Frame  := Build_Frame_Commands (Snap, Width, Height, LH);
         Assert (Close.Visible, "the quick look overlay hosts a close button");
         Assert
           (Has_Close_Button_Node (Frame, Close),
            "the open quick look overlay emits a close-button accessibility node");
      end;

      --  Color-label picker overlay.
      declare
         Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout : Guikit.Draw.Layout_Metrics;
         Picker : Label_Picker_Layout;
         Close  : Close_Button_Layout;
         Frame  : Frame_Commands;
      begin
         Snap.Label_Picker_Open := True;
         Layout := Calculate_Layout (Snap, Width, Height, LH);
         Picker := Calculate_Label_Picker_Layout (Layout, LH);
         Close  := Panel_Close_Button (Picker.X, Picker.Y, Picker.Width, Picker.Height, LH);
         Frame  := Build_Frame_Commands (Snap, Width, Height, LH);
         Assert (Close.Visible, "the label picker hosts a close button");
         Assert
           (Has_Close_Button_Node (Frame, Close),
            "the open label picker emits a close-button accessibility node");
      end;

      --  Paste-conflict dialog.
      declare
         Snap   : View_Snapshot := Sample_Snapshot (3, Files.Types.Small_Icons);
         Layout : Guikit.Draw.Layout_Metrics;
         Dialog : Conflict_Dialog_Layout;
         Close  : Close_Button_Layout;
         Frame  : Frame_Commands;
      begin
         Snap.Paste_Conflict_Open := True;
         Snap.Paste_Conflict_Name := To_Unbounded_String ("report.txt");
         Layout := Calculate_Layout (Snap, Width, Height, LH);
         Dialog := Calculate_Conflict_Dialog_Layout (Snap, Layout, LH);
         Close  := Panel_Close_Button (Dialog.X, Dialog.Y, Dialog.Width, Dialog.Height, LH);
         Frame  := Build_Frame_Commands (Snap, Width, Height, LH);
         Assert (Close.Visible, "the paste-conflict dialog hosts a close button");
         Assert
           (Has_Close_Button_Node (Frame, Close),
            "the open paste-conflict dialog emits a close-button accessibility node");
         Assert
           (Conflict_Hit_At (Frame, Dialog.Replace_X + Dialog.Button_Width / 2,
              Dialog.Button_Y + Dialog.Button_Height / 2).Kind = Conflict_Hit_Replace,
            "the replace button is hit-testable at its center");
      end;
   end Test_Dialog_Overlays_Expose_Close_Button;
