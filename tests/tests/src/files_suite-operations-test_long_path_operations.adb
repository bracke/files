with Files.Fs_Primitives;
separate (Files_Suite.Operations)
   --  Every operation reaches a folder deeper than Windows' 260-character
   --  path limit, which GNAT's own file calls refuse there before Windows is
   --  asked: the folder is built by renaming short folders to 150-character
   --  names, and from then on only files' own operations touch it.
   procedure Test_Long_Path_Operations (T : in out AUnit.Test_Cases.Test_Case'Class) is
      pragma Unreferenced (T);
      Settings : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Long_A   : constant String := Ada.Strings.Fixed."*" (150, 'a');
      Long_B   : constant String := Ada.Strings.Fixed."*" (150, 'b');
      Top      : constant String := Join (Root, "deep");
      Middle   : constant String := Join (Top, Long_A);
      Deep     : constant String := Join (Middle, Long_B);

      --  Write Bytes to Path, a file there emptied first, past GNAT's limit.
      procedure Put (Path : String; Bytes : String) is
         File   : Ada.Streams.Stream_IO.File_Type;
         Buffer : Ada.Streams.Stream_Element_Array (1 .. Bytes'Length);
      begin
         for Index in Bytes'Range loop
            Buffer (Ada.Streams.Stream_Element_Offset (Index - Bytes'First + 1)) :=
              Ada.Streams.Stream_Element (Character'Pos (Bytes (Index)));
         end loop;
         Hostkit.Fs.Create_Stream (File, Ada.Streams.Stream_IO.Out_File, Path);
         Ada.Streams.Stream_IO.Write (File, Buffer);
         Ada.Streams.Stream_IO.Close (File);
      exception
         when others =>
            if Ada.Streams.Stream_IO.Is_Open (File) then
               Ada.Streams.Stream_IO.Close (File);
            end if;
            raise;
      end Put;

      --  The bytes of the file at Path, past GNAT's limit.
      function Got (Path : String) return String is
         File   : Ada.Streams.Stream_IO.File_Type;
         Buffer : Ada.Streams.Stream_Element_Array (1 .. 4_096);
         use type Ada.Streams.Stream_Element_Offset;
         Last   : Ada.Streams.Stream_Element_Offset;
         Result : Unbounded_String;
      begin
         Hostkit.Fs.Open_Stream (File, Ada.Streams.Stream_IO.In_File, Path);
         loop
            Ada.Streams.Stream_IO.Read (File, Buffer, Last);
            for Index in Buffer'First .. Last loop
               Append (Result, Character'Val (Buffer (Index)));
            end loop;
            exit when Last < Buffer'Last;
         end loop;
         Ada.Streams.Stream_IO.Close (File);
         return To_String (Result);
      exception
         when others =>
            if Ada.Streams.Stream_IO.Is_Open (File) then
               Ada.Streams.Stream_IO.Close (File);
            end if;
            raise;
      end Got;

      --  Whether Load_Directory lists Directory with Name in it.
      function Listed (Directory : String; Name : String) return Boolean is
         Load : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (Directory, Settings);
      begin
         return Load.Success and then (for some Item of Load.Items => To_String (Item.Name) = Name);
      end Listed;

      --  Whether Result found an item called Name.
      function Found (Result : Files.File_System.Recursive_Search_Result; Name : String) return Boolean is
        (Result.Success and then (for some Item of Result.Items => To_String (Item.Name) = Name));

      --  A model of Deep with Name selected, as a window shows it.
      procedure Show (Model : in out Files.Model.Window_Model; Name : String) is
         Load : constant Files.File_System.Directory_Load_Result :=
           Files.File_System.Load_Directory (Deep, Settings);
      begin
         Assert (Load.Success, "the deep folder loads for the window");
         Files.Model.Initialize (Model, Deep, Load.Items, Root);
         Select_Name (Model, Name);
      end Show;

      --  Copy or move Source into the folder Destination.
      procedure Import (Source : String; Destination : String; Mode : Files.File_System.Drop_Import_Mode) is
         Sources : Files.Types.String_Vectors.Vector;
         Plan    : Files.File_System.Drop_Import_Result;
      begin
         Sources.Append (To_Unbounded_String (Source));
         Plan := Files.File_System.Plan_Drop_Import (Sources, Destination, Mode);
         Assert (Plan.Success and then Natural (Plan.Plans.Length) = 1 and then Plan.Plans.First_Element.Valid,
                 "an import into the deep folder is planned");
         Assert (Files.File_System.Execute_Drop_Import (Plan.Plans).Success, "the import into the deep folder runs");
      end Import;

      procedure Check is
         Note     : constant String := Join (Deep, "note.txt");
         Tree     : constant String := Join (Deep, "tree");
         Dest     : constant String := Join (Deep, "dest");
         Moved    : constant String := Join (Deep, "moved");
         Mutation : Files.File_System.Mutation_Result;
         Model    : Files.Model.Window_Model;
         Routed   : Files.Controller.Controller_Result;
         Trashed  : Files.Types.UString;
         Target   : Unbounded_String;
      begin
         Ada.Environment_Variables.Set ("XDG_DATA_HOME", Root & "_xdg_data");
         Ada.Environment_Variables.Set ("FILES_TRASH_BACKEND", "xdg");

         --  Short names, renamed long: nothing but the rename meets the
         --  long path.
         Assert (Hostkit.Fs.Create_Directory (Top)
                 and then Hostkit.Fs.Create_Directory (Join (Top, "a"))
                 and then Hostkit.Fs.Move_No_Replace (Join (Top, "a"), Middle)
                 and then Hostkit.Fs.Create_Directory (Join (Middle, "b"))
                 and then Hostkit.Fs.Move_No_Replace (Join (Middle, "b"), Deep),
                 "the deep folder is built by renaming short folders long");
         Assert (Deep'Length > 300, "the folder lies more than 300 characters deep");

         --  Listed, empty.
         declare
            Load : constant Files.File_System.Directory_Load_Result :=
              Files.File_System.Load_Directory (Deep, Settings);
         begin
            Assert (Load.Success and then Load.Items.Is_Empty, "the empty deep folder is listed");
         end;

         --  A file and a folder made in it.
         Assert (Files.File_System.Create_Empty_File (Note).Success, "a file is created in the deep folder");
         Put (Note, "long path note");
         Assert_Equal (Got (Note), "long path note", "the deep file holds what was written");
         Assert (Files.File_System.Create_Directory (Tree).Success
                 and then Files.File_System.Create_Directory (Join (Tree, "sub")).Success,
                 "folders are created in the deep folder");
         Put (Join (Tree, "inner.txt"), "inner bytes");
         Put (Join (Join (Tree, "sub"), "leaf.txt"), "leaf bytes");
         Assert (Listed (Deep, "note.txt") and then Listed (Deep, "tree"), "the deep folder lists what was made");

         --  A folder tree copied, then moved, on one volume.
         Assert (Files.File_System.Create_Directory (Dest).Success
                 and then Files.File_System.Create_Directory (Moved).Success,
                 "the copy and move destinations are made");
         Import (Tree, Dest, Files.File_System.Drop_Copy);
         Assert_Equal (Got (Join (Join (Join (Dest, "tree"), "sub"), "leaf.txt")), "leaf bytes",
                       "the copied tree holds its deepest file");
         Assert (Files.Fs_Primitives.File_Exists (Join (Join (Tree, "sub"), "leaf.txt")),
                 "the copy leaves its source");
         Import (Join (Dest, "tree"), Moved, Files.File_System.Drop_Move);
         Assert (not Files.Fs_Primitives.Entry_Exists (Join (Dest, "tree")), "the move leaves no source");
         Assert_Equal (Got (Join (Join (Moved, "tree"), "inner.txt")), "inner bytes", "the moved tree holds its files");

         --  Duplicated through the window's command.
         Show (Model, "note.txt");
         Routed := Files.Controller.Execute_Non_Settings_Command
           (Files.Commands.Duplicate_Selected_Command, Model, Settings);
         Assert_Equal (Routed.Operation.Status, Files.Operations.Operation_Success, "the deep file is duplicated");
         Assert_Equal
           (Got (Join (Deep, "note (copy).txt")), "long path note", "the duplicate holds the original's bytes");

         --  Renamed, and renamed again in case alone.
         Mutation := Files.File_System.Rename_Item (Join (Deep, "note (copy).txt"), Join (Deep, "renamed.txt"));
         Assert (Mutation.Success, "the duplicate is renamed in the deep folder");
         Mutation := Files.File_System.Rename_Item (Join (Deep, "renamed.txt"), Join (Deep, "Renamed.txt"));
         Assert (Mutation.Success, "a case-only rename works in the deep folder");
         Assert (Listed (Deep, "Renamed.txt") and then not Listed (Deep, "renamed.txt"),
                 "the folder lists the new spelling only");
         Assert_Equal (Got (Join (Deep, "Renamed.txt")), "long path note", "the renamed file keeps its bytes");

         --  Linked: a hard link everywhere, a symbolic link where the host
         --  makes one.
         Assert (Files.File_System.Create_Hard_Link (Note, Join (Deep, "note hard.txt")).Success,
                 "a hard link is made in the deep folder");
         Assert_Equal (Got (Join (Deep, "note hard.txt")), "long path note", "the hard link reads as its file");
         if Files.File_System.Create_Symbolic_Link ("note.txt", Join (Deep, "note link")).Success then
            Assert (Hostkit.Fs.Is_Link (Join (Deep, "note link"))
                    and then Hostkit.Fs.Read_Link_Target (Join (Deep, "note link"), Target)
                    and then To_String (Target) = "note.txt",
                    "the deep symbolic link names its target");
         else
            Link_Not_Made ("Test_Long_Path_Operations");
         end if;

         --  Measured.
         declare
            Size : constant Files.File_System.Directory_Size_Result := Files.File_System.Directory_Size (Moved);
         begin
            Assert (Size.Available and then not Size.Capped, "the deep folder is measured");
            Assert_Equal (Size.File_Count, 2, "the deep folder holds two files");
            Assert_Equal (Size.Total_Bytes, Long_Long_Integer'(21), "the deep folder holds 21 bytes");
         end;

         --  Searched by name and by content.
         Assert (Found (Files.File_System.Search_Recursive (Deep, "leaf", Settings), "leaf.txt"),
                 "a name search finds the deepest file");
         Assert (Found (Files.File_System.Search_Contents (Deep, "inner bytes", Settings), "inner.txt"),
                 "a content search reads the deep files");

         --  Compressed through the window's command, the original deleted for
         --  good, and extracted back.
         Show (Model, "moved");
         Routed := Files.Controller.Execute_Non_Settings_Command
           (Files.Commands.Compress_Zip_Command, Model, Settings);
         Assert_Equal (Routed.Operation.Status, Files.Operations.Operation_Success, "the deep folder is compressed");
         declare
            Archive : constant String := Got (Join (Deep, "moved.zip"));
         begin
            Assert (Archive'Length > 4 and then Archive (Archive'First .. Archive'First + 1) = "PK",
                    "the archive is a zip");
         end;
         Mutation := Files.File_System.Delete_Permanently (Moved);
         Assert (Mutation.Success and then not Files.Fs_Primitives.Entry_Exists (Moved),
                 "the deep folder is deleted permanently");
         Show (Model, "moved.zip");
         Routed := Files.Controller.Execute_Non_Settings_Command
           (Files.Commands.Extract_Archive_Command, Model, Settings);
         Assert_Equal (Routed.Operation.Status, Files.Operations.Operation_Success, "the deep archive is extracted");
         Assert_Equal (Got (Join (Join (Join (Join (Moved, "moved"), "tree"), "sub"), "leaf.txt")), "leaf bytes",
                       "the extracted tree holds its deepest file");

         --  To the trash and back.
         Mutation := Files.File_System.Move_To_Trash (Note, Trashed);
         Assert (Mutation.Success and then not Files.Fs_Primitives.Entry_Exists (Note),
                 "the deep file goes to the trash");
         Mutation := Files.File_System.Restore_From_Trash (To_String (Trashed));
         Assert (Mutation.Success, "the deep file is restored");
         Assert_Equal (Got (Note), "long path note", "the restored file is back with its bytes");

         --  Gone for good, the whole tree.
         Mutation := Files.File_System.Delete_Permanently (Top);
         Assert (Mutation.Success and then not Files.Fs_Primitives.Entry_Exists (Top),
                 "the deep tree is deleted permanently");
      exception
         when others =>
            Files.Fs_Primitives.Delete_Tree (Top);
            raise;
      end Check;
   begin
      With_Trash_Environment (Check'Access);
   end Test_Long_Path_Operations;
