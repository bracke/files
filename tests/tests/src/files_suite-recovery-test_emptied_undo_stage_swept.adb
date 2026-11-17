with Files.File_Identities;
with Files.File_System.Testing;
with Files.Protocol_Names;
separate (Files_Suite.Recovery)
   --  Removing a verified entry takes it into a recovery stage first and
   --  marks the stage before the entry leaves it, as a restore does. A stage
   --  that would not go afterwards -- or a stop right then -- is a marked,
   --  emptied stage the next sweep finishes, record and all, rather than a
   --  hidden folder kept for good.
   procedure Test_Emptied_Undo_Stage_Swept (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Made  : constant String := Join (Root, "made.txt");
      Stage : constant String := Join (Root, Files.Protocol_Names.Recovery_Stage_Prefix & "1");
      Result : Files.File_System.Mutation_Result;
   begin
      Reset_Root;
      Write_Binary_File (Made, "made bytes");
      declare
         Identity : constant String := Files.File_Identities.Token (Made);
         Revision : constant String := Files.File_System.Tree_Revision (Made);
      begin
         --  The stage's sidecar refuses to go, as a sharing violation would.
         Files.File_System.Testing.Fail_Owned_Delete (Join (Stage, "original"));
         Result := Files.File_System.Delete_Created_Entry (Made, Identity, Revision);
         Files.File_System.Testing.Stop_Failing_Owned_Delete;
      end;
      Assert (Result.Success and then not Ada.Directories.Exists (Made), "the verified entry is removed");
      Assert (Ada.Directories.Exists (Stage), "its stage would not go");
      Assert (Ada.Directories.Exists (Join (Stage, Files.Protocol_Names.Recovery_Vacated)),
              "the stage was marked before the entry left it");
      Files.File_System.Sweep_Recovery_Registry;
      Assert (not Ada.Directories.Exists (Stage), "the sweep finishes the marked, emptied stage");
   exception
      when others =>
         Files.File_System.Testing.Stop_Failing_Owned_Delete;
         raise;
   end Test_Emptied_Undo_Stage_Swept;
