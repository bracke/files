separate (Files_Suite.Commands)
   procedure Test_Multi_Rename_Multibyte_Edits (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function U8 (Text : Wide_Wide_String) return String is
        (Ada.Strings.UTF_Encoding.Wide_Wide_Strings.Encode (Text));
      Items : Files.File_System.Item_Vectors.Vector;
      Model : Files.Model.Window_Model;
      Moved : Boolean;
      pragma Unreferenced (Moved);

      function Name (Row : Positive) return String is
        (To_String (Files.Model.Rename_Targets (Model) (Row).New_Name));

      function All_Valid return Boolean is
        (for all Target of Files.Model.Rename_Targets (Model) => Files.UTF8.Is_Valid (To_String (Target.New_Name)));
   begin
      Items.Append (Files.File_System.Make_Item
                      (Files_Suite.Support.Root, U8 ("café über.txt"), Files.Types.Regular_File_Item, "text/plain"));
      Items.Append (Files.File_System.Make_Item
                      (Files_Suite.Support.Root, U8 ("naïve ölig.txt"), Files.Types.Regular_File_Item, "text/plain"));
      Files.Model.Initialize (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root);
      Files.Model.Select_All_Visible (Model);
      Files.Model.Toggle_Rename (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename_Field_Count (Model),
         2,
         "both selected names are being renamed");

      Moved := Files.Model.Rename_Set_All_Carets_Home (Model);
      Assert (Files.Model.Rename_Delete_Forward (Model), "Delete removes one letter (a field changed)");
      Assert (Name (1) = U8 ("afé über.txt") and then Name (2) = U8 ("aïve ölig.txt"), "Delete removes one letter");
      Assert
        (Files.Model.Rename_Move_All_Carets (Model, Guikit.Input.Move_Right),
         "Delete after a multibyte letter takes the whole next letter (first caret move)");
      Assert
        (Files.Model.Rename_Move_All_Carets (Model, Guikit.Input.Move_Right),
         "Delete after a multibyte letter takes the whole next letter (second caret move)");
      Assert
        (Files.Model.Rename_Delete_Forward (Model),
         "Delete after a multibyte letter takes the whole next letter (a field changed)");
      Assert (Name (1) = U8 ("af über.txt") and then Name (2) = U8 ("aïe ölig.txt"),
              "Delete after a multibyte letter takes the whole next letter");
      Assert
        (Files.Model.Rename_Delete_Backward (Model),
         "Backspace takes the whole multibyte letter before the caret (a field changed)");
      Assert (Name (1) = U8 ("a über.txt") and then Name (2) = U8 ("ae ölig.txt"),
              "Backspace takes the whole multibyte letter before the caret");

      Moved := Files.Model.Rename_Set_All_Carets_Home (Model);
      Assert
        (Files.Model.Rename_Delete_Word_Forward (Model),
         "Ctrl+Delete removes the first word and leaves the next one whole (a field changed)");
      Assert (All_Valid, "Ctrl+Delete removes the first word and leaves the next one whole (valid UTF-8)");
      Assert
        (Ada.Strings.Fixed.Index (Name (1), U8 ("über")) > 0,
         "Ctrl+Delete removes the first word and leaves the next one whole (first name)");
      Assert
        (Ada.Strings.Fixed.Index (Name (2), U8 ("ölig")) > 0,
         "Ctrl+Delete removes the first word and leaves the next one whole (second name)");
      Moved := Files.Model.Rename_Set_All_Carets_End (Model);
      Assert
        (Files.Model.Rename_Delete_Word_Backward (Model),
         "Ctrl+Backspace leaves every name valid UTF-8 (a field changed)");
      Assert (All_Valid, "Ctrl+Backspace leaves every name valid UTF-8");
   end Test_Multi_Rename_Multibyte_Edits;
