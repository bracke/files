separate (Check_All)
   procedure Check_Raw_File_System_Calls is
      --  No file is exempt: Files.IO.Fs_Primitives' wrappers call Hostkit too.
      LF : constant Character := ASCII.LF;

      --  Unit and subprogram, lower case, one a line.
      Banned : constant String :=
        "ada.directories.create_directory" & LF & "ada.directories.create_path" & LF
        & "ada.directories.delete_file" & LF & "ada.directories.delete_directory" & LF
        & "ada.directories.delete_tree" & LF & "ada.directories.start_search" & LF
        & "ada.directories.search" & LF
        & "ada.directories.full_name" & LF & "ada.directories.kind" & LF
        & "ada.directories.exists" & LF & "ada.directories.size" & LF
        & "ada.directories.modification_time" & LF & "ada.directories.current_directory" & LF
        & "ada.directories.rename" & LF & "ada.directories.copy_file" & LF
        & "gnat.os_lib.create_new_file" & LF & "gnat.os_lib.create_file" & LF
        & "gnat.os_lib.open_read" & LF & "gnat.os_lib.open_read_write" & LF
        & "gnat.os_lib.open_append" & LF & "gnat.os_lib.delete_file" & LF
        & "gnat.os_lib.normalize_pathname" & LF & "gnat.os_lib.is_directory" & LF
        & "gnat.os_lib.is_regular_file" & LF & "gnat.os_lib.rename_file" & LF
        & "gnat.os_lib.copy_file" & LF
        & "gnat.os_lib.is_owner_readable_file" & LF & "gnat.os_lib.is_owner_writable_file" & LF
        & "gnat.directory_operations.open" & LF & "gnat.directory_operations.read" & LF
        & "gnat.directory_operations.make_dir" & LF & "gnat.directory_operations.remove_dir" & LF
        & "ada.streams.stream_io.open" & LF & "ada.streams.stream_io.create" & LF
        & "ada.text_io.open" & LF & "ada.text_io.create" & LF
        & "ada.sequential_io.open" & LF & "ada.sequential_io.create" & LF
        & "ada.direct_io.open" & LF & "ada.direct_io.create";

      --  Every package renaming or instantiation of one of the units in
      --  src/: a subunit calls through its parent's.
      Aliases : constant String := Package_Aliases (File_System_Units);

      procedure Check_File (Path : String) is
         Toks    : constant Tokens.Token_List := Tokens.Tokens_Of (Project_Tools.Files.Read_Raw_File (Path));
         Refused : Unbounded_String;

         procedure Refuse (Name : String; Why : String) is
         begin
            if not Has_Line (To_String (Refused), Name) then
               Append (Refused, Name & LF);
               Report (Path & ": " & Why & " " & Name & ", which GNAT refuses past 260 characters on Windows;"
                  & " use Files.IO.Fs_Primitives or Hostkit");
            end if;
         end Refuse;

         procedure Check_Name (Name : String; Next : Positive) is
            pragma Unreferenced (Next);
         begin
            if Has_Line (Banned, Name) then
               Refuse (Name, "calls");
            end if;
         end Check_Name;

         procedure Check_Use (Unit : String; Number : Positive) is
            pragma Unreferenced (Number);
         begin
            Refuse (Unit, "uses");
         end Check_Use;
      begin
         For_Each_Resolved_Name (Toks, Aliases, File_System_Units, Check_Name'Access);
         For_Each_Line (Used_Units (Toks, Aliases, File_System_Units), Check_Use'Access);
      end Check_File;
   begin
      for Item of Project_Tools.Files.List_Tree (Root & "/src", "*.ad?", Generated_Directories) loop
         Check_File (To_String (Item));
      end loop;
   end Check_Raw_File_System_Calls;
