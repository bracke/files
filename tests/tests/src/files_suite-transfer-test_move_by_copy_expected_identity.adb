with Files.File_System.Testing;
separate (Files_Suite.Transfer)
   --  A move by copy that names the item it expects (a restore from a trash
   --  on another device does) copies only that item: another one under its
   --  name is refused before anything is copied, and the one named moves.
   procedure Test_Move_By_Copy_Expected_Identity (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Source      : constant String := Join (Root, "expected-source");
      Destination : constant String := Join (Root, "expected-destination");
      Mutation    : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      Write_Binary_File (Source, "the item named");
      Mutation := Files.File_System.Testing.Move_By_Copy
        (Source, Destination, Files.File_Identities.Token (Source) & "-another");
      Assert (not Mutation.Success, "another identity is refused");
      Files_Suite.Support.Assert_Equal
        (To_String (Mutation.Error_Key), "error.move.failed", "the refusal carries the fallback key");
      Assert (not Ada.Directories.Exists (Destination), "nothing is copied for another item");
      Assert (File_Has_Bytes (Source, "the item named"), "the source stays");
      Mutation := Files.File_System.Testing.Move_By_Copy (Source, Destination, Files.File_Identities.Token (Source));
      Assert (Mutation.Success, "the item named moves");
      Assert (File_Has_Bytes (Destination, "the item named"), "its copy is at the destination");
      Assert (not Ada.Directories.Exists (Source), "and its source is gone");
   end Test_Move_By_Copy_Expected_Identity;
