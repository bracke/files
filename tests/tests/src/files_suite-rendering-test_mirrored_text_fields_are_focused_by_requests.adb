with Files.Preference_Types;
with Files.Input_Actions;
with Files.Application.Window_Policy;
with Guikit.Mirroring;
separate (Files_Suite.Rendering)
   --  A right-to-left window shows its frame mirrored, and a screen reader
   --  is told where each node is shown: its request on the path or filter
   --  field names the reflected box, which is reflected back before it is
   --  matched against the fields as laid out.
   procedure Test_Mirrored_Text_Fields_Are_Focused_By_Requests (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Width : constant := 800;
      Snap  : constant View_Snapshot := Sample_Snapshot (6, Files.Preference_Types.Details);
      Shown : Guikit.Draw.Accessibility_Node_Vectors.Vector :=
        Build_Frame_Commands (Snap, Width, 480, 20).Accessibility;
      Path_Seen, Filter_Seen : Boolean := False;
   begin
      Guikit.Mirroring.Mirror (Shown, Width);
      Guikit.Mirroring.Set_Mirrored_Layout (True);
      for Node of Shown loop
         if Node.Role = Guikit.Draw.Role_Text_Input then
            declare
               Action : constant Files.Input_Actions.Input_Action :=
                 Files.Application.Window_Policy.Field_Request (Node.X, Node.Y, Node.Width, Node.Height, Width, 20);
            begin
               Assert (Action.Kind = Files.Input_Actions.Command_Input_Action, To_String (Node.Name) & " is answered");
               Path_Seen := Path_Seen or else Action.Command = Files.Commands.Focus_Path_Input_Command;
               Filter_Seen := Filter_Seen or else Action.Command = Files.Commands.Focus_Filter_Input_Command;
            end;
         end if;
      end loop;
      Guikit.Mirroring.Set_Mirrored_Layout (False);
      Assert (Path_Seen and then Filter_Seen, "both fields are focused by a request on their shown boxes");
      Files_Suite.Support.Assert_Equal
        (Files.Application.Window_Policy.Unmirrored_Node_X (10, 30, Width), 10,
                                                            "unmirrored, a box stays where it is shown");
   exception
      when others =>
         Guikit.Mirroring.Set_Mirrored_Layout (False);
         raise;
   end Test_Mirrored_Text_Fields_Are_Focused_By_Requests;
