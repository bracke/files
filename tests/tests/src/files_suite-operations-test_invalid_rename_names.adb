separate (Files_Suite.Operations)
   procedure Test_Invalid_Rename_Names (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Write_File (Join (Root, "old.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "old.txt");
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "rename rejects empty names");

      Files.Model.Set_Rename_Text (Model, ".");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "rename rejects dot names");

      Files.Model.Set_Rename_Text (Model, "..");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "rename rejects parent-directory names");

      Files.Model.Set_Rename_Text (Model, "bad/name.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "rename rejects path separator names");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Error_Key),
         "error.name.invalid",
         "rename invalid name reports error key");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.name.invalid",
         "rename invalid name records error");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "invalid rename leaves source in place");
      Assert (not Path_Exists (Join (Root, "bad")), "invalid rename does not create directories");
      Assert (Files.Model.Rename_Is_Active (Model), "invalid rename keeps rename active");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Selected_Name (Model),
         "old.txt",
         "invalid rename keeps selected item");

      --  Backslash, colon, wildcard, and trailing-dot names are Windows-only
      --  rejections -- ordinary filenames on a POSIX host -- so the POSIX/Windows
      --  split is covered directly in Test_Leaf_Name_Rules, not through rename.
      Files.Model.Set_Rename_Text (Model, "renamed ");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "rename rejects trailing-space names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "trailing-space rename leaves source in place");
      Assert (not Ada.Directories.Exists (Join (Root, "renamed ")), "invalid trailing-space rename writes no file");

      Files.Model.Set_Rename_Text (Model, Ideographic_Space_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "rename rejects ideographic-space-only names");
      Assert
        (Ada.Directories.Exists (Join (Root, "old.txt")),
         "ideographic-space-only rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Trailing_NBSP_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "rename rejects trailing NBSP names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "trailing NBSP rename leaves source in place");
      Assert
        (not Ada.Directories.Exists (Join (Root, Trailing_NBSP_Name)),
         "invalid trailing NBSP rename writes no file");

      Files.Model.Set_Rename_Text (Model, Trailing_Ideographic_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "rename rejects trailing ideographic-space names");
      Assert
        (Ada.Directories.Exists (Join (Root, "old.txt")),
         "trailing ideographic-space rename leaves source in place");

      --  Reserved device names (NUL, COM9, CONOUT$ and space-padded variants) are
      --  a Windows-only rejection; the POSIX/Windows split lives in
      --  Test_Leaf_Name_Rules.
      Files.Model.Set_Rename_Text (Model, Nul_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "rename rejects embedded NUL names");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Error_Key),
         "error.name.invalid",
         "rename NUL name reports error key");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.name.invalid",
         "rename NUL name records error");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "NUL rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Tab_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "rename rejects control-character names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "control-character rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, C1_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "rename rejects C1 control-character names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "C1 control-character rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Encoded_C1_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "rename rejects UTF-8 encoded C1 control-character names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "encoded C1 rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Truncated_UTF8_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "rename rejects truncated UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "truncated UTF-8 rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Overlong_UTF8_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "rename rejects overlong UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "overlong UTF-8 rename leaves source in place");
   end Test_Invalid_Rename_Names;
