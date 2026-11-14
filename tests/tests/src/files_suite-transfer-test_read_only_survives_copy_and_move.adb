with Files_Suite.Volumes;
separate (Files_Suite.Transfer)
   --  A read-only file stays read-only when copied, and when moved across
   --  devices -- where the move also syncs the copy, which on Windows means
   --  opening a read-only file for writing.
   procedure Test_Read_Only_Survives_Copy_And_Move (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Remote   : Files_Suite.Volumes.Remote_Directory;
      Source   : constant String := Join (Root, "read-only.txt");
      Copy     : constant String := Join (Root, "read-only-copy.txt");
      Paths    : Files.File_System.Drop_Import_Plan_Vectors.Vector;
      Mutation : Files.File_System.Mutation_Result;
      function Set_Read_Only_Attribute (Path : System.Address) return Interfaces.C.int
        with Import, Convention => C, External_Name => "files_test_set_read_only_attribute";

      --  Whether the file can be opened for writing.
      function Writable (Path : String) return Boolean is
         File : Ada.Streams.Stream_IO.File_Type;
      begin
         Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.Append_File, Path);
         Ada.Streams.Stream_IO.Close (File);
         return True;
      exception
         when Ada.IO_Exceptions.Use_Error | Ada.IO_Exceptions.Name_Error =>
            return False;
      end Writable;
   begin
      Reset_Root;
      Write_Binary_File (Source, "kept as is");
      if Hostkit.Host.Current = Hostkit.Host.Windows then
         --  The attribute, which GNAT's Set_Read_Only cannot set there (see
         --  files_test_metadata.c).
         declare
            Name : aliased Interfaces.C.char_array := Interfaces.C.To_C (Source);
         begin
            Assert (Set_Read_Only_Attribute (Name'Address) = 1, "the source is made read-only");
         end;
      else
         GNAT.OS_Lib.Set_Read_Only (Source);
      end if;
      if Writable (Source) then
         GNAT.OS_Lib.Set_Writable (Source);
         Files_Suite.Support.Skip
           ("Test_Read_Only_Survives_Copy_And_Move", "a read-only file is still writable here (running as root)");
         return;
      end if;
      Mutation := Files.File_System.Copy_Tree (Source, Copy);
      Assert (Mutation.Success, "a read-only file copies");
      Assert (File_Has_Bytes (Copy, "kept as is"), "and its copy has its bytes");
      Assert
        (not Writable (Copy),
         "and its copy is read-only"
         & (if Writable (Copy) then Files_Suite.Support.Access_Report (Copy) else ""));
      GNAT.OS_Lib.Set_Writable (Copy);

      Remote.Create ("files-test-read-only-");
      if Remote.Path = "" then
         GNAT.OS_Lib.Set_Writable (Source);
         Files_Suite.Support.Skip ("Test_Read_Only_Survives_Copy_And_Move", Files_Suite.Volumes.No_Other_Volume);
         return;
      end if;
      Paths.Append (Files.File_System.Drop_Import_Plan'
        (To_Unbounded_String (Source), To_Unbounded_String (Join (Remote.Path, "moved.txt")),
         Files.File_System.Drop_Move, True, Null_Unbounded_String));
      Mutation := Files.File_System.Execute_Drop_Import (Paths);
      if Ada.Directories.Exists (Source) then
         GNAT.OS_Lib.Set_Writable (Source);
      end if;
      Assert (Mutation.Success, "a read-only file moves across devices: " & To_String (Mutation.Error_Key));
      Assert (File_Has_Bytes (Join (Remote.Path, "moved.txt"), "kept as is")
              and then not Writable (Join (Remote.Path, "moved.txt")),
              "and arrives read-only");
      GNAT.OS_Lib.Set_Writable (Join (Remote.Path, "moved.txt"));
   end Test_Read_Only_Survives_Copy_And_Move;
