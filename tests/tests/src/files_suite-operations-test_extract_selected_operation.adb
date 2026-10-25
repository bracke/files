separate (Files_Suite.Operations)
   procedure Test_Extract_Selected_Operation (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Zlib.Status_Code;
      Settings        : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Dir             : constant String := Join (Root, "extract");
      Source_Report   : constant String := Join (Dir, "report.txt");
      Source_Notes    : constant String := Join (Dir, "notes.txt");
      Archive_Path    : constant String := Join (Dir, "bundle.zip");
      Dest_Dir        : constant String := Join (Dir, "bundle");
      Out_Report      : constant String := Join (Dest_Dir, "report.txt");
      Out_Notes       : constant String := Join (Dest_Dir, "notes.txt");
      Report_Payload  : constant String := "first extraction payload";
      Notes_Payload   : constant String := "second extraction payload";
      Inputs          : Zlib.Text_Array (1 .. 2);
      Names           : Zlib.Text_Array (1 .. 2);
      Build_Status    : Zlib.Status_Code;
      Load            : Files.File_System.Directory_Load_Result;
      Model           : Files.Model.Window_Model;
      Routed          : Files.Controller.Controller_Result;
      Catalogue       : Zlib.Archive_Entry_Array (1 .. 2);
   begin
      Reset_Root;

      Catalogue (1).Name := To_Unbounded_String ("report.txt");
      Catalogue (1).Uncompressed_Size := 10;
      Catalogue (1).Compressed_Size := 10;
      Catalogue (2).Name := To_Unbounded_String ("notes.txt");
      Catalogue (2).Uncompressed_Size := 20;
      Catalogue (2).Compressed_Size := 20;
      Assert
        (Files.Archive_Writing.Extraction_Is_Within_Limits
           (Catalogue, 1_000, True, 100, True),
         "a small archive fits within known destination resources");
      Catalogue (1).Name := To_Unbounded_String ("../report.txt");
      Assert
        (not Files.Archive_Writing.Extraction_Is_Within_Limits
           (Catalogue, 1_000, True, 100, True),
         "archive traversal names are rejected before extraction");
      Catalogue (1).Name := To_Unbounded_String ("report.txt");
      Catalogue (2).Name := To_Unbounded_String ("report.txt");
      Assert
        (not Files.Archive_Writing.Extraction_Is_Within_Limits
           (Catalogue, 1_000, True, 100, True),
         "duplicate archive names are rejected before extraction");
      Catalogue (1).Name := To_Unbounded_String ("docs/");
      Catalogue (2).Name := To_Unbounded_String ("docs/");
      Assert
        (Files.Archive_Writing.Extraction_Is_Within_Limits
           (Catalogue, 1_000, True, 100, True),
         "a repeated directory entry does not block extraction");
      Catalogue (1).Name := To_Unbounded_String ("report.txt");
      Catalogue (2).Name := To_Unbounded_String ("notes.txt");
      Assert
        (not Files.Archive_Writing.Extraction_Is_Within_Limits
           (Catalogue, 25, True, 100, True),
         "archive extraction preserves free-space headroom");
      Assert
        (not Files.Archive_Writing.Extraction_Is_Within_Limits
           (Catalogue, 1_000, True, 1, True),
         "archive extraction cannot exhaust destination inodes");
      Catalogue (1).Uncompressed_Size := Interfaces.Unsigned_64'Last;
      Catalogue (2).Uncompressed_Size := 1;
      Assert
        (not Files.Archive_Writing.Extraction_Is_Within_Limits
           (Catalogue, 0, False, 0, False),
         "overflowing archive totals are rejected before extraction");
      Catalogue (1).Uncompressed_Size := 1;
      Catalogue (1).Compressed_Size := Interfaces.Unsigned_64'Last;
      Catalogue (2).Uncompressed_Size := 1;
      Catalogue (2).Compressed_Size := 0;
      Assert
        (Files.Archive_Writing.Extraction_Is_Within_Limits
           (Catalogue, 1_000, True, 100, True),
         "expansion-limit arithmetic saturates instead of overflowing");

      --  Name checks, per destination: every unsafe shape is refused, a
      --  DOS-rules volume refuses names Windows cannot store, and on a
      --  case-insensitive one names differing only in case collide.
      declare
         One : Zlib.Archive_Entry_Array (1 .. 1);
         function Extractable (Name : String; Dos : Boolean := False; Folded : Boolean := False) return Boolean is
         begin
            One (1).Name := To_Unbounded_String (Name);
            return Files.Archive_Writing.Names_Are_Extractable (One, Dos, Folded);
         end Extractable;
      begin
         for Unsafe of Files.Types.String_Vectors.Vector'
           ([To_Unbounded_String ("/etc/passwd"), To_Unbounded_String ("a/../../x"),
             To_Unbounded_String ("a\b"), To_Unbounded_String ("C:x"), To_Unbounded_String (".."),
             To_Unbounded_String ("./"), To_Unbounded_String ("a//b"), To_Unbounded_String ("")])
         loop
            Assert (not Extractable (To_String (Unsafe)), "unsafe archive name refused: " & To_String (Unsafe));
         end loop;
         Assert (Extractable ("dir/nul.txt") and then Extractable ("aux.c"),
                 "a POSIX destination stores Windows device names");
         for Unstorable of Files.Types.String_Vectors.Vector'
           ([To_Unbounded_String ("dir/nul.txt"), To_Unbounded_String ("aux.c"),
             To_Unbounded_String ("notes."), To_Unbounded_String ("a?b")])
         loop
            Assert (not Extractable (To_String (Unstorable), Dos => True),
                    "a DOS-rules destination refuses names Windows cannot store: " & To_String (Unstorable));
         end loop;
         Assert (Extractable ("dir/report.txt", Dos => True), "an ordinary name is fine on a DOS volume");
      end;
      Catalogue (1).Name := To_Unbounded_String ("Makefile");
      Catalogue (2).Name := To_Unbounded_String ("makefile");
      Assert (Files.Archive_Writing.Names_Are_Extractable (Catalogue, False, Case_Insensitive => False),
              "names differing in case are distinct on a case-sensitive volume");
      Assert (not Files.Archive_Writing.Names_Are_Extractable (Catalogue, False, Case_Insensitive => True),
              "names differing only in case collide on a case-insensitive volume");

      Ada.Directories.Create_Path (Dir);
      Write_File (Source_Report, Report_Payload);
      Write_File (Source_Notes, Notes_Payload);

      --  Build a real ZIP archive holding both files next to the originals.
      Inputs (1) := To_Unbounded_String (Source_Report);
      Inputs (2) := To_Unbounded_String (Source_Notes);
      Names (1) := To_Unbounded_String ("report.txt");
      Names (2) := To_Unbounded_String ("notes.txt");
      Zlib.ZIP_Files (Inputs, Archive_Path, Names, Status => Build_Status);
      Assert (Build_Status = Zlib.Ok, "test archive is created");

      Load := Files.File_System.Load_Directory (Dir, Settings);
      Files.Model.Initialize (Model, Dir, Load.Items, Root);
      Select_Name (Model, "bundle.zip");

      Assert
        (Files.Commands.Is_Enabled (Files.Commands.Extract_Archive_Command, Model),
         "extract command is enabled when an archive is selected");

      Routed := Files.Controller.Execute_Command (Files.Commands.Extract_Archive_Command, Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Routed.Operation.Status,
         Files.Operations.Operation_Success,
         "extract succeeds");
      Assert (Ada.Directories.Exists (Dest_Dir), "destination folder is created from the archive base name");
      Assert (Ada.Directories.Exists (Out_Report), "first archived file is extracted");
      Assert (Ada.Directories.Exists (Out_Notes), "second archived file is extracted");
      Files_Suite.Support.Assert_Equal
        (Project_Tools.Files.Read_Raw_File (Out_Report),
         Project_Tools.Files.Read_Raw_File (Source_Report),
         "first extracted file matches the original contents");
      Files_Suite.Support.Assert_Equal
        (Project_Tools.Files.Read_Raw_File (Out_Notes),
         Project_Tools.Files.Read_Raw_File (Source_Notes),
         "second extracted file matches the original contents");

      Select_Name (Model, "bundle.zip");
      Files.File_Identities.Testing.Set_Unavailable (True);
      begin
         Routed := Files.Controller.Execute_Command
           (Files.Commands.Extract_Archive_Command, Model, Settings);
         Files.File_Identities.Testing.Set_Unavailable (False);
      exception
         when others =>
            Files.File_Identities.Testing.Set_Unavailable (False);
            raise;
      end;
      Assert
        (Routed.Operation.Status = Files.Operations.Operation_Failed
         and then not Ada.Directories.Exists (Join (Dir, "bundle (1)")),
         "extraction does not publish a tree without a verifiable identity");
   end Test_Extract_Selected_Operation;
