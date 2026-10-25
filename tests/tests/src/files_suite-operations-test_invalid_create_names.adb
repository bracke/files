separate (Files_Suite.Operations)
   procedure Test_Invalid_Create_Names (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
   begin
      Reset_Root;
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Begin_Create_File (Model, "");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "create rejects empty names");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.name.invalid",
         "empty create records invalid name");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, ".");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "create rejects dot names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "..");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "create rejects parent-directory names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "bad/name.txt");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "create rejects path separator names");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Error_Key),
         "error.name.invalid",
         "create invalid name reports error key");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.name.invalid",
         "create invalid name records error");
      Assert (not Path_Exists (Join (Root, "bad")), "invalid create does not create directories");
      Assert (Files.Model.Temporary_Item_Is_Active (Model), "invalid create keeps temporary item active");
      Assert (Files.Model.Rename_Is_Active (Model), "invalid create keeps rename active");

      --  Backslash, colon, wildcard, and trailing-dot names are rejected only
      --  under Windows rules; on a POSIX host they are ordinary filenames, so
      --  the host-gated behaviour is covered directly in Test_Leaf_Name_Rules
      --  rather than through the create operation here.
      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "trailing-space.txt ");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "create rejects trailing-space names");
      Assert
        (not Ada.Directories.Exists (Join (Root, "trailing-space.txt ")),
         "invalid trailing-space create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, NBSP_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "create rejects NBSP-only names");
      Assert (not Ada.Directories.Exists (Join (Root, NBSP_Name)), "invalid NBSP-only create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Trailing_NBSP_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "create rejects trailing NBSP names");
      Assert
        (not Ada.Directories.Exists (Join (Root, Trailing_NBSP_Name)),
         "invalid trailing NBSP create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Trailing_Ideographic_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "create rejects trailing ideographic-space names");
      Assert
        (not Ada.Directories.Exists (Join (Root, Trailing_Ideographic_Name)),
         "invalid trailing ideographic-space create writes no file");

      --  Reserved device names (CON, LPT1, CONIN$ and space-padded variants) are
      --  rejected only under Windows rules; Test_Leaf_Name_Rules covers that.
      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Nul_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "create rejects embedded NUL names");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Error_Key),
         "error.name.invalid",
         "create NUL name reports error key");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model),
         "error.name.invalid",
         "create NUL name records error");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Tab_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "create rejects control-character names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, C1_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "create rejects C1 control-character names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Encoded_C1_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "create rejects UTF-8 encoded C1 control-character names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Truncated_UTF8_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "create rejects truncated UTF-8 names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Overlong_UTF8_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Files_Suite.Support.Assert_Equal
        (Result.Status,
         Files.Operations.Operation_Invalid_Name,
         "create rejects overlong UTF-8 names");
   end Test_Invalid_Create_Names;
