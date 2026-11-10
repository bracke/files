with Files.Rendering.Hit;
separate (Files_Suite.Rendering)
   --  Each sortable details-header cell is a button of its own for screen
   --  readers, placed so its centre hits that cell and its sort command --
   --  what activating it from a screen reader dispatches.
   procedure Test_Header_Cells_Are_Accessible_Buttons (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Snap    : constant View_Snapshot := Sample_Snapshot (6, Files.Types.Details);
      Layout  : constant Guikit.Draw.Layout_Metrics := Calculate_Layout (Snap, 900, 480, 20);
      Frame   : constant Frame_Commands := Build_Frame_Commands (Snap, 900, 480, 20);
      Buttons : Natural := 0;
   begin
      for Node of Frame.Accessibility loop
         if Node.Role = Guikit.Draw.Role_Button then
            declare
               Cell : constant Detail_Header_Cell :=
                 Files.Rendering.Hit.Details_Header_Cell_At
                   (Snap, Layout, Node.X + Node.Width / 2, Node.Y + Node.Height / 2, 20);
            begin
               if Cell.Present then
                  Buttons := Buttons + 1;
                  Assert (Cell.Command /= Files.Commands.No_Command,
                          To_String (Node.Name) & " sorts when activated");
               end if;
            end;
         end if;
      end loop;
      Assert (Buttons >= 2, "the visible sortable header cells are buttons:" & Buttons'Image);
   end Test_Header_Cells_Are_Accessible_Buttons;
