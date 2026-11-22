with Files.File_System.Recovery_Registry;
with Files.File_Identities;
with Files.File_System.Testing;
with Files.Protocol_Names;
separate (Files_Suite.Recovery)
   --  Removing a verified folder that stops part way leaves what is left in
   --  its registered recovery stage: it is no longer the folder, so it is not
   --  put back under the folder's name as if it were. A removal that removed
   --  nothing puts the folder back whole.
   procedure Test_Partial_Delete_Kept_In_Stage (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Folder : constant String := Join (Root, "made-folder");
      Stage  : constant String := Join (Root, Files.Protocol_Names.Recovery_Stage_Prefix & "1");
      Count  : constant := 9;
      Result : Files.File_System.Mutation_Result;

      function Child (Index : Positive) return String is
        (Join (Folder, "f" & Ada.Strings.Fixed.Trim (Index'Image, Ada.Strings.Left)));

      function Whole return Boolean is
        (for all Index in 1 .. Count => Ada.Directories.Exists (Child (Index)));
   begin
      Reset_Root;
      Ada.Directories.Create_Directory (Folder);
      for Index in 1 .. Count loop
         Write_Binary_File (Child (Index), "bytes" & Index'Image);
      end loop;
      declare
         Identity : constant String := Files.File_Identities.Token (Folder);
         Revision : constant String := Files.File_System.Tree_Revision (Folder);
      begin
         --  One file in the middle refuses to go, as a sharing violation would.
         Files.File_System.Testing.Fail_Owned_Delete (Join (Join (Stage, "payload"), "f5"));
         Result := Files.File_System.Delete_Created_Entry (Folder, Identity, Revision);
         Files.File_System.Testing.Stop_Failing_Owned_Delete;
      end;
      Assert (not Result.Success, "a removal that stopped part way fails");
      Assert (not Ada.Directories.Exists (Folder) or else Whole,
              "a folder is back under its name only whole, never with part of it removed");
      if not Ada.Directories.Exists (Folder) then
         Assert (Ada.Directories.Exists (Join (Join (Stage, "payload"), "f5")),
                 "what is left stays in its recovery stage");
         Assert (Files.File_System.Recovery_Registry.Registered_Recovery_Payloads.Contains
                   (To_Unbounded_String (Join (Stage, "payload"))),
                 "listed among the recoveries");
      end if;
   exception
      when others =>
         Files.File_System.Testing.Stop_Failing_Owned_Delete;
         raise;
   end Test_Partial_Delete_Kept_In_Stage;
