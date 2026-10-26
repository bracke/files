with Files.Commands.Status;
separate (Files_Suite.Interaction)
   procedure Test_Item_Menu_Contents_And_Enablement (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "menu-contents");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "report.txt"), "payload");

      Model := Loaded_Model (Dir);
      Files_Suite.Support.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Assert (Files.Model.Context_Menu_Is_Open (Model), "the item menu opens on the selected file");

      --  Every item-context command the layout promises is present (rule a).
      Assert (Menu_Offers (Model, Settings, Files.Commands.Open_Selected_Items_Command),
              "the item menu lists Open");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Open_With_Command),
              "the item menu lists Open With");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Toggle_Favorite_Command),
              "the item menu lists Toggle Favorite");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Set_Color_Label_Command),
              "the item menu lists Set Color Label");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Copy_Selected_Items_Command),
              "the item menu lists Copy");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Cut_Selected_Items_Command),
              "the item menu lists Cut");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Copy_To_Command),
              "the item menu lists Copy to");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Move_To_Command),
              "the item menu lists Move to");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Duplicate_Selected_Command),
              "the item menu lists Duplicate");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Create_Symlink_Command),
              "the item menu lists Create Symlink");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Create_Hardlink_Command),
              "the item menu lists Create Hardlink");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Rename_Selected_Items_Command),
              "the item menu lists Rename");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Delete_Selected_Items_Command),
              "the item menu lists Delete");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Compress_Zip_Command),
              "the item menu lists Compress Zip");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Compress_7z_Command),
              "the item menu lists Compress 7z");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Extract_Archive_Command),
              "the item menu lists Extract");
      Assert (Menu_Offers (Model, Settings, Files.Commands.Restore_From_Trash_Command),
              "the item menu lists Restore From Trash");

      --  Selection-driven enablement (rule b: semantic Is_Enabled, not geometry).
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Copy_Selected_Items_Command, Model),
              "Copy is enabled with a selection");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Cut_Selected_Items_Command, Model),
              "Cut is enabled with a selection");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Duplicate_Selected_Command, Model),
              "Duplicate is enabled with a selection");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Copy_To_Command, Model),
              "Copy to is enabled with a selection");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Move_To_Command, Model),
              "Move to is enabled with a selection");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Create_Symlink_Command, Model),
              "Create Symlink is enabled with a selection");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Create_Hardlink_Command, Model),
              "Create Hardlink is enabled with a selection");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Compress_Zip_Command, Model),
              "Compress Zip is enabled with a selection");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Compress_7z_Command, Model),
              "Compress 7z is enabled with a selection");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Open_With_Command, Model),
              "Open With is enabled with a selection");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Open_Selected_Items_Command, Model),
              "Open is enabled with a selection");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Delete_Selected_Items_Command, Model),
              "Delete is enabled with a selection");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Rename_Selected_Items_Command, Model),
              "Rename is enabled for a single real selection");
      Assert (Files.Commands.Status.Is_Enabled (Files.Commands.Set_Color_Label_Command, Model),
              "Set Color Label is enabled with a selection");

      --  Context-sensitive commands are present but disabled in a normal
      --  directory on a plain file: Extract needs an archive, Restore needs trash.
      Assert (not Files.Commands.Status.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
              "Extract is disabled on a non-archive selection");
      Assert (not Files.Commands.Status.Is_Enabled (Files.Commands.Restore_From_Trash_Command, Model),
              "Restore From Trash is disabled outside the trash directory");

      --  Enter on Copy to belongs to the context menu that was open at the
      --  start of dispatch. It opens the destination picker, but the newly
      --  opened picker must not consume that same Enter and confirm immediately.
      declare
         Rows : constant Files.Commands.Context_Menu_Rows :=
           Files.Commands.Context_Menu_Rows_For
             (Files.Model.Context_Menu_Target_Of (Model));
         Copy_To_Row : Natural := 0;
      begin
         for Row in 1 .. Rows.Count loop
            if Rows.Rows (Row).Command = Files.Commands.Copy_To_Command then
               Copy_To_Row := Row;
               exit;
            end if;
         end loop;
         Assert (Copy_To_Row > 0, "the live item menu has a Copy to row for keyboard dispatch");
         Files.Model.Set_Context_Menu_Highlight (Model, Copy_To_Row);
         Files.Interaction.Handle_Key
           (Model, Settings, "", Guikit.Input.Key_Return,
            Guikit.Input.No_Modifiers, Base_Font, Result);
      end;
      Assert
        (not Files.Model.Context_Menu_Is_Open (Model),
         "context-menu Enter opens Copy to without immediately confirming it (menu closed)");
      Assert
        (Files.Model.Tree_Pick_Is_Active (Model),
         "context-menu Enter opens Copy to without immediately confirming it (tree pick active)");
      Assert
        (Files.Model.Tree_Panel_Is_Open (Model),
         "context-menu Enter opens Copy to without immediately confirming it (tree panel open)");
      Assert
        (not Files.Model.Paste_Conflict_Is_Active (Model)
         and then not Files.Model.Paste_Execution_Is_Active (Model),
         "the newly opened picker does not start a transfer from the same Enter");
   end Test_Item_Menu_Contents_And_Enablement;
