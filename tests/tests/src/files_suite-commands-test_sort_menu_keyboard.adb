separate (Files_Suite.Commands)
   procedure Test_Sort_Menu_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Result   : Files.Controller.Controller_Result;
      pragma Unreferenced (Result);
   begin
      Reset_Root;
      Items.Append (Files.File_System.Make_Item (Root, "a.txt", Files.Types.Regular_File_Item, "text/plain"));
      Files.Model.Initialize (Model, Root, Items, Root);

      --  The menu opens with the highlight on the current field (Name, row 1).
      Files.Model.Toggle_Sort_Menu (Model);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Sort_Menu_Highlight (Model),
         1,
         "the sort menu opens highlighting the current field");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Up);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Sort_Menu_Highlight (Model),
         1,
         "Up at the first row stays clamped");

      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Down);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Sort_Menu_Highlight (Model),
         2,
         "Down moves the highlight to the next row");

      --  Enter applies the highlighted field and closes the menu.
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Assert (not Files.Model.Sort_Menu_Is_Open (Model), "Enter closes the sort menu");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Sort_Field_Of (Model),
         Files.Model.Sort_Size,
         "Enter applies the highlighted sort field");
   end Test_Sort_Menu_Keyboard;
