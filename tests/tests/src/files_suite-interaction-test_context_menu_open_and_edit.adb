separate (Files_Suite.Interaction)
   procedure Test_Context_Menu_Open_And_Edit (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
   begin
      --  Open on a directory navigates into it.
      declare
         Dir   : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "open-nav");
         Items : Files.File_System.Item_Vectors.Vector;
         Model : Files.Model.Window_Model;
      begin
         Files_Suite.Support.Reset_Root;
         Ada.Directories.Create_Path (Dir);
         Files_Suite.Support.Write_File (Files_Suite.Support.Join (Dir, "inside.txt"));
         Items.Append
           (Files.File_System.Make_Item
              (Files_Suite.Support.Root, "open-nav", Files.Types.Directory_Item, "inode/directory"));
         Files.Model.Initialize (Model, Files_Suite.Support.Root, Items, Files_Suite.Support.Root);
         Files.Model.Select_Visible (Model, 1);

         Open_Item_Context_Menu (Model, Settings, Result);
         Dispatch_Menu_Command
           (Model, Settings, "", Files.Commands.Open_Selected_Items_Command, Result, Found);
         Assert (Found, "the item menu offers the open command");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Current_Path (Model),
            Dir,
            "opening a directory navigates into it");
         Assert (not Files.Model.Context_Menu_Is_Open (Model), "dispatching a menu row closes the menu");
      end;

      --  Rename, Cut, and Duplicate on a real file, each from a fresh model.
      declare
         Dir       : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "edit-ops");
         Source    : constant String := Files_Suite.Support.Join (Dir, "report.txt");
         Copy_Path : constant String := Files_Suite.Support.Join (Dir, "report (copy).txt");
         Model     : Files.Model.Window_Model;
      begin
         Files_Suite.Support.Reset_Root;
         Ada.Directories.Create_Path (Dir);
         Files_Suite.Support.Write_File (Source, "payload");

         Model := Loaded_Model (Dir);
         Files_Suite.Support.Select_Name (Model, "report.txt");
         Open_Item_Context_Menu (Model, Settings, Result);
         Dispatch_Menu_Command
           (Model, Settings, "", Files.Commands.Rename_Selected_Items_Command, Result, Found);
         Assert (Found, "the item menu offers the rename command");
         Assert (Files.Model.Rename_Is_Active (Model), "rename starts inline editing of the selection");

         Model := Loaded_Model (Dir);
         Files_Suite.Support.Select_Name (Model, "report.txt");
         Open_Item_Context_Menu (Model, Settings, Result);
         Dispatch_Menu_Command
           (Model, Settings, "", Files.Commands.Cut_Selected_Items_Command, Result, Found);
         Assert (Found, "the item menu offers the cut command");
         Files_Suite.Support.Assert_Equal
           (Result.Command,
            Files.Commands.Cut_Selected_Items_Command,
            "the result echoes the cut command");
         Assert
           (Files.Model.Clipboard_Mode_Of (Model) = Files.Model.Clipboard_Cut,
            "cut records a cut clipboard intent");
         Assert (Files.Model.Clipboard_Has_Items (Model), "cut captures the selected item");

         Model := Loaded_Model (Dir);
         Files_Suite.Support.Select_Name (Model, "report.txt");
         Open_Item_Context_Menu (Model, Settings, Result);
         Dispatch_Menu_Command
           (Model, Settings, "", Files.Commands.Duplicate_Selected_Command, Result, Found);
         Assert (Found, "the item menu offers the duplicate command");
         Assert (Ada.Directories.Exists (Source), "duplicate keeps the original file");
         Assert (Ada.Directories.Exists (Copy_Path), "duplicate writes a uniquely named copy");
      end;
   end Test_Context_Menu_Open_And_Edit;
