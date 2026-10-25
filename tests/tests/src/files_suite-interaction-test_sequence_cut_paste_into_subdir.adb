separate (Files_Suite.Interaction)
   procedure Test_Sequence_Cut_Paste_Into_Subdir (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Src_Dir  : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "cut-seq");
      Sub      : constant String := Files_Suite.Support.Join (Src_Dir, "sub");
      Source   : constant String := Files_Suite.Support.Join (Src_Dir, "movable.txt");
      Pasted   : constant String := Files_Suite.Support.Join (Sub, "movable.txt");
      Model    : Files.Model.Window_Model;
      Load     : Files.File_System.Directory_Load_Result;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Sub);
      Files_Suite.Support.Write_File (Source, "payload");

      --  Step 1: cut a file from the source directory.
      Model := Loaded_Model (Src_Dir);
      Files_Suite.Support.Select_Name (Model, "movable.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command
        (Model, Settings, "", Files.Commands.Cut_Selected_Items_Command, Result, Found);
      Assert (Found, "the item menu offers the cut command");
      Assert
        (Files.Model.Clipboard_Mode_Of (Model) = Files.Model.Clipboard_Cut,
         "cut records a cut clipboard intent");

      --  Step 2: navigate into the subdirectory and paste via the empty-area menu.
      Load := Files.File_System.Load_Directory (Sub, Settings);
      Files.Model.Navigate_To (Model, Sub, Load.Items);
      Open_Empty_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command (Model, Settings, "", Files.Commands.Paste_Items_Command, Result, Found);
      Assert (Found, "the empty-area menu offers the paste command");
      Assert (Ada.Directories.Exists (Pasted), "paste moves the cut file into the subdirectory");
      Assert (not Ada.Directories.Exists (Source), "a cut paste removes the file from its origin");

      --  Step 3: if the move is undoable, undo returns the file to its origin.
      if Files.Model.Undo_Available (Model) then
         Dispatch_Command (Model, Settings, Files.Commands.Undo_Command, Result);
         Assert (Ada.Directories.Exists (Source), "undo moves the cut file back to its origin");
         Assert (not Ada.Directories.Exists (Pasted), "undo removes the file from the subdirectory");
      end if;
   end Test_Sequence_Cut_Paste_Into_Subdir;
