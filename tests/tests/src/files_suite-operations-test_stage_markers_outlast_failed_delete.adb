with Files.File_System.Testing;
with Files.Protocol_Names;
separate (Files_Suite.Operations)
   --  A stage whose delete fails partway keeps what marks it as ours -- its
   --  owner file and vacated marker -- so the recovery sweep can finish it
   --  later. Each payload child is refused in turn: whatever order the
   --  folder lists in, a marker deleted before the refused child is caught.
   procedure Test_Stage_Markers_Outlast_Failed_Delete (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Stage    : constant String := Join (Root, "failing-stage");
      Children : constant := 8;

      function Child (Index : Positive) return String is
        (Join (Stage, "child-" & Files.Types.Natural_Text (Index)));
   begin
      for Refused in 1 .. Children loop
         Reset_Root;
         Ada.Directories.Create_Directory (Stage);
         Write_Binary_File (Join (Stage, Files.Protocol_Names.Recovery_Owner), "owner");
         Write_Binary_File (Join (Stage, Files.Protocol_Names.Recovery_Vacated), "");
         for Index in 1 .. Children loop
            Write_Binary_File (Child (Index), "payload");
         end loop;
         Files.File_System.Testing.Fail_Owned_Delete (Child (Refused));
         begin
            Files.File_System.Testing.Delete_Owned_Tree (Stage);
            Files.File_System.Testing.Stop_Failing_Owned_Delete;
            Assert (False, "a refused child fails the stage's delete");
         exception
            when Ada.Directories.Use_Error =>
               Files.File_System.Testing.Stop_Failing_Owned_Delete;
         end;
         Assert (Ada.Directories.Exists (Child (Refused)), "the refused child is still there");
         Assert
           (Ada.Directories.Exists (Join (Stage, Files.Protocol_Names.Recovery_Owner)),
            "the owner file outlasts a failed delete (child " & Files.Types.Natural_Text (Refused) & " refused)");
         Assert
           (Ada.Directories.Exists (Join (Stage, Files.Protocol_Names.Recovery_Vacated)),
            "the vacated marker outlasts a failed delete (child " & Files.Types.Natural_Text (Refused) & " refused)");
      end loop;
      Files.File_System.Testing.Delete_Owned_Tree (Stage);
      Assert (not Ada.Directories.Exists (Stage), "once nothing refuses, the stage goes entirely");
   end Test_Stage_Markers_Outlast_Failed_Delete;
