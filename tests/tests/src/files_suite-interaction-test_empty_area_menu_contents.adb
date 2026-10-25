separate (Files_Suite.Interaction)
   procedure Test_Empty_Area_Menu_Contents (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "empty-contents");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Model := Loaded_Model (Dir);

      Open_Empty_Context_Menu (Model, Settings, Result);
      Assert (Files.Model.Context_Menu_Is_Open (Model), "the empty-area menu opens on empty space");

      Assert (Menu_Offers (Model, Settings, Files.Commands.Create_File_Command),
              "the empty-area menu lists Create File");
      Assert (Menu_Offers (Model, Settings, Files.Commands.New_Folder_Command),
              "the empty-area menu lists New Folder");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Paste_Items_Command),
              "the empty-area menu lists Paste");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Open_Terminal_Command),
              "the empty-area menu lists Open Terminal");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Refresh_Directory_Command),
              "the empty-area menu lists Refresh");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Empty_Trash_Command),
              "the empty-area menu lists Empty Trash");

      --  The item-only commands must not leak into the empty-area menu.
      Assert (not Menu_Offers (Model, Settings, Files.Commands.Open_Selected_Items_Command),
              "the empty-area menu omits Open");
      Assert (not Menu_Offers (Model, Settings, Files.Commands.Copy_Selected_Items_Command),
              "the empty-area menu omits Copy");
      Assert (not Menu_Offers (Model, Settings, Files.Commands.Cut_Selected_Items_Command),
              "the empty-area menu omits Cut");
      Assert (not Menu_Offers (Model, Settings, Files.Commands.Delete_Selected_Items_Command),
              "the empty-area menu omits Delete");
      Assert (not Menu_Offers (Model, Settings, Files.Commands.Rename_Selected_Items_Command),
              "the empty-area menu omits Rename");
      Assert (not Menu_Offers (Model, Settings, Files.Commands.Extract_Archive_Command),
              "the empty-area menu omits Extract");
   end Test_Empty_Area_Menu_Contents;
