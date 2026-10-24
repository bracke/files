separate (Files_Suite.Operations)
   procedure Test_Invalid_File_Operation_Names (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Load     : Files.File_System.Directory_Load_Result;
      Model    : Files.Model.Window_Model;
      Items    : Files.File_System.Item_Vectors.Vector;
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Result   : Files.Operations.Operation_Result;
      Nul_Name : constant String := "bad" & Character'Val (0) & "name.txt";
      Tab_Name : constant String := "bad" & Character'Val (9) & "name.txt";
      C1_Name  : constant String := "bad" & Character'Val (133) & "name.txt";
      Encoded_C1_Name : constant String := "bad" & Byte (16#C2#) & Byte (16#85#) & "name.txt";
      Truncated_UTF8_Name : constant String := "bad" & Byte (16#E2#) & Byte (16#82#) & "name.txt";
      Overlong_UTF8_Name  : constant String := "bad" & Byte (16#C0#) & Byte (16#AF#) & "name.txt";
      NBSP_Name : constant String := Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#00A0#));
      Ideographic_Space_Name : constant String :=
        Files.Application.Windows.Text_Input_Bytes (Wide_Wide_Character'Val (16#3000#));
      Trailing_NBSP_Name : constant String := "trailing-nbsp" & NBSP_Name;
      Trailing_Ideographic_Name : constant String := "trailing-wide" & Ideographic_Space_Name;
   begin
      Reset_Root;
      Files.Model.Initialize (Model, Root, Items, Root);
      Files.Model.Begin_Create_File (Model, "");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects empty names");
      Assert (Files.Model.Last_Error_Key (Model) = "error.name.invalid", "empty create records invalid name");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, ".");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects dot names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "..");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects parent-directory names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, "bad/name.txt");
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects path separator names");
      Assert (To_String (Result.Error_Key) = "error.name.invalid", "create invalid name reports error key");
      Assert (Files.Model.Last_Error_Key (Model) = "error.name.invalid", "create invalid name records error");
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
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects trailing-space names");
      Assert
        (not Ada.Directories.Exists (Join (Root, "trailing-space.txt ")),
         "invalid trailing-space create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, NBSP_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects NBSP-only names");
      Assert (not Ada.Directories.Exists (Join (Root, NBSP_Name)), "invalid NBSP-only create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Trailing_NBSP_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects trailing NBSP names");
      Assert
        (not Ada.Directories.Exists (Join (Root, Trailing_NBSP_Name)),
         "invalid trailing NBSP create writes no file");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Trailing_Ideographic_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Invalid_Name,
         "create rejects trailing ideographic-space names");
      Assert
        (not Ada.Directories.Exists (Join (Root, Trailing_Ideographic_Name)),
         "invalid trailing ideographic-space create writes no file");

      --  Reserved device names (CON, LPT1, CONIN$ and space-padded variants) are
      --  rejected only under Windows rules; Test_Leaf_Name_Rules covers that.
      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Nul_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects embedded NUL names");
      Assert (To_String (Result.Error_Key) = "error.name.invalid", "create NUL name reports error key");
      Assert (Files.Model.Last_Error_Key (Model) = "error.name.invalid", "create NUL name records error");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Tab_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects control-character names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, C1_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects C1 control-character names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Encoded_C1_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Invalid_Name,
         "create rejects UTF-8 encoded C1 control-character names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Truncated_UTF8_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects truncated UTF-8 names");

      Files.Model.Cancel_Create_File (Model);
      Files.Model.Begin_Create_File (Model, Overlong_UTF8_Name);
      Result := Files.Operations.Commit_Create_File (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "create rejects overlong UTF-8 names");

      Reset_Root;
      Write_File (Join (Root, "old.txt"));
      Load := Files.File_System.Load_Directory (Root, Settings);
      Files.Model.Initialize (Model, Root, Load.Items, Root);
      Select_Name (Model, "old.txt");
      Files.Model.Toggle_Rename (Model);
      Files.Model.Set_Rename_Text (Model, "");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects empty names");

      Files.Model.Set_Rename_Text (Model, ".");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects dot names");

      Files.Model.Set_Rename_Text (Model, "..");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects parent-directory names");

      Files.Model.Set_Rename_Text (Model, "bad/name.txt");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects path separator names");
      Assert (To_String (Result.Error_Key) = "error.name.invalid", "rename invalid name reports error key");
      Assert (Files.Model.Last_Error_Key (Model) = "error.name.invalid", "rename invalid name records error");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "invalid rename leaves source in place");
      Assert (not Path_Exists (Join (Root, "bad")), "invalid rename does not create directories");
      Assert (Files.Model.Rename_Is_Active (Model), "invalid rename keeps rename active");
      Assert (Files.Model.Selected_Name (Model) = "old.txt", "invalid rename keeps selected item");

      --  Backslash, colon, wildcard, and trailing-dot names are Windows-only
      --  rejections -- ordinary filenames on a POSIX host -- so the POSIX/Windows
      --  split is covered directly in Test_Leaf_Name_Rules, not through rename.
      Files.Model.Set_Rename_Text (Model, "renamed ");
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects trailing-space names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "trailing-space rename leaves source in place");
      Assert (not Ada.Directories.Exists (Join (Root, "renamed ")), "invalid trailing-space rename writes no file");

      Files.Model.Set_Rename_Text (Model, Ideographic_Space_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Invalid_Name,
         "rename rejects ideographic-space-only names");
      Assert
        (Ada.Directories.Exists (Join (Root, "old.txt")),
         "ideographic-space-only rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Trailing_NBSP_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects trailing NBSP names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "trailing NBSP rename leaves source in place");
      Assert
        (not Ada.Directories.Exists (Join (Root, Trailing_NBSP_Name)),
         "invalid trailing NBSP rename writes no file");

      Files.Model.Set_Rename_Text (Model, Trailing_Ideographic_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Invalid_Name,
         "rename rejects trailing ideographic-space names");
      Assert
        (Ada.Directories.Exists (Join (Root, "old.txt")),
         "trailing ideographic-space rename leaves source in place");

      --  Reserved device names (NUL, COM9, CONOUT$ and space-padded variants) are
      --  a Windows-only rejection; the POSIX/Windows split lives in
      --  Test_Leaf_Name_Rules.
      Files.Model.Set_Rename_Text (Model, Nul_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects embedded NUL names");
      Assert (To_String (Result.Error_Key) = "error.name.invalid", "rename NUL name reports error key");
      Assert (Files.Model.Last_Error_Key (Model) = "error.name.invalid", "rename NUL name records error");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "NUL rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Tab_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects control-character names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "control-character rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, C1_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects C1 control-character names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "C1 control-character rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Encoded_C1_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert
        (Result.Status = Files.Operations.Operation_Invalid_Name,
         "rename rejects UTF-8 encoded C1 control-character names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "encoded C1 rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Truncated_UTF8_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects truncated UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "truncated UTF-8 rename leaves source in place");

      Files.Model.Set_Rename_Text (Model, Overlong_UTF8_Name);
      Result := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Result.Status = Files.Operations.Operation_Invalid_Name, "rename rejects overlong UTF-8 names");
      Assert (Ada.Directories.Exists (Join (Root, "old.txt")), "overlong UTF-8 rename leaves source in place");
   end Test_Invalid_File_Operation_Names;
