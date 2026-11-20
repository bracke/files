with Files.Input_Actions;
with Files.Rendering.Layouts;
with Guikit.Layout;
separate (Files_Suite.Rendering)
   --  The path and filter fields are text inputs for screen readers, bounded
   --  by the box drawn for them, and a request on either focuses that field.
   --  At 800 pixels the filter section's centre lies on the search-scope chip,
   --  which a synthesised centre click would cycle instead.
   procedure Test_Text_Fields_Are_Focused_By_Requests (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width   : constant := 800;
      Snap    : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Frame   : constant Frame_Commands := Build_Frame_Commands (Snap, Width, 480, 20);
      Toolbar : constant Guikit.Layout.Toolbar_Layout := Guikit.Layout.Calculate_Toolbar_Layout (Width, 20);
      Chip    : constant Guikit.Layout.Scope_Chip_Region :=
        Guikit.Layout.Filter_Scope_Chip_Region_Of
          (Toolbar, Files.Rendering.Layouts.Filter_Scope_Chip_Width (20), 20);
      Path_Seen, Filter_Seen : Boolean := False;
   begin
      Assert (Chip.Visible, "the scope chip is shown at this width");
      Assert
        (Toolbar.Right_X + Toolbar.Right_Width / 2 >= Chip.X,
         "the filter section's centre lies on the chip, the case a centre click gets wrong");
      for Node of Frame.Accessibility loop
         if Node.Role = Guikit.Draw.Role_Text_Input then
            declare
               Action : constant Files.Input_Actions.Input_Action :=
                 Files.Events.Translate_Field_Request (Node.X, Node.Y, Node.Width, Node.Height, Width, 20);
            begin
               Assert (Action.Kind = Files.Input_Actions.Command_Input_Action, To_String (Node.Name) & " is answered");
               if Action.Command = Files.Commands.Focus_Path_Input_Command then
                  Path_Seen := True;
               elsif Action.Command = Files.Commands.Focus_Filter_Input_Command then
                  Filter_Seen := True;
                  Assert (Node.X + Node.Width <= Chip.X, "the filter node ends before the chip");
               end if;
            end;
         end if;
      end loop;
      Assert (Path_Seen and then Filter_Seen, "both fields are focused by a request");
      Assert
        (Files.Events.Translate_Field_Request
           (Toolbar.Right_X, Guikit.Layout.Toolbar_Input_Y (20), Toolbar.Right_Width,
            Guikit.Layout.Toolbar_Input_Height (20), Width, 20).Kind = Files.Input_Actions.No_Input_Action,
         "a node over the whole section is no field");
   end Test_Text_Fields_Are_Focused_By_Requests;
