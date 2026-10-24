separate (Files_Suite.Operations)
   procedure Test_Copy_Extended_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Hostkit.Metadata_Copy.Entry_Times;
      function Prepare_Native (Path : System.Address; Directory : Interfaces.C.int) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_metadata_prepare";
      function Check_Native (Path : System.Address; Directory : Interfaces.C.int) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_metadata_check";
      subtype Times_Array is Hostkit.Metadata_Copy.Entry_Times;
      Source : constant String := Join (Root, "source");
      Remote : Unbounded_String;
      Original_File, Original_Directory : Times_Array;
      Mutation : Files.File_System.Mutation_Result;
      Had_Tmp : constant Boolean := Ada.Environment_Variables.Exists ("TMPDIR");
      Old_Tmp : constant String := Ada.Environment_Variables.Value ("TMPDIR", "");
      function Times_Of (Path : String) return Times_Array is
         Values : Times_Array;
      begin
         Assert
           (Hostkit.Metadata_Copy.Capture_Times (Path, Values),
            "capture access and modification times");
         return Values;
      end Times_Of;
      procedure Prepare (Path : String; Directory : Boolean) is
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      begin
         Assert (Prepare_Native (Name'Address, Boolean'Pos (Directory)) = 1,
                 "prepare extended attributes, ACL and nanosecond timestamp fixtures");
      end Prepare;
      procedure Check (Path : String; Directory : Boolean; Expected : Times_Array) is
         Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
      begin
         Assert (Check_Native (Name'Address, Boolean'Pos (Directory)) = 1,
                 "preserve populated and empty extended attributes and the file ACL");
         Assert (Times_Of (Path) = Expected, "preserve access and modification timestamps before any read");
      end Check;
      procedure Restore_Tmp is
      begin
         if Had_Tmp then
            Ada.Environment_Variables.Set ("TMPDIR", Old_Tmp);
         else
            Ada.Environment_Variables.Clear ("TMPDIR");
         end if;
      end Restore_Tmp;
      procedure Cleanup is
      begin
         Restore_Tmp;
         if Length (Remote) > 0 then
            Project_Tools.Files.Delete_Tree (To_String (Remote));
         end if;
      end Cleanup;
   begin
      if Hostkit.Host.Current /= Hostkit.Host.Linux then
         Files_Suite.Support.Skip ("Test_Copy_Extended_Metadata", "Hostkit.Host.Current /= Hostkit.Host.Linux");
         return;
      end if;
      Reset_Root;
      Ada.Directories.Create_Directory (Source);
      Write_Binary_File (Join (Source, "child"), "metadata bytes");
      Prepare (Join (Source, "child"), False);
      Prepare (Source, True);
      Original_File := Times_Of (Join (Source, "child"));
      Original_Directory := Times_Of (Source);
      Mutation := Files.File_System.Copy_Tree (Source, Join (Root, "copy"));
      Assert (Mutation.Success, "copy extended metadata fixture");
      Check (Join (Root, "copy"), True, Original_Directory);
      Check (Join (Root, "copy/child"), False, Original_File);
      if not Ada.Directories.Exists ("/dev/shm") then
         Files_Suite.Support.Skip ("Test_Copy_Extended_Metadata", "not Ada.Directories.Exists (""/dev/shm"")");
         return;
      end if;
      Ada.Environment_Variables.Set ("TMPDIR", "/dev/shm");
      Remote := To_Unbounded_String (Hostkit.Fs.Create_Temporary_Directory ("files-test-extended-metadata-"));
      Restore_Tmp;
      if Length (Remote) = 0 then
         Files_Suite.Support.Skip ("Test_Copy_Extended_Metadata", "Length (Remote) = 0");
         return;
      end if;
      Prepare (Join (Source, "child"), False);
      Prepare (Source, True);
      Mutation := Files.File_System.Rename_Item (Source, Join (To_String (Remote), "moved"));
      Assert (Mutation.Success and then not Ada.Directories.Exists (Source),
              "move the metadata tree across filesystems");
      Check (Join (To_String (Remote), "moved"), True, Original_Directory);
      Check (Join (To_String (Remote), "moved/child"), False, Original_File);
      --  Guarded history transitions use the same metadata-preserving fallback.
      Mutation := Files.File_System.Rename_Item
        (Join (To_String (Remote), "moved"), Source,
         Files.File_Identities.Token (Join (To_String (Remote), "moved")));
      Assert (Mutation.Success, "guarded cross-filesystem history move");
      Check (Source, True, Original_Directory);
      Check (Join (Source, "child"), False, Original_File);
      Cleanup;
   exception
      when others => Cleanup; raise;
   end Test_Copy_Extended_Metadata;
