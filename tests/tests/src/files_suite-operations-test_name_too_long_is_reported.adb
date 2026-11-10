with Files.Fs_Primitives;
separate (Files_Suite.Operations)
   --  A name longer than the destination filesystem stores (255 bytes, or
   --  255 UTF-16 units under DOS rules) is refused as too long before the
   --  disk is touched, on every host alike: a Windows runner was seen
   --  creating a 300-character name. The errno-to-cause table has its own
   --  test (Test_Io_Error_Classifier).
   procedure Test_Name_Too_Long_Is_Reported (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Result : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      Result := Files.File_System.Create_Empty_File (Join (Root, [1 .. 300 => 'n']));
      Assert (not Result.Success, "a 300-byte name is not created");
      Assert (not Files.Fs_Primitives.Entry_Exists (Join (Root, [1 .. 300 => 'n'])), "and nothing was made");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Error_Key), "error.io.name_too_long", "the refusal says the name is too long");
   end Test_Name_Too_Long_Is_Reported;
