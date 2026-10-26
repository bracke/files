with Files.Commands.Status;
separate (Files_Suite.Interaction)
   procedure Test_Paste_Enablement_Reflects_Clipboard (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "paste-enable");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "a.txt"), "payload");
      Model := Loaded_Model (Dir);

      --  No clipboard yet: Paste is listed in the empty-area menu but disabled.
      Open_Empty_Context_Menu (Model, Settings, Result);
      Assert (Menu_Offers (Model, Settings, Files.Commands.Paste_Items_Command),
              "the empty-area menu lists Paste");
      Assert (not Files.Model.Clipboard_Has_Items (Model), "the clipboard starts empty");
      Assert (not Files.Commands.Status.Is_Enabled (Files.Commands.Paste_Items_Command, Model),
              "Paste is disabled before anything is copied");
      Files.Model.Close_Context_Menu (Model);

      --  Copy a file: Paste becomes enabled.
      Files_Suite.Support.Select_Name (Model, "a.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command
        (Model, Settings, "", Files.Commands.Copy_Selected_Items_Command, Result, Found);
      Assert (Found, "the item menu offers the copy command");
      Assert (Files.Model.Clipboard_Has_Items (Model), "copy populates the clipboard");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Paste_Items_Command, Model),
              "Paste is enabled once the clipboard holds items");
   end Test_Paste_Enablement_Reflects_Clipboard;
