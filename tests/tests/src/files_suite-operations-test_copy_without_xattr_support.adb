separate (Files_Suite.Operations)
   --  A file with extended attributes copies onto a volume that holds none
   --  (vfat, exFAT, an NFS export): the file arrives, its attributes do not,
   --  as cp -a does it. A browser tags every download with one.
   procedure Test_Copy_Without_Xattr_Support (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function Prepare_Native (Path : System.Address; Directory : Interfaces.C.int) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_metadata_prepare";
      Source      : constant String := Join (Root, "tagged.txt");
      Copy        : constant String := Join (Root, "tagged-copy.txt");
      Mutation    : Files.File_System.Mutation_Result;
      Environment : Files_Suite.Support.Environment_Guard;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip
           ("Test_Copy_Without_Xattr_Support", "the xattr fault hooks lsetxattr in Linux-only C");
         return;
      end if;
      Reset_Root;
      Write_Binary_File (Source, "downloaded");
      declare
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Source);
      begin
         Assert (Prepare_Native (Name'Address, 0) = 1, "the source carries extended attributes and an ACL");
      end;
      Files_Suite.Support.Save (Environment, "FILES_TEST_XATTR_UNSUPPORTED");
      Ada.Environment_Variables.Set ("FILES_TEST_XATTR_UNSUPPORTED", "1");
      Mutation := Files.File_System.Copy_Tree (Source, Copy);
      Ada.Environment_Variables.Clear ("FILES_TEST_XATTR_UNSUPPORTED");
      Assert (Mutation.Success, "the copy succeeds: " & To_String (Mutation.Error_Key));
      Assert (File_Has_Bytes (Copy, "downloaded"), "and holds the file's bytes");
   end Test_Copy_Without_Xattr_Support;
