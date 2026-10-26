with Files.Commands.Status;
separate (Files_Suite.Commands)
   procedure Test_Open_Containing_Folder_Command (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Sub      : constant String := Join (Root, "sub");
      Items    : Files.File_System.Item_Vectors.Vector;
      Model    : Files.Model.Window_Model;
      Result   : Files.Controller.Controller_Result;
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Sub);
      Write_File (Join (Sub, "found.txt"));

      --  A recursive-search-style model: the current directory is Root, but the
      --  single result item lives in Root/sub.
      Items.Append (Files.File_System.Make_Item (Sub, "found.txt", Files.Types.Regular_File_Item, "text/plain"));
      Files.Model.Initialize (Model, Root, Items, Root);

      --  Disabled without a selection, enabled with a single result selected.
      Assert
        (not Files.Commands.Status.Is_Enabled (Files.Commands.Open_Containing_Folder_Command, Model),
         "reveal is disabled with no selection");
      Select_Name (Model, "found.txt");
      Assert
        (Files.Commands.Status.Is_Enabled (Files.Commands.Open_Containing_Folder_Command, Model),
         "reveal is enabled for a single selected result");

      Result :=
        Files.Controller.Execute_Command (Files.Commands.Open_Containing_Folder_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Open_Containing_Folder_Command,
         "reveal reports its command");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Current_Path (Model),
         Ada.Directories.Full_Name (Sub),
         "reveal navigates to the item's containing folder");
      Assert
        (Files.Model.Selected_Count (Model) = 1
           and then To_String (Files.Model.Selected_Items (Model).First_Element.Name) = "found.txt",
         "reveal selects the item in its containing folder");
   end Test_Open_Containing_Folder_Command;
