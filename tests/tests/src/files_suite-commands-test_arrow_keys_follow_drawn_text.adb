with Files.Item_Lists;
with Files.Controller.Testing;
with Files_Suite.Support.Disk;
separate (Files_Suite.Commands)
   procedure Test_Arrow_Keys_Follow_Drawn_Text (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function U8 (Text : Wide_Wide_String) return String is
        (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Text));
      --  Alef, bet, gimel: two bytes each, drawn gimel bet alef, so the text
      --  starts at the right edge.
      Hebrew   : constant String := U8 ("אבג");
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model    : Files.Model.Window_Model := Sample_Model;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result   : Files.Controller.Controller_Result;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Files.Model.Focus_Filter_Input (Model);
      Files.Controller.Testing.Replace_Focused_Text (Model, Hebrew);
      Files.Model.Set_Text_Cursor_Position (Model, 0);
      Result := Files.Controller.Testing.Handle_Key (Model, Settings, Guikit.Input.Key_Left);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model), 2, "Left from the right edge passes alef, reading on");
      Result := Files.Controller.Testing.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model), 0, "Right goes back to the right edge");
      Result := Files.Controller.Testing.Handle_Key (Model, Settings, Guikit.Input.Key_Right);
      Files_Suite.Support.Assert_Equal
        (Result.Status, Files.Controller.Controller_Ignored, "nothing lies right of the right edge");

      Files.Controller.Testing.Replace_Focused_Text (Model, U8 ("אב גא"));
      Files.Model.Set_Text_Cursor_Position (Model, 0);
      Result := Files.Controller.Testing.Handle_Key (Model, Settings, Guikit.Input.Key_Left, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model), 4, "Control+Left reads on to the end of the first word");
      Result := Files.Controller.Testing.Handle_Key (Model, Settings, Guikit.Input.Key_Right, Ctrl);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model), 0, "Control+Right reads back");

      --  Every caret of a multi-rename steps the same way.
      declare
         Items : Files.Items.Item_Vectors.Vector;
         Homed : Boolean;
         pragma Unreferenced (Homed);
         Moved : Boolean;
      begin
         Items.Append (Files.Item_Lists.Make_Item
                         (Files_Suite.Support.Disk.Root, Hebrew & ".txt", Files.Types.Regular_File_Item,
                          "text/plain"));
         Items.Append (Files.Item_Lists.Make_Item
                         (Files_Suite.Support.Disk.Root, U8 ("גבא.txt"), Files.Types.Regular_File_Item,
                          "text/plain"));
         Files.Model.Initialize (Model, Files_Suite.Support.Disk.Root, Items, Files_Suite.Support.Disk.Root);
         Files.Model.Selection.Select_All_Visible (Model);
         Files.Model.Rename.Toggle (Model);
         Homed := Files.Model.Rename.Set_All_Carets_Home (Model);
         Assert (Files.Model.Rename.Move_All_Carets (Model, Guikit.Input.Move_Left), "Left moves the carets");
         Moved := Files.Model.Rename.Delete (Model, Backward => True);
         Assert (Moved, "Backspace after Left deletes");
         Assert
           (To_String (Files.Model.Rename.Targets (Model) (1).New_Name) = U8 ("בג.txt")
              and then To_String (Files.Model.Rename.Targets (Model) (2).New_Name) = U8 ("בא.txt"),
            "Left from the start passed each name's first letter");
      end;
   end Test_Arrow_Keys_Follow_Drawn_Text;
