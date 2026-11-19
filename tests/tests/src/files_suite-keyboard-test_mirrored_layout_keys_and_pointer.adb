with Files.Window_Policy;
with Files.Controller.Testing;
with Files_Suite.Support.Models;
with Glfw;
with Guikit.Mirroring;
separate (Files_Suite.Keyboard)
   --  A right-to-left interface draws the window mirrored: the grid fills
   --  from the right, so Right steps back through it and Left on; a focused
   --  text field keeps its reading order, and its arrows are not traded. The
   --  pointer's X is reflected back into the frame as drawn before mirroring.
   procedure Test_Mirrored_Layout_Keys_And_Pointer (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model := Files_Suite.Support.Models.Sample_Model;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;

      procedure Press (Key : Guikit.Input.Key_Code) is
      begin
         Files.Interaction.Handle_Key
           (Model => Model, Settings => Settings, Settings_Path => "", Key => Key, Result => Result);
      end Press;
   begin
      Guikit.Mirroring.Set_Mirrored_Layout (True);
      Files.Model.Selection.Select_Visible (Model, 2);
      Press (Guikit.Input.Key_Right);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selection.Selected_Index (Model), 1, "Right steps back to the item drawn right of it");
      Press (Guikit.Input.Key_Left);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selection.Selected_Index (Model), 2, "Left steps on to the item drawn left of it");

      Files.Model.Focus_Filter_Input (Model);
      Files.Controller.Testing.Replace_Focused_Text (Model, "abc");
      Press (Guikit.Input.Key_Left);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model), 2, "in a text field Left still moves the caret left");

      Files_Suite.Support.Assert_Equal
        (Files.Window_Policy.Scale_X (10.2, Glfw.Size (100), Glfw.Size (100)), 89,
         "the pointer's column is reflected");
      Files_Suite.Support.Assert_Equal
        (Files.Window_Policy.Scale_X (150.0, Glfw.Size (100), Glfw.Size (100)), 0,
         "a drag held past the shown right edge is past the drawn frame's left edge");
      Files_Suite.Support.Assert_Equal
        (Files.Window_Policy.Scale_X (100.0, Glfw.Size (100), Glfw.Size (100)), 0,
         "the shown right edge itself is the drawn frame's left edge");
      Guikit.Mirroring.Set_Mirrored_Layout (False);
      Files_Suite.Support.Assert_Equal
        (Files.Window_Policy.Scale_X (10.2, Glfw.Size (100), Glfw.Size (100)), 10,
         "unmirrored, the column is the one under the pointer");
   exception
      when others =>
         Guikit.Mirroring.Set_Mirrored_Layout (False);
         raise;
   end Test_Mirrored_Layout_Keys_And_Pointer;
