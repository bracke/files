separate (Files_Suite.Operations)
   --  A cause key from a real failure, not from the table's own numbers: a
   --  file whose name is longer than any filesystem stores fails with the
   --  host's own ENAMETOOLONG, and is reported as a name too long.
   procedure Test_Name_Too_Long_Is_Reported (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Result : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      Result := Files.File_System.Create_Empty_File (Join (Root, [1 .. 300 => 'n']));
      Assert (not Result.Success, "a 300-byte name is not created");
      Files_Suite.Support.Assert_Equal
        (To_String (Result.Error_Key), "error.io.name_too_long", "the refusal says the name is too long");
   end Test_Name_Too_Long_Is_Reported;
