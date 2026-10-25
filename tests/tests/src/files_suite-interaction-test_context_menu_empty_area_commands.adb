separate (Files_Suite.Interaction)
   procedure Test_Context_Menu_Empty_Area_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
   begin
      --  New Folder from the empty-area menu activates a temporary directory item.
      declare
         Dir   : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "empty-area");
         Model : Files.Model.Window_Model;
      begin
         Files_Suite.Support.Reset_Root;
         Ada.Directories.Create_Path (Dir);
         Model := Loaded_Model (Dir);

         Open_Empty_Context_Menu (Model, Settings, Result);
         Assert (Files.Model.Context_Menu_Is_Open (Model), "the empty-area menu opens on empty space");
         Dispatch_Menu_Command (Model, Settings, "", Files.Commands.New_Folder_Command, Result, Found);
         Assert (Found, "the empty-area menu offers the new-folder command");
         Assert (Files.Model.Temporary_Item_Is_Active (Model), "new folder activates a temporary item");
         Assert
           (Files.Model.Temporary_Item_Is_Directory (Model),
            "the new-folder temporary item is marked as a directory");
      end;

      --  Paste from the empty-area menu copies a clipboard item into the
      --  navigated-into subdirectory.
      declare
         Src_Dir : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "paste-src");
         Sub     : constant String := Files_Suite.Support.Join (Src_Dir, "sub");
         Model   : Files.Model.Window_Model;
         Load    : Files.File_System.Directory_Load_Result;
      begin
         Files_Suite.Support.Reset_Root;
         Ada.Directories.Create_Path (Sub);
         Files_Suite.Support.Write_File (Files_Suite.Support.Join (Src_Dir, "a.txt"), "payload");

         Model := Loaded_Model (Src_Dir);
         Files_Suite.Support.Select_Name (Model, "a.txt");
         Open_Item_Context_Menu (Model, Settings, Result);
         Dispatch_Menu_Command
           (Model, Settings, "", Files.Commands.Copy_Selected_Items_Command, Result, Found);
         Assert (Found, "the item menu offers the copy command");

         Load := Files.File_System.Load_Directory (Sub, Settings);
         Files.Model.Navigate_To (Model, Sub, Load.Items);
         Open_Empty_Context_Menu (Model, Settings, Result);
         Dispatch_Menu_Command (Model, Settings, "", Files.Commands.Paste_Items_Command, Result, Found);
         Assert (Found, "the empty-area menu offers the paste command");
         Assert
           (Ada.Directories.Exists (Files_Suite.Support.Join (Sub, "a.txt")),
            "paste copies the clipboard item into the current directory");
      end;
   end Test_Context_Menu_Empty_Area_Commands;
