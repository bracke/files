separate (Files_Suite.Operations)
   procedure Test_Compress_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir      : constant String := Join (Root, "compress");
      Zip_Path : constant String := Join (Dir, "report.zip");
      Sz_Path  : constant String := Join (Dir, "report.7z");
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Routed   : Files.Controller.Controller_Result;

      function First_Bytes (Path : String; Count : Positive) return String is
         Raw : constant String := Project_Tools.Files.Read_Raw_File (Path);
      begin
         if Raw'Length < Count then
            return Raw;
         end if;
         return Raw (Raw'First .. Raw'First + Count - 1);
      end First_Bytes;

      Zip_Magic : constant String :=
        "PK" & Character'Val (3) & Character'Val (4);
      Sz_Magic  : constant String :=
        Character'Val (16#37#) & Character'Val (16#7A#) & Character'Val (16#BC#)
        & Character'Val (16#AF#) & Character'Val (16#27#) & Character'Val (16#1C#);
   begin
      Reset_Root;
      Ada.Directories.Create_Path (Dir);
      Write_File (Join (Dir, "report.txt"), "hello compression payload");
      Write_File (Join (Dir, "notes.txt"), "second file payload");

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "report.txt");

      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Compress_Zip_Command, Model),
         "compress-zip command is enabled with a selection");

      Routed := Files.Controller.Execute_Command (Files.Commands.Compress_Zip_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "compress to zip succeeds");
      Assert (Ada.Directories.Exists (Zip_Path), "zip archive is created next to the first item");
      Files_Suite.Support.Assert_Equal
        (First_Bytes (Zip_Path, 4),
         Zip_Magic,
         "zip archive begins with the ZIP local-header signature");

      Select_Name (Model, "report.txt");
      Routed := Files.Controller.Execute_Command (Files.Commands.Compress_7z_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "compress to 7z succeeds");
      Assert (Ada.Directories.Exists (Sz_Path), "7z archive is created next to the first item");
      Files_Suite.Support.Assert_Equal (First_Bytes (Sz_Path, 6), Sz_Magic, "7z archive begins with the 7z signature");

      Select_Name (Model, "notes.txt");
      Files.File_Identities.Testing.Set_Unavailable (True);
      begin
         Routed := Files.Controller.Execute_Command
           (Files.Commands.Compress_Zip_Command, Model, Settings);
         Files.File_Identities.Testing.Set_Unavailable (False);
      exception
         when others =>
            Files.File_Identities.Testing.Set_Unavailable (False);
            raise;
      end;
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Failed
         and then not Ada.Directories.Exists (Join (Dir, "notes.zip")),
         "compression does not publish an archive without a verifiable identity");
   end Test_Compress_Selected_Operation;
