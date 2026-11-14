with Files_Suite.Volumes;
separate (Files_Suite.Transfer)
   procedure Test_Copy_Extended_Metadata (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Hostkit.Metadata_Copy.Entry_Times;
      function Prepare_Native (Path : System.Address; Directory : Interfaces.C.int) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_metadata_prepare";
      function Check_Native (Path : System.Address; Directory : Interfaces.C.int) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_metadata_check";
      subtype Times_Array is Hostkit.Metadata_Copy.Entry_Times;
      Source : constant String := Join (Root, "source");
      Remote : Files_Suite.Volumes.Remote_Directory;
      Original_File, Original_Directory : Times_Array;
      Mutation : Files.File_System.Mutation_Result;
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
                 "prepare extended attributes (named streams on Windows), ACL and nanosecond timestamp fixtures");
      end Prepare;
      --  The times are read first: reading the streams back could move the
      --  access time on an NTFS volume that keeps it.
      procedure Check (Path : String; Directory : Boolean; Expected : Times_Array) is
         Name   : aliased Interfaces.C.char_array := Interfaces.C.To_C (Path);
         Actual : constant Times_Array := Times_Of (Path);
      begin
         if Hostkit.Host.Current = Hostkit.Host.Windows then
            Assert (Check_Native (Name'Address, Boolean'Pos (Directory)) = 1,
                    "preserve the Zone.Identifier and a custom named stream, and a file's read-only attribute");
            --  NTFS updates a small volume's access time on every read, the
            --  copy's own verification among them: only the modification
            --  time is the copy's to keep there.
            Assert (Actual (3 .. 4) = Expected (3 .. 4), "preserve the modification timestamp");
         else
            Assert (Check_Native (Name'Address, Boolean'Pos (Directory)) = 1,
                    "preserve populated and empty extended attributes and the file ACL");
            Assert (Actual = Expected, "preserve access and modification timestamps before any read");
         end if;
      end Check;
   begin
      if Hostkit.Host.Current not in Hostkit.Host.Linux | Hostkit.Host.Windows then
         Files_Suite.Support.Skip
           ("Test_Copy_Extended_Metadata",
            "the xattr and POSIX ACL fixture is Linux C");
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
      Remote.Create ("files-test-extended-metadata-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Copy_Extended_Metadata", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      Prepare (Join (Source, "child"), False);
      Prepare (Source, True);
      Mutation := Files.File_System.Rename_Item (Source, Join (Remote.Path, "moved"));
      Assert (Mutation.Success and then not Ada.Directories.Exists (Source),
              "move the metadata tree across filesystems");
      Check (Join (Remote.Path, "moved"), True, Original_Directory);
      Check (Join (Remote.Path, "moved/child"), False, Original_File);
      --  Guarded history transitions use the same metadata-preserving fallback.
      Mutation := Files.File_System.Rename_Item
        (Join (Remote.Path, "moved"), Source,
         Files.File_Identities.Token (Join (Remote.Path, "moved")));
      Assert (Mutation.Success, "guarded cross-filesystem history move");
      Check (Source, True, Original_Directory);
      Check (Join (Source, "child"), False, Original_File);
   end Test_Copy_Extended_Metadata;
