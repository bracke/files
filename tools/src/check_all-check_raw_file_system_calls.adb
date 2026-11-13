separate (Check_All)
   procedure Check_Raw_File_System_Calls is
      --  No file is exempt: Files.Fs_Primitives' wrappers call Hostkit too.
      LF : constant Character := ASCII.LF;

      Units : constant String :=
        "ada.directories" & LF & "gnat.os_lib" & LF & "gnat.directory_operations" & LF
        & "ada.streams.stream_io" & LF & "ada.text_io";

      --  Unit and subprogram, lower case, one a line.
      Banned : constant String :=
        "ada.directories.create_directory" & LF & "ada.directories.create_path" & LF
        & "ada.directories.delete_file" & LF & "ada.directories.delete_directory" & LF
        & "ada.directories.delete_tree" & LF & "ada.directories.start_search" & LF
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
        & "ada.text_io.open" & LF & "ada.text_io.create";

      --  Every package renaming of one of Units in src/, an "alias=unit" line
      --  each: a subunit calls through its parent's renaming.
      Aliases : Unbounded_String;

      function Is_Name_Character (C : Character) return Boolean is
        (C in 'a' .. 'z' | 'A' .. 'Z' | '0' .. '9' | '_');

      procedure For_Each_Line (Text : String; Visit : not null access procedure (Line : String)) is
         First : Positive := Text'First;
      begin
         for Index in Text'Range loop
            if Text (Index) = LF then
               Visit (Text (First .. Index - 1));
               First := Index + 1;
            end if;
         end loop;
         if First <= Text'Last then
            Visit (Text (First .. Text'Last));
         end if;
      end For_Each_Line;

      --  Code (lower case) of a source in src/.
      function Lower_Code (Path : String) return String is
        (Ada.Characters.Handling.To_Lower
           (Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => True)));

      --  Whether Lower names Name whole: not as the tail of a longer name,
      --  nor followed by more of one.
      function Names (Lower, Name : String) return Boolean is
         From    : Positive := Lower'First;
         At_Name : Natural;
      begin
         loop
            At_Name := Ada.Strings.Fixed.Index (Lower (From .. Lower'Last), Name);
            exit when At_Name = 0;
            if (At_Name = Lower'First
                or else not (Is_Name_Character (Lower (At_Name - 1)) or else Lower (At_Name - 1) = '.'))
              and then (At_Name + Name'Length > Lower'Last
                        or else not Is_Name_Character (Lower (At_Name + Name'Length)))
            then
               return True;
            end if;
            exit when At_Name = Lower'Last;
            From := At_Name + 1;
         end loop;
         return False;
      end Names;

      procedure Collect_Aliases (Path : String) is
         Lower : constant String := Lower_Code (Path);

         procedure For_Unit (Unit : String) is
            Pattern   : constant String := "renames " & Unit & ";";
            From      : Positive := Lower'First;
            At_Rename : Natural;
            Last      : Natural;
            First     : Natural;
         begin
            loop
               At_Rename := Ada.Strings.Fixed.Index (Lower (From .. Lower'Last), Pattern);
               exit when At_Rename = 0;
               Last := At_Rename - 1;
               while Last >= Lower'First and then Lower (Last) in ' ' | ASCII.LF | ASCII.CR | ASCII.HT loop
                  Last := Last - 1;
               end loop;
               First := Last + 1;
               while First > Lower'First and then Is_Name_Character (Lower (First - 1)) loop
                  First := First - 1;
               end loop;
               if First <= Last
                 and then First - Lower'First >= 8
                 and then Lower (First - 8 .. First - 1) = "package "
               then
                  Append (Aliases, Lower (First .. Last) & "=" & Unit & LF);
               end if;
               exit when At_Rename + Pattern'Length > Lower'Last;
               From := At_Rename + Pattern'Length;
            end loop;
         end For_Unit;
      begin
         For_Each_Line (Units, For_Unit'Access);
      end Collect_Aliases;

      procedure Check_File (Path : String) is
         Lower : constant String := Lower_Code (Path);

         procedure Refuse (Name : String; Why : String) is
         begin
            Put_Line
              (Standard_Error,
               Path & ": " & Why & " " & Name & ", which GNAT refuses past 260 characters on Windows;"
               & " use Files.Fs_Primitives or Hostkit");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         end Refuse;

         --  Name, and Name with its unit spelled as each of the unit's aliases.
         procedure Check_Spellings (Unit, Rest : String; Why : String) is
            procedure Check_Alias (Line : String) is
               Equals : constant Natural := Ada.Strings.Fixed.Index (Line, "=");
            begin
               if Equals > 0 and then Line (Equals + 1 .. Line'Last) = Unit
                 and then Names (Lower, Line (Line'First .. Equals - 1) & Rest)
               then
                  Refuse (Line (Line'First .. Equals - 1) & Rest, Why);
               end if;
            end Check_Alias;
         begin
            if Names (Lower, Unit & Rest) then
               Refuse (Unit & Rest, Why);
            end if;
            For_Each_Line (To_String (Aliases), Check_Alias'Access);
         end Check_Spellings;

         procedure Check_Call (Line : String) is
            Dot : constant Natural := Ada.Strings.Fixed.Index (Line, ".", Ada.Strings.Backward);
         begin
            Check_Spellings (Line (Line'First .. Dot - 1), Line (Dot .. Line'Last), "calls");
         end Check_Call;

         procedure Check_Use (Unit : String) is
            Use_Clause : constant String := "use ";
         begin
            if Names (Lower, Use_Clause & Unit & ";") then
               Refuse (Unit, "uses");
            end if;
            declare
               procedure Check_Alias (Line : String) is
                  Equals : constant Natural := Ada.Strings.Fixed.Index (Line, "=");
               begin
                  if Equals > 0 and then Line (Equals + 1 .. Line'Last) = Unit
                    and then Names (Lower, Use_Clause & Line (Line'First .. Equals - 1) & ";")
                  then
                     Refuse (Line (Line'First .. Equals - 1), "uses");
                  end if;
               end Check_Alias;
            begin
               For_Each_Line (To_String (Aliases), Check_Alias'Access);
            end;
         end Check_Use;
      begin
         For_Each_Line (Banned, Check_Call'Access);
         For_Each_Line (Units, Check_Use'Access);
      end Check_File;

      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
   begin
      Ada.Directories.Start_Search
        (Search, Root & "/src", "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         Collect_Aliases (Ada.Directories.Full_Name (Item));
      end loop;
      Ada.Directories.End_Search (Search);
      Ada.Directories.Start_Search
        (Search, Root & "/src", "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         begin
            Check_File (Ada.Directories.Full_Name (Item));
         exception
            when Program_Error =>
               Ada.Directories.End_Search (Search);
               raise;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   end Check_Raw_File_System_Calls;
