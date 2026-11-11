with Files.Fs_Primitives;
separate (Files_Suite.Operations)
   --  A name longer than the destination filesystem stores (255 bytes, or
   --  255 UTF-16 units under DOS rules) is refused as too long before the
   --  disk is touched, on every host alike: a Windows runner was seen
   --  creating a 300-character name. Creating a file or a folder, linking
   --  and renaming all refuse it; the errno-to-cause table has its own test
   --  (Test_Io_Error_Classifier).
   procedure Test_Name_Too_Long_Is_Reported (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Long_Path : constant String := Join (Root, [1 .. 300 => 'n']);
      Source    : constant String := Join (Root, "source.txt");
      Result    : Files.File_System.Mutation_Result;
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Model     : Files.Model.Window_Model;
      Committed : Files.Operations.Operation_Result;

      procedure Expect_Refused (What : String) is
      begin
         Assert (not Result.Success, What & ": a 300-byte name is refused");
         Assert (not Files.Fs_Primitives.Entry_Exists (Long_Path), What & ": and nothing was made");
         Files_Suite.Support.Assert_Equal
           (To_String (Result.Error_Key), "error.io.name_too_long", What & ": the refusal says the name is too long");
      end Expect_Refused;
   begin
      Reset_Root;
      Result := Files.File_System.Create_Empty_File (Long_Path);
      Expect_Refused ("create file");
      Result := Files.File_System.Create_Directory (Long_Path);
      Expect_Refused ("create folder");

      Write_File (Source, "kept");
      Result := Files.File_System.Create_Symbolic_Link (Source, Long_Path);
      Expect_Refused ("symbolic link");
      Result := Files.File_System.Create_Hard_Link (Source, Long_Path);
      Expect_Refused ("hard link");

      Result := Files.File_System.Rename_Item (Source, Long_Path);
      Expect_Refused ("rename");
      Assert (File_Has_Bytes (Source, "kept"), "rename: the source keeps its name and content");

      --  The inline rename a user types into goes the same way.
      Files.Model.Initialize (Model, Root, Files.File_System.Load_Directory (Root, Settings).Items, Root);
      Select_Name (Model, "source.txt");
      Files.Model.Toggle_Rename (Model);
      Assert (Files.Model.Rename_Insert_At_Carets (Model, [1 .. 300 => 'n']), "the typed name is entered");
      Committed := Files.Operations.Commit_Rename (Model, Settings);
      Assert (Committed.Status /= Files.Operations.Operation_Success, "inline rename: a 300-byte name is refused");
      Files_Suite.Support.Assert_Equal
        (To_String (Committed.Error_Key), "error.io.name_too_long", "inline rename: the refusal says why");
      Files_Suite.Support.Assert_Equal
        (Files.Model.Last_Error_Key (Model), "error.io.name_too_long", "inline rename: and the window shows it");
      Assert (File_Has_Bytes (Source, "kept"), "inline rename: the source keeps its name and content");
   end Test_Name_Too_Long_Is_Reported;
