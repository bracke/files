with Files_Suite.Volumes;
separate (Files_Suite.Operations)
   procedure Test_Deep_Tree_Copy (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      use type Hostkit.Fs.Entry_Kind;
      Source : constant String := Join (Root, "source");
      Dest : constant String := Join (Root, "copy");
      Leaf : Unbounded_String;
      Relative : Unbounded_String;
      Mutation : Files.File_System.Mutation_Result;
      Settings : Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Load : Files.File_System.Directory_Load_Result;
      Remote : Files_Suite.Volumes.Remote_Directory;

      --  The fixture is built through Hostkit, which reaches past Windows'
      --  260-character limit where GNAT's own calls stop: 1025 levels of
      --  "\d" are some 2000 characters there.
      procedure Make_Directory (Path : String) is
      begin
         Assert (Hostkit.Fs.Create_Directory (Path), "make the deep fixture's folder " & Path);
      end Make_Directory;
   begin
      --  macOS refuses any path past PATH_MAX, 1024 bytes, which 1025 levels
      --  of "/d" pass; Windows' 32767 UTF-16 units hold them.
      if Hostkit.Host.Current = Hostkit.Host.MacOS then
         Files_Suite.Support.Skip
           ("Test_Deep_Tree_Copy",
            "the 1025-deep fixture passes the host's path limit");
         return;
      end if;
      Settings.Show_Hidden_Files := True;
      for Depth in 1 .. 3 loop
         Reset_Root;
         Relative := Null_Unbounded_String;
         Leaf := To_Unbounded_String (Source);
         Make_Directory (Source);
         for N in 1 .. (if Depth = 1 then 128 elsif Depth = 2 then 256 else 1_025) loop
            Append (Leaf, "/d");
            Append (Relative, "/d");
            Make_Directory (To_String (Leaf));
         end loop;
         Write_Long_Path_File (Join (To_String (Leaf), "child"), "deep bytes");
         Mutation := Files.File_System.Copy_Tree (Source, Dest);
         if Depth < 3 then
            Assert (Mutation.Success and then Long_Path_File_Is (Dest & To_String (Relative) & "/child", "deep bytes"),
                    "copying a valid deep directory tree completes without a stack overflow");
         else
            Assert (not Mutation.Success and then Hostkit.Fs.Kind_Of (Dest) = Hostkit.Fs.Missing_Entry,
                    "exceeding the traversal depth cap fails without publishing an incomplete copy");
         end if;
         Assert (Long_Path_File_Is (Join (To_String (Leaf), "child"), "deep bytes"),
                 "deep copies preserve their source");
         Load := Files.File_System.Load_Directory (Root, Settings);
         for Item of Load.Items loop
            Assert (Ada.Strings.Fixed.Index (To_String (Item.Name), ".files-work-") /= 1,
                    "deep copy success or refusal leaves no private staging tree");
         end loop;
      end loop;

      --  A cross-device move snapshots the whole source before it copies:
      --  that walk, too, must hold 1000 levels on any caller's stack.
      Remote.Create ("files-test-deep-");
      if Remote.Path = "" then
         Files_Suite.Support.Skip ("Test_Deep_Tree_Copy", Files_Suite.Volumes.No_Other_Volume);
      else
         Reset_Root;
         declare
            Paths    : Files.Types.String_Vectors.Vector;
            Plans    : Files.File_System.Drop_Import_Result;
            Moved    : Files.File_System.Mutation_Result;
         begin
            Leaf := To_Unbounded_String (Source);
            Make_Directory (Source);
            for N in 1 .. 1_000 loop
               Append (Leaf, "/d");
               Make_Directory (To_String (Leaf));
            end loop;
            Write_Long_Path_File (Join (To_String (Leaf), "child"), "deep bytes");
            Paths.Append (To_Unbounded_String (Source));
            Plans := Files.File_System.Plan_Drop_Import (Paths, Remote.Path, Files.File_System.Drop_Move);
            Moved := Files.File_System.Execute_Drop_Import (Plans.Plans);
            Assert (Moved.Success and then not Ada.Directories.Exists (Source),
                    "a 1000-level tree moves across devices");
         end;
      end if;
   end Test_Deep_Tree_Copy;
