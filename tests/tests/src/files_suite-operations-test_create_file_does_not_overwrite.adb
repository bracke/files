separate (Files_Suite.Operations)
   procedure Test_Create_File_Does_Not_Overwrite (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result        : Files.Operations.Operation_Result;
      Existing_Path : constant String := Join (Root, "existing.txt");
      Direct_Path   : constant String := Join (Root, "direct-created.txt");
      Utf8_Two_Name   : constant String := "caf" & Byte (16#C3#) & Byte (16#A9#) & ".txt";
      Utf8_Three_Name : constant String := Byte (16#E2#) & Byte (16#82#) & Byte (16#AC#) & "uro.txt";
      Utf8_Four_Name  : constant String :=
        "folder-" & Byte (16#F0#) & Byte (16#9F#) & Byte (16#93#) & Byte (16#81#) & ".txt";
      Mutation      : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      Write_File (Existing_Path, "original");
      Ada.Directories.Create_Path (Join (Root, "existing-dir"));
      Mutation := Files.File_System.Create_Empty_File ("");
      Assert (not Mutation.Success, "create reports empty destination failure");
      Files_Suite.Support.Assert_Equal
        (To_String (Mutation.Error_Key),
         "error.file.parent_missing",
         "empty destination create reports parent diagnostic");
      Mutation := Files.File_System.Create_Empty_File (Join (Root, "existing-dir"));
      Assert (not Mutation.Success, "create refuses an existing directory destination");
      Files_Suite.Support.Assert_Equal
        (To_String (Mutation.Error_Key),
         "error.file.exists",
         "existing directory create reports exists diagnostic");
      Mutation := Files.File_System.Create_Empty_File (Existing_Path);
      Assert (not Mutation.Success, "create refuses an existing file destination");
      Files_Suite.Support.Assert_Equal
        (To_String (Mutation.Error_Key),
         "error.file.exists",
         "existing file create reports exists diagnostic");
      Assert
        (Ada.Strings.Fixed.Index (Project_Tools.Files.Read_Raw_File (Existing_Path), "original") > 0,
         "direct existing-file create preserves file content");
      Mutation := Files.File_System.Create_Empty_File (Join (Join (Root, "missing-parent"), "child.txt"));
      Assert (not Mutation.Success, "create reports missing parent failure");
      Files_Suite.Support.Assert_Equal
        (To_String (Mutation.Error_Key),
         "error.file.parent_missing",
         "missing parent create reports parent diagnostic");
      Assert
        (not Ada.Directories.Exists (Join (Join (Root, "missing-parent"), "child.txt")),
         "missing parent create writes no child file");
      Mutation := Files.File_System.Create_Empty_File (Join (Existing_Path, "child.txt"));
      Assert (not Mutation.Success, "create reports non-directory parent failure");
      Files_Suite.Support.Assert_Equal
        (To_String (Mutation.Error_Key),
         "error.file.parent_missing",
         "non-directory parent create reports parent diagnostic");
      Mutation :=
        Files.File_System.Create_Empty_File (Join (Root, "bad" & Character'Val (9) & "name.txt"));
      Assert (not Mutation.Success, "direct create rejects invalid leaf names");
      Files_Suite.Support.Assert_Equal
        (To_String (Mutation.Error_Key),
         "error.name.invalid",
         "direct invalid-name create reports invalid-name diagnostic");
      Assert
        (not Path_Exists (Join (Root, "bad" & Character'Val (9) & "name.txt")),
         "direct invalid-name create writes no file");
      Mutation := Files.File_System.Create_Empty_File (Direct_Path);
      Assert (Mutation.Success, "direct create mutation succeeds");
      Files_Suite.Support.Assert_Equal
        (To_String (Mutation.Error_Key),
         "",
         "successful direct create has no error key");
      Assert (Ada.Directories.Exists (Direct_Path), "direct create writes the requested file");
      declare
         Original_Content : constant String := Project_Tools.Files.Read_Raw_File (Existing_Path);
      begin
         Load := Files.File_System.Load_Directory (Root, Settings);
         Files.Model.Initialize (Model, Root, Load.Items, Root);
         Files.Model.Begin_Create_File (Model, "existing.txt");

         Result := Files.Operations.Commit_Create_File (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Result.Status,
            Files.Operations.Operation_Failed,
            "create refuses an existing destination");
         Files_Suite.Support.Assert_Equal
           (To_String (Result.Error_Key),
            "error.file.exists",
            "create reports existing file error");
         Files_Suite.Support.Assert_Equal
           (To_String (Result.Path),
            Existing_Path,
            "failed create reports attempted destination path");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Last_Error_Key (Model),
            "error.file.exists",
            "model records existing file error");
         Files_Suite.Support.Assert_Equal
           (Project_Tools.Files.Read_Raw_File (Existing_Path),
            Original_Content,
            "failed create leaves existing file content unchanged");
         Assert (Files.Model.Temporary_Item_Is_Active (Model), "failed create keeps temporary item active");
         Assert (Files.Model.Rename_Is_Active (Model), "failed create keeps rename mode active");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Temporary_Item_Name (Model),
            "existing.txt",
            "failed create keeps attempted name");

         Files.Model.Set_Rename_Text (Model, "retry.txt");
         Result := Files.Operations.Commit_Create_File (Model, Settings);
         Files_Suite.Support.Assert_Equal
           (Result.Status,
            Files.Operations.Operation_Success,
            "create retry after collision succeeds");
         Assert (Ada.Directories.Exists (Join (Root, "retry.txt")), "create retry writes renamed file");
         Files_Suite.Support.Assert_Equal
           (Project_Tools.Files.Read_Raw_File (Existing_Path),
            Original_Content,
            "create retry preserves original existing file");
         Assert (not Files.Model.Temporary_Item_Is_Active (Model), "create retry clears temporary state");
         Files_Suite.Support.Assert_Equal
           (Files.Model.Selected_Name (Model),
            "retry.txt",
            "create retry selects created file");
      end;

      Files.Model.Begin_Create_File (Model, Utf8_Two_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "create accepts two-byte UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, Utf8_Two_Name)), "two-byte UTF-8 create writes file");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         Utf8_Two_Name,
         "two-byte UTF-8 create selects file");

      Files.Model.Begin_Create_File (Model, Utf8_Three_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "create accepts three-byte UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, Utf8_Three_Name)), "three-byte UTF-8 create writes file");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         Utf8_Three_Name,
         "three-byte UTF-8 create selects file");

      Files.Model.Begin_Create_File (Model, Utf8_Four_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Success,
         "create accepts four-byte UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, Utf8_Four_Name)), "four-byte UTF-8 create writes file");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         Utf8_Four_Name,
         "four-byte UTF-8 create selects file");
   end Test_Create_File_Does_Not_Overwrite;
