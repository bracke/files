separate (Files_Suite.Operations)
   --  A file with extended attributes copies onto a volume that holds none
   --  (vfat, exFAT, an NFS export): the file arrives, its attributes do not,
   --  as cp -a does it. A browser tags every download with one.
   --  On Windows the attributes are named streams -- a download's Mark of
   --  the Web among them -- and the volume a FAT-formatted one CI mounts.
   procedure Test_Copy_Without_Xattr_Support (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      function Prepare_Native (Path : System.Address; Directory : Interfaces.C.int) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_metadata_prepare";
      function Stream_Count (Path : System.Address) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_named_stream_count";
      Source      : constant String := Join (Root, "tagged.txt");
      Copy        : constant String := Join (Root, "tagged-copy.txt");
      Mutation    : Files.File_System.Mutation_Result;
      Environment : Files_Suite.Support.Environment_Guard;

      --  A copy of a file with named streams (on Linux, user.* attributes)
      --  onto the FAT or exFAT volume named by FILES_TEST_STREAMLESS_VOLUME.
      procedure Check_Streamless_Volume is
         Volume : constant String := Ada.Environment_Variables.Value ("FILES_TEST_STREAMLESS_VOLUME", "");
         Target : constant String := (if Volume = "" then "" else Join (Volume, "files-test-streamless"));
         Arrived : constant String := Join (Target, "tagged-copy.txt");
         procedure Remove_Target is
         begin
            if Ada.Directories.Exists (Target) then
               Mutation := Files.File_System.Delete_Permanently (Target);
               Assert (Mutation.Success, "remove the folder on the volume without streams");
            end if;
         end Remove_Target;
      begin
         if Volume = "" then
            Files_Suite.Support.Skip
              ("Test_Copy_Without_Xattr_Support",
               "no volume without named streams (set FILES_TEST_STREAMLESS_VOLUME)");
            return;
         end if;
         Reset_Root;
         Write_Binary_File (Source, "downloaded");
         declare
            Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Source);
         begin
            Assert (Prepare_Native (Name'Address, 0) = 1, "the source carries a Zone.Identifier and a custom stream");
            Assert (Stream_Count (Name'Address) = 2, "the source lists its two named streams or user attributes");
         end;
         Remove_Target;
         Ada.Directories.Create_Directory (Target);
         Mutation := Files.File_System.Copy_Tree (Source, Arrived);
         Assert
           (Mutation.Success, "the copy onto a volume without streams succeeds: " & To_String (Mutation.Error_Key));
         Assert (File_Has_Bytes (Arrived, "downloaded"), "and holds the file's bytes");
         declare
            Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Arrived);
         begin
            Assert (Stream_Count (Name'Address) = 0, "and arrives without the streams that volume cannot hold");
         end;
         --  A failed run leaves the folder for the next one to remove.
         Remove_Target;
      end Check_Streamless_Volume;
   begin
      if Hostkit.Host.Current = Hostkit.Host.Windows then
         Check_Streamless_Volume;
         return;
      end if;
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip
           ("Test_Copy_Without_Xattr_Support", "the xattr fault hooks lsetxattr in Linux-only C");
         return;
      end if;
      --  A real vfat volume where CI mounts one, then the fault hook.
      if Ada.Environment_Variables.Value ("FILES_TEST_STREAMLESS_VOLUME", "") /= "" then
         Check_Streamless_Volume;
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
