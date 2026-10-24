separate (Files_Suite.Operations)
   procedure Test_Commit_Rename (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
      Taken    : constant String := Join (Root, "taken.txt");
      Direct_Source : constant String := Join (Root, "direct-source.txt");
      Direct_Target : constant String := Join (Root, "direct-target.txt");
      Missing_Parent_Source : constant String := Join (Root, "missing-parent-source.txt");
      Non_Directory_Source  : constant String := Join (Root, "non-directory-source.txt");
      Utf8_Target : constant String :=
        "renamed-" & Byte (16#E2#) & Byte (16#82#) & Byte (16#AC#) & ".txt";
      Mutation : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      Write_File (Join (Root, "old.txt"));
      Write_File (Taken, "destination");
      Write_File (Direct_Source, "direct");
      Write_File (Missing_Parent_Source, "missing parent");
      Write_File (Non_Directory_Source, "non-directory parent");
      Ada.Directories.Create_Path (Join (Root, "taken-dir"));
      Mutation := Files.File_System.Rename_Item (Join (Root, "old.txt"), Join (Root, "taken-dir"));
      Assert (not Mutation.Success, "rename refuses an existing directory destination");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "existing directory rename reports invalid destination");
      Mutation := Files.File_System.Rename_Item (Join (Root, "old.txt"), Taken);
      Assert (not Mutation.Success, "direct rename refuses an existing file destination");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "existing file direct rename reports invalid destination");
      Assert
        (Ada.Strings.Fixed.Index (Project_Tools.Files.Read_Raw_File (Taken), "destination") > 0,
         "direct rename preserves existing destination file");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "direct failed rename leaves source in place");
      Mutation := Files.File_System.Rename_Item (Join (Root, "missing-source.txt"), Join (Root, "new-missing.txt"));
      Assert (not Mutation.Success, "rename reports missing source failure");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.source_missing",
         "missing source rename reports source-missing diagnostic");
      Assert (not Ada.Directories.Exists (Join (Root, "new-missing.txt")), "missing source rename writes no target");
      Mutation := Files.File_System.Rename_Item (Join (Root, "old.txt"), "");
      Assert (not Mutation.Success, "rename reports empty destination failure");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "empty destination rename reports invalid destination");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "empty destination rename leaves source in place");
      Mutation :=
        Files.File_System.Rename_Item
          (Root & "/bad" & Character'Val (0) & "same.txt",
           Root & "/bad" & Character'Val (0) & "same.txt");
      Assert (not Mutation.Success, "malformed same-path rename reports failure");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.source_missing",
         "malformed same-path rename reports source-missing diagnostic");
      Mutation :=
        Files.File_System.Rename_Item
          (Missing_Parent_Source,
           Join (Join (Root, "missing-parent"), "target.txt"));
      Assert (not Mutation.Success, "rename refuses a missing destination parent");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "missing destination parent reports invalid destination");
      Assert (Ada.Directories.Exists (Missing_Parent_Source), "missing parent rename leaves source in place");
      Mutation := Files.File_System.Rename_Item (Non_Directory_Source, Join (Taken, "target.txt"));
      Assert (not Mutation.Success, "rename refuses a non-directory destination parent");
      Assert
        (To_String (Mutation.Error_Key) = "error.rename.invalid_destination",
         "non-directory destination parent reports invalid destination");
      Assert (Ada.Directories.Exists (Non_Directory_Source), "non-directory parent rename leaves source in place");
      Mutation :=
        Files.File_System.Rename_Item (Direct_Source, Join (Root, "bad" & ASCII.NUL & "name.txt"));
      Assert (not Mutation.Success, "direct rename rejects a name no filesystem can store");
      Assert
        (To_String (Mutation.Error_Key) = "error.name.invalid",
         "direct invalid-name rename reports invalid-name diagnostic");
      Assert (Ada.Directories.Exists (Direct_Source), "direct invalid-name rename leaves source in place");
      Assert
        (not Path_Exists (Join (Root, "bad" & ASCII.NUL & "name.txt")),
         "direct invalid-name rename writes no target");
      Mutation := Files.File_System.Rename_Item (Direct_Source, Direct_Target);
      Assert (Mutation.Success, "direct rename mutation succeeds");
      Assert (To_String (Mutation.Error_Key) = "", "successful direct rename has no error key");
      Assert (not Ada.Directories.Exists (Direct_Source), "direct rename removes source path");
      Assert (Ada.Directories.Exists (Direct_Target), "direct rename creates destination path");
      Mutation := Files.File_System.Rename_Item (Direct_Target, Direct_Target);
      Assert (Mutation.Success, "direct same-path rename is a successful no-op");
      Assert (To_String (Mutation.Error_Key) = "", "direct same-path rename has no error key");
      Assert (Ada.Directories.Exists (Direct_Target), "direct same-path rename keeps source path");
      Mutation :=
        Files.File_System.Rename_Item
          (Direct_Target,
           Files.File_System.Join_Path (Files.File_System.Join_Path (Root, "."), "direct-target.txt"));
      Assert (Mutation.Success, "direct normalized same-path rename is a successful no-op");
      Assert (To_String (Mutation.Error_Key) = "", "direct normalized same-path rename has no error key");
      Assert (Ada.Directories.Exists (Direct_Target), "direct normalized same-path rename keeps source path");
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "old.txt");
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Error (Model, "error.rename.failed");
      Files.Model.Set_Rename_Text (Model, "old.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "same-name rename succeeds without mutation");
      Assert (To_String (Result.Path) = Join (Root, "old.txt"), "same-name rename reports existing path");
      Assert (Files.Model.Last_Error_Key (Model) = "", "same-name rename clears stale error state");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "same-name rename leaves source in place");
      Assert (not Files.Model.Rename_Is_Active (Model), "same-name rename clears edit state");
      Assert (Files.Model.Selected_Name (Model) = "old.txt", "same-name rename keeps selected source");

      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "taken.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Failed, "rename refuses an existing destination");
      Assert
        (To_String (Result.Error_Key) = "error.rename.invalid_destination",
         "existing destination rename reports invalid destination key");
      Assert (To_String (Result.Path) = Taken, "failed rename reports attempted destination path");
      Assert (Files.Model.Last_Error_Key (Model) = "error.rename.invalid_destination", "failed rename records error");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "failed rename leaves source in place");
      Assert
        (Ada.Strings.Fixed.Index (Project_Tools.Files.Read_Raw_File (Taken), "destination") > 0,
         "failed rename preserves destination");
      Assert (Files.Model.Rename_Is_Active (Model), "failed rename keeps rename mode active");
      Assert (Files.Model.Rename_Text (Model) = "taken.txt", "failed rename keeps attempted name");
      Assert (Files.Model.Selected_Name (Model) = "old.txt", "failed rename keeps selected source");

      Ada.Directories.Delete_File (Join (Root, "old.txt"));
      Files.Model.Set_Rename_Text (Model, "missing-result.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Failed, "rename reports disappeared source");
      Assert
        (To_String (Result.Error_Key) = "error.rename.source_missing",
         "disappeared source reports source-missing error key");
      Assert
        (To_String (Result.Path) = Join (Root, "missing-result.txt"),
         "source-missing rename reports attempted destination path");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.rename.source_missing",
         "disappeared source records source-missing error");
      Assert (not Files.Model.Rename_Is_Active (Model), "source-missing rename clears stale rename mode");
      Assert (Files.Model.Rename_Text (Model) = "", "source-missing rename clears stale attempted name");
      Assert (Files.Model.Selected_Count (Model) = 0, "source-missing rename clears stale selection");
      Assert (Files.Model.Selected_Name (Model) = "", "source-missing rename removes stale selected item");

      Reset_Root;
      Write_File (Join (Root, "same-missing.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "same-missing.txt");
      Files.Model.Toggle_Rename (Model);
      Ada.Directories.Delete_File (Join (Root, "same-missing.txt"));
      Files.Model.Set_Rename_Text (Model, "same-missing.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Failed,
         "same-name rename reports disappeared source");
      Assert
        (To_String (Result.Error_Key) = "error.rename.source_missing",
         "same-name disappeared source reports source-missing error key");
      Assert
        (Files.Model.Last_Error_Key (Model) = "error.rename.source_missing",
         "same-name disappeared source records source-missing error");
      Assert
        (not Files.Model.Rename_Is_Active (Model),
         "same-name disappeared source clears stale rename mode");

      Write_File (Join (Root, "missing-parent-source.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "missing-parent-source.txt");
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "new.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "rename succeeds after source is restored");
      Assert (Files.Model.Last_Error_Key (Model) = "", "restored-source rename clears stale error");
      Assert (Ada.Directories.Exists (Join (Root, "new.txt")), "restored-source rename creates new path");
      Assert (To_String (Result.Path) = Join (Root, "new.txt"), "rename commit returns renamed path");
      Assert (not Ada.Directories.Exists (Join (Root, "missing-parent-source.txt")), "rename removes old path");
      Assert (not Files.Model.Rename_Is_Active (Model), "rename commit clears edit state");
      Assert (Files.Model.Selected_Name (Model) = "new.txt", "renamed item is selected after reload");

      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, Utf8_Target);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Success, "rename accepts UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, Utf8_Target)), "UTF-8 rename creates new path");
      Assert (not Ada.Directories.Exists (Join (Root, "new.txt")), "UTF-8 rename removes old path");
      Assert (Files.Model.Selected_Name (Model) = Utf8_Target, "UTF-8 renamed item is selected after reload");
   end Test_Commit_Rename;
