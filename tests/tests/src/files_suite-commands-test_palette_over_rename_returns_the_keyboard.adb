with Files.Controller.Testing;
with Files.Model.Command_Palette;
separate (Files_Suite.Commands)
   --  F2, a name typed, Control+P, Escape: the rename the palette was opened
   --  over gets the keyboard back, so Return commits the name instead of
   --  opening the item, and a pending New File row is handed back the same.
   procedure Test_Palette_Over_Rename_Returns_The_Keyboard (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Result   : Files.Controller.Controller_Result with Unreferenced;
      Ctrl     : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
   begin
      Ctrl (Guikit.Input.Control_Key) := True;
      Reset_Root;
      Write_File (Join (Root, "old.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "old.txt");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_F2);
      Files.Controller.Testing.Replace_Focused_Text (Model, "new_na");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_P, Ctrl);
      Assert (Files.Model.Command_Palette.Is_Open (Model), "Control+P opens the palette over the rename");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Assert (not Files.Model.Command_Palette.Is_Open (Model), "Escape closes the palette");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model), Files.UI_Types.Focus_Rename_Input, "the rename has the keyboard again");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Text_Cursor_Position (Model), 6, "its caret is where the typing left it");
      Result := Files.Controller.Append_Focused_Text (Model, "me.txt");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Rename.Text (Model), "new_name.txt", "typing goes on into the rename");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Return);
      Assert (not Files.Model.Rename.Is_Active (Model), "Return ends the rename");
      Assert (Ada.Directories.Exists (Join (Root, "new_name.txt")), "Return commits the typed name");
      Assert (not Ada.Directories.Exists (Join (Root, "old.txt")), "the old name is gone");

      --  A New File row waiting for its name is handed back the same way.
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_N, Ctrl);
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "Control+N starts a new file row");
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_P, Ctrl);
      Result := Files.Controller.Handle_Key (Model, Settings, Guikit.Input.Key_Escape);
      Files_Suite.Support.Assert_Equal
        (Files.Model.Focus (Model), Files.UI_Types.Focus_Rename_Input, "the new file row has the keyboard again");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "and is still pending");
   end Test_Palette_Over_Rename_Returns_The_Keyboard;
