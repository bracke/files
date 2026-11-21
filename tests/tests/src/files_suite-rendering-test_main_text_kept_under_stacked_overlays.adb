with Files.Preference_Types;
separate (Files_Suite.Rendering)
   --  The palette opened from settings hides the settings pane, so the file
   --  view must still be drawn where the pane would be: every overlay panel
   --  is composited after the main layer, which keeps all of its text.
   procedure Test_Main_Text_Kept_Under_Stacked_Overlays
     (T : in out AUnit.Test_Cases.Test_Case'Class)
   is
      pragma Unreferenced (T);
      Width  : constant Natural  := 1000;
      Height : constant Natural  := 800;
      LH     : constant Positive := 20;
      Snap   : View_Snapshot := Sample_Snapshot (12, Files.Preference_Types.Details);
      Frame  : Frame_Commands;
      Pane   : Guikit.Layout.Settings_Pane_Layout;
      Under_Pane : Natural := 0;

      --  Whether the main layer alone draws Name.
      function Main_Layer_Has (Name : String) return Boolean is
      begin
         for Command of Frame.Text loop
            if To_String (Command.Text) = Name then
               if Command.Y >= Pane.Y and then Command.Y < Pane.Y + Pane.Height
                 and then Command.X < Pane.X + Pane.Width
                 and then Command.X + Command.Width > Pane.X
               then
                  Under_Pane := Under_Pane + 1;
               end if;
               return True;
            end if;
         end loop;
         return False;
      end Main_Layer_Has;
   begin
      Snap.Settings_Pane_Open := True;
      Snap.Command_Palette_Open := True;
      Frame := Build_Frame_Commands (Snap, Width, Height, LH);
      Pane := Files.Rendering.Layouts.Calculate_Frame_Layout (Snap, Width, Height, LH).Settings_Pane;
      for Item of Snap.Items loop
         Assert
           (Main_Layer_Has (To_String (Item.Name)),
            "the name " & To_String (Item.Name) & " stays in the main layer under the palette over settings");
      end loop;
      Assert (Under_Pane > 0, "some of those names lie where the settings pane would be drawn");
   end Test_Main_Text_Kept_Under_Stacked_Overlays;
