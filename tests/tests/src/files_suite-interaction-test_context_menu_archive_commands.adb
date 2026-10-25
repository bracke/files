separate (Files_Suite.Interaction)
   procedure Test_Context_Menu_Archive_Commands (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Interaction.Interaction_Result;
      Found    : Boolean;
      Dir      : constant String := Files_Suite.Support.Join (Files_Suite.Support.Root, "archive-ops");
      Report   : constant String := Files_Suite.Support.Join (Dir, "report.txt");
      Notes    : constant String := Files_Suite.Support.Join (Dir, "notes.txt");
      Zip_Path : constant String := Files_Suite.Support.Join (Dir, "report.zip");
      Sz_Path  : constant String := Files_Suite.Support.Join (Dir, "report.7z");
      Model    : Files.Model.Window_Model;
   begin
      Files_Suite.Support.Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Files_Suite.Support.Write_File (Report, "first payload");
      Files_Suite.Support.Write_File (Notes, "second payload");

      Model := Loaded_Model (Dir);
      Files_Suite.Support.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command (Model, Settings, "", Files.Commands.Compress_Zip_Command, Result, Found);
      Assert (Found, "the item menu offers the compress-zip command");
      Files_Suite.Support.Assert_Equal
        (Result.Command,
         Files.Commands.Compress_Zip_Command,
         "the result echoes the compress-zip command");
      Assert (Ada.Directories.Exists (Zip_Path), "compress-zip writes a zip archive next to the item");

      Model := Loaded_Model (Dir);
      Files_Suite.Support.Select_Name (Model, "report.txt");
      Open_Item_Context_Menu (Model, Settings, Result);
      Dispatch_Menu_Command (Model, Settings, "", Files.Commands.Compress_7z_Command, Result, Found);
      Assert (Found, "the item menu offers the compress-7z command");
      Assert (Ada.Directories.Exists (Sz_Path), "compress-7z writes a 7z archive next to the item");

      --  Extract a real archive built next to the originals.
      declare
         use type Zlib.Status_Code;
         Bundle : constant String := Files_Suite.Support.Join (Dir, "bundle.zip");
         Dest   : constant String := Files_Suite.Support.Join (Dir, "bundle");
         Inputs : Zlib.Text_Array (1 .. 2);
         Names  : Zlib.Text_Array (1 .. 2);
         Status : Zlib.Status_Code;
      begin
         Inputs (1) := Ada.Strings.Unbounded.To_Unbounded_String (Report);
         Inputs (2) := Ada.Strings.Unbounded.To_Unbounded_String (Notes);
         Names (1) := Ada.Strings.Unbounded.To_Unbounded_String ("report.txt");
         Names (2) := Ada.Strings.Unbounded.To_Unbounded_String ("notes.txt");
         Zlib.ZIP_Files (Inputs, Bundle, Names, Status => Status);
         Assert (Status = Zlib.Ok, "the test archive is created for extraction");

         Model := Loaded_Model (Dir);
         Files_Suite.Support.Select_Name (Model, "bundle.zip");
         Open_Item_Context_Menu (Model, Settings, Result);
         Dispatch_Menu_Command (Model, Settings, "", Files.Commands.Extract_Archive_Command, Result, Found);
         Assert (Found, "the item menu offers the extract command");
         Assert (Ada.Directories.Exists (Dest), "extract creates a folder from the archive base name");
         Assert
           (Ada.Directories.Exists (Files_Suite.Support.Join (Dest, "report.txt")),
            "extract writes the archived entries into the new folder");
      end;
   end Test_Context_Menu_Archive_Commands;
