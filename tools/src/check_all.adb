with Ada.Command_Line;
with Ada.Characters.Handling;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Hash;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.OS_Lib;

with Project_Tools.Ada_Source;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Text;
use Project_Tools.Ada_Source;
use Project_Tools.Text;

procedure Check_All is
   use Ada.Strings.Unbounded;
   use Ada.Text_IO;
   use type Ada.Directories.File_Kind;

   Max_Line_Length : constant Natural := 120;

   function Project_Root return String is
      Here : constant String := Ada.Directories.Current_Directory;
   begin
      if Ada.Directories.Exists (Here & "/files.gpr") then
         return Here;
      elsif Ada.Directories.Exists (Here & "/../files.gpr") then
         return Ada.Directories.Full_Name (Here & "/..");
      else
         return Here;
      end if;
   end Project_Root;

   Root : constant String := Project_Root;
   --  The AUnit suite was split from one files_suite.adb into per-section
   --  bodies; contract checks search this combined snapshot so an assertion
   --  may live in any section. Written once at startup (see main body).
   Combined_Suite : constant String := Root & "/tools/obj/check_all_combined_suite.txt";
   Alr  : constant String := Project_Tools.Processes.Locate_Command ("alr");

   function Is_Text_Project_File (Name : String) return Boolean is
   begin
      return Name = ".gitignore"
        or else Ends_With (Name, ".adb")
        or else Ends_With (Name, ".ads")
        or else Ends_With (Name, ".gpr")
        or else Ends_With (Name, ".h")
        or else Ends_With (Name, ".toml")
        or else Ends_With (Name, ".catalog")
        or else Ends_With (Name, ".desktop")
        or else Ends_With (Name, ".icon")
        or else Ends_With (Name, ".manifest")
        or else Ends_With (Name, ".xml")
        or else Ends_With (Name, ".svg");
   end Is_Text_Project_File;

   function Is_Generated_Directory_Name (Name : String) return Boolean is
   begin
      return Name = "bin" or else Name = "obj";
   end Is_Generated_Directory_Name;

   procedure Require_Command (Name : String) is
   begin
      Project_Tools.Processes.Require_Command
        (Name,
         Name & " is required for the files project check tool");
   end Require_Command;

   procedure Run
     (Label   : String;
      Dir     : String;
      Program : String;
      Args    : GNAT.OS_Lib.Argument_List;
      Quiet   : Boolean := False) renames Project_Tools.Processes.Run;

   procedure Run_And_Require_Output
     (Label           : String;
      Dir             : String;
      Program         : String;
      Args            : GNAT.OS_Lib.Argument_List;
      Output_Path     : String;
      Required_First  : String;
      Required_Second : String)
   is
      Previous    : constant String := Ada.Directories.Current_Directory;
      Spawned     : Boolean := False;
      Status      : Integer := -1;
      Output_Text : Unbounded_String;
   begin
      Project_Tools.Files.Delete_File_If_Present (Output_Path);

      Ada.Directories.Set_Directory (Dir);
      GNAT.OS_Lib.Spawn
        (Program_Name => Program,
         Args         => Args,
         Output_File  => Output_Path,
         Success      => Spawned,
         Return_Code  => Status,
         Err_To_Out   => True);
      Ada.Directories.Set_Directory (Previous);

      if not Spawned or else Status /= 0 then
         Put_Line
           (Standard_Error,
            Label & " failed with status" & Integer'Image (Status));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;

      Output_Text := Project_Tools.Text.Read_Text_File (Output_Path);
      if not Project_Tools.Text.Contains (To_String (Output_Text), Required_First)
        or else not Project_Tools.Text.Contains (To_String (Output_Text), Required_Second)
      then
         Put_Line
           (Standard_Error,
            Label & " output is missing expected CLI help text");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;

      Project_Tools.Files.Delete_File_If_Present (Output_Path);
   exception
      when others =>
         if Ada.Directories.Current_Directory /= Previous then
            Ada.Directories.Set_Directory (Previous);
         end if;
         raise;
   end Run_And_Require_Output;

   --  Concatenate the aggregator and every split section body of the AUnit
   --  suite, so contract checks can assert against the suite as a whole.
   function Suite_Sources return String is
      Dir    : constant String := Root & "/tests/tests/src/";
      Result : Unbounded_String;

      procedure Add (Name : String) is
      begin
         Append (Result, Project_Tools.Text.Read_Text_File (Dir & Name));
         Append (Result, ASCII.LF);
      end Add;
   begin
      Add ("files_suite.adb");
      Add ("files_suite-startup.adb");
      Add ("files_suite-model.adb");
      Add ("files_suite-commands.adb");
      Add ("files_suite-settings.adb");
      Add ("files_suite-operations.adb");
      Add ("files_suite-rendering.adb");
      Add ("files_suite-support.adb");
      return To_String (Result);
   end Suite_Sources;

   procedure Check_CLDR_Importer is
   begin
      Run_And_Require_Output
        (Label           => "CLDR catalog importer fixture",
         Dir             => Root,
         Program         => Root & "/tools/bin/cldr_to_catalog",
         Args            =>
           [1 => new String'(Root & "/tools/testdata/cldr/main/zz.xml")],
         Output_Path     => "/tmp/files_cldr_to_catalog_fixture.out",
         Required_First  => "zz-ZZ.time.locale.datetime_pattern = %d %b %Y at %H.%M.%S",
         Required_Second => "zz-ZZ.details.size.unit.mib = zmb");
   end Check_CLDR_Importer;

   procedure Check_Line_Lengths_In_File (Path : String) is
      Content : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Line    : Natural := 1;
      Column  : Natural := 0;
   begin
      for Char of Content loop
         if Char = ASCII.LF then
            Line := Line + 1;
            Column := 0;
         else
            Column := Column + 1;
            if Column > Max_Line_Length then
               Put_Line
                 (Standard_Error,
                  Path & ":" & Natural'Image (Line) & ": line exceeds"
                  & Natural'Image (Max_Line_Length) & " characters");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end if;
      end loop;
   end Check_Line_Lengths_In_File;

   procedure Check_Line_Lengths_In_Tree (Path : String);

   procedure Check_Line_Lengths_In_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if Project_Tools.Files.File_Exists (Path) then
         Check_Line_Lengths_In_File (Path);
         return;
      elsif not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name /= "." and then Name /= ".." then
               case Ada.Directories.Kind (Dir_Entry) is
                  when Ada.Directories.Ordinary_File =>
                     if Is_Text_Project_File (Name) then
                        Check_Line_Lengths_In_File (Full);
                     end if;
                  when Ada.Directories.Directory =>
                     if not Is_Generated_Directory_Name (Name) then
                        Check_Line_Lengths_In_Tree (Full);
                     end if;
                  when Ada.Directories.Special_File =>
                     null;
               end case;
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_Line_Lengths_In_Tree;

   procedure Check_Line_Lengths is
   begin
      Check_Line_Lengths_In_Tree (Root & "/config");
      Check_Line_Lengths_In_Tree (Root & "/src");
      Check_Line_Lengths_In_Tree (Root & "/tests/tests/src");
      Check_Line_Lengths_In_Tree (Root & "/tools/config");
      Check_Line_Lengths_In_Tree (Root & "/tools/src");
      Check_Line_Lengths_In_Tree (Root & "/share");
      Check_Line_Lengths_In_File (Root & "/.gitignore");
      Check_Line_Lengths_In_File (Root & "/alire.toml");
      Check_Line_Lengths_In_File (Root & "/tests/alire.toml");
      Check_Line_Lengths_In_File (Root & "/tests/tests/alire.toml");
      Check_Line_Lengths_In_File (Root & "/files.gpr");
      Check_Line_Lengths_In_File (Root & "/tests/tests.gpr");
      Check_Line_Lengths_In_File (Root & "/tests/tests/tests.gpr");
      Check_Line_Lengths_In_File (Root & "/tools/alire.toml");
      Check_Line_Lengths_In_File (Root & "/tools/files_check_all.gpr");
   end Check_Line_Lengths;

   procedure Check_Consecutive_Empty_Lines_In_File (Path : String) is
      Content     : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Line_Number : Natural := 1;
      Line_Start  : Positive := Content'First;
      Empty_Run   : Natural := 0;

      procedure Check_Line (Raw : String) is
      begin
         if Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both) = "" then
            Empty_Run := Empty_Run + 1;
            if Empty_Run > 1 then
               Put_Line
                 (Standard_Error,
                  Path & ":" & Natural'Image (Line_Number) & ": multiple consecutive empty lines");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         else
            Empty_Run := 0;
         end if;
      end Check_Line;
   begin
      if Content = "" then
         return;
      end if;

      for Index in Content'Range loop
         if Content (Index) = ASCII.LF then
            Check_Line (Content (Line_Start .. Index - 1));
            Line_Number := Line_Number + 1;
            Line_Start := Index + 1;
         end if;
      end loop;

      if Line_Start <= Content'Last then
         Check_Line (Content (Line_Start .. Content'Last));
      end if;
   end Check_Consecutive_Empty_Lines_In_File;

   procedure Check_Consecutive_Empty_Lines_In_Tree (Path : String);

   procedure Check_Consecutive_Empty_Lines_In_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if Project_Tools.Files.File_Exists (Path) then
         Check_Consecutive_Empty_Lines_In_File (Path);
         return;
      elsif not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name /= "." and then Name /= ".." then
               case Ada.Directories.Kind (Dir_Entry) is
                  when Ada.Directories.Ordinary_File =>
                     if Is_Text_Project_File (Name) then
                        Check_Consecutive_Empty_Lines_In_File (Full);
                     end if;
                  when Ada.Directories.Directory =>
                     if not Is_Generated_Directory_Name (Name) then
                        Check_Consecutive_Empty_Lines_In_Tree (Full);
                     end if;
                  when Ada.Directories.Special_File =>
                     null;
               end case;
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_Consecutive_Empty_Lines_In_Tree;

   procedure Check_Consecutive_Empty_Lines is
   begin
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/config");
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/src");
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/tests/tests/src");
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/tools/config");
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/tools/src");
      Check_Consecutive_Empty_Lines_In_Tree (Root & "/share");
      Check_Consecutive_Empty_Lines_In_File (Root & "/.gitignore");
      Check_Consecutive_Empty_Lines_In_File (Root & "/alire.toml");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tests/alire.toml");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tests/tests/alire.toml");
      Check_Consecutive_Empty_Lines_In_File (Root & "/files.gpr");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tests/tests.gpr");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tests/tests/tests.gpr");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tools/alire.toml");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tools/files_check_all.gpr");
   end Check_Consecutive_Empty_Lines;

   function Is_Whitespace_Checked_File (Name : String) return Boolean is
   begin
      return Name = ".gitignore"
        or else Ends_With (Name, ".adb")
        or else Ends_With (Name, ".ads")
        or else Ends_With (Name, ".gpr")
        or else Ends_With (Name, ".h")
        or else Ends_With (Name, ".toml")
        or else Ends_With (Name, ".desktop")
        or else Ends_With (Name, ".icon")
        or else Ends_With (Name, ".manifest")
        or else Ends_With (Name, ".xml")
        or else Ends_With (Name, ".svg");
   end Is_Whitespace_Checked_File;

   procedure Check_Whitespace_In_File (Path : String) is
      Content     : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Line_Number : Natural := 1;
      Line_Start  : Positive := Content'First;

      procedure Fail (Message : String) is
      begin
         Put_Line
           (Standard_Error,
            Path & ":" & Natural'Image (Line_Number) & ": " & Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Fail;

      procedure Check_Line (Raw : String) is
      begin
         if Raw'Length = 0 then
            return;
         end if;

         for Character_Value of Raw loop
            if Character_Value = ASCII.HT then
               Fail ("tab character is not allowed");
            end if;
         end loop;

         if Raw (Raw'Last) = ' ' or else Raw (Raw'Last) = ASCII.HT then
            Fail ("trailing whitespace is not allowed");
         end if;
      end Check_Line;
   begin
      if Content = "" then
         return;
      end if;

      for Index in Content'Range loop
         if Content (Index) = ASCII.LF then
            Check_Line (Content (Line_Start .. Index - 1));
            Line_Number := Line_Number + 1;
            Line_Start := Index + 1;
         end if;
      end loop;

      if Line_Start <= Content'Last then
         Check_Line (Content (Line_Start .. Content'Last));
      end if;
   end Check_Whitespace_In_File;

   procedure Check_Whitespace_In_Tree (Path : String);

   procedure Check_Whitespace_In_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if Project_Tools.Files.File_Exists (Path) then
         Check_Whitespace_In_File (Path);
         return;
      elsif not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name /= "." and then Name /= ".." then
               case Ada.Directories.Kind (Dir_Entry) is
                  when Ada.Directories.Ordinary_File =>
                     if Is_Whitespace_Checked_File (Name) then
                        Check_Whitespace_In_File (Full);
                     end if;
                  when Ada.Directories.Directory =>
                     if not Is_Generated_Directory_Name (Name) then
                        Check_Whitespace_In_Tree (Full);
                     end if;
                  when Ada.Directories.Special_File =>
                     null;
               end case;
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_Whitespace_In_Tree;

   procedure Check_Whitespace is
   begin
      Check_Whitespace_In_Tree (Root & "/config");
      Check_Whitespace_In_Tree (Root & "/src");
      Check_Whitespace_In_Tree (Root & "/tests/tests/src");
      Check_Whitespace_In_Tree (Root & "/tools/config");
      Check_Whitespace_In_Tree (Root & "/tools/src");
      Check_Whitespace_In_Tree (Root & "/share");
      Check_Whitespace_In_File (Root & "/.gitignore");
      Check_Whitespace_In_File (Root & "/alire.toml");
      Check_Whitespace_In_File (Root & "/tests/.gitignore");
      Check_Whitespace_In_File (Root & "/tests/alire.toml");
      Check_Whitespace_In_File (Root & "/tests/tests/alire.toml");
      Check_Whitespace_In_File (Root & "/files.gpr");
      Check_Whitespace_In_File (Root & "/tests/tests.gpr");
      Check_Whitespace_In_File (Root & "/tests/tests/tests.gpr");
      Check_Whitespace_In_File (Root & "/tools/alire.toml");
      Check_Whitespace_In_File (Root & "/tools/files_check_all.gpr");
   end Check_Whitespace;

   function Is_Subprogram_Spec_Line (Line : String) return Boolean is
   begin
      return
        Starts_With (Line, "function ")
        or else Starts_With (Line, "procedure ")
        or else Starts_With (Line, "overriding function ")
        or else Starts_With (Line, "overriding procedure ");
   end Is_Subprogram_Spec_Line;

   procedure Check_GNATdoc_In_File (Path : String) is
      Content      : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Line_Number  : Natural := 1;
      Line_Start   : Positive := Content'First;
      Previous     : Unbounded_String;
      Comment_Text : Unbounded_String;
      Pending_Subprogram  : Boolean := False;
      Pending_Is_Function : Boolean := False;
      Pending_Has_Param   : Boolean := False;
      Pending_Comments    : Unbounded_String;
      Pending_Declaration : Unbounded_String;

      procedure Fail (Message : String) is
      begin
         Put_Line (Standard_Error, Path & ":" & Natural'Image (Line_Number) & ": " & Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Fail;

      procedure Finish_Pending is
         Comments : constant String := To_String (Pending_Comments);
         Declaration : constant String := To_String (Pending_Declaration);

         function Documented_Param (Name : String) return Boolean is
            Marker      : constant String := "@param " & Name;
            Search_From : Positive := Comments'First;
         begin
            loop
               declare
                  Found : constant Natural :=
                    Ada.Strings.Fixed.Index
                      (Source  => Comments,
                       Pattern => Marker,
                       From    => Search_From);
               begin
                  if Found = 0 then
                     return False;
                  elsif Found + Marker'Length > Comments'Last
                    or else not
                      ((Comments (Found + Marker'Length) >= 'A'
                        and then Comments (Found + Marker'Length) <= 'Z')
                       or else (Comments (Found + Marker'Length) >= 'a'
                                and then Comments (Found + Marker'Length) <= 'z')
                       or else (Comments (Found + Marker'Length) >= '0'
                                and then Comments (Found + Marker'Length) <= '9')
                       or else Comments (Found + Marker'Length) = '_')
                  then
                     return True;
                  end if;

                  Search_From := Found + Marker'Length;
               end;
            end loop;
         end Documented_Param;

         procedure Check_Param_Group (Text : String) is
            Colon : constant Natural := Ada.Strings.Fixed.Index (Text, ":");
            Start : Positive := Text'First;

            procedure Check_Name (Raw : String) is
               Name : constant String := Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
            begin
               if Name /= "" and then not Documented_Param (Name) then
                  Fail ("GNATdoc comment is missing @param " & Name);
               end if;
            end Check_Name;
         begin
            if Colon = 0 then
               return;
            end if;

            for Index in Text'First .. Colon - 1 loop
               if Text (Index) = ',' then
                  Check_Name (Text (Start .. Index - 1));
                  Start := Index + 1;
               end if;
            end loop;

            if Start <= Colon - 1 then
               Check_Name (Text (Start .. Colon - 1));
            end if;
         end Check_Param_Group;

         procedure Check_Param_Names is
            Open_Pos  : constant Natural := Ada.Strings.Fixed.Index (Declaration, "(");
            Close_Pos : constant Natural :=
              Ada.Strings.Fixed.Index
                (Declaration,
                 ")",
                 Going => Ada.Strings.Backward);
            Start     : Positive;
         begin
            if Open_Pos = 0 or else Close_Pos = 0 or else Close_Pos <= Open_Pos then
               return;
            end if;

            Start := Open_Pos + 1;

            for Index in Open_Pos + 1 .. Close_Pos - 1 loop
               if Declaration (Index) = ';' then
                  Check_Param_Group (Declaration (Start .. Index - 1));
                  Start := Index + 1;
               end if;
            end loop;

            if Start <= Close_Pos - 1 then
               Check_Param_Group (Declaration (Start .. Close_Pos - 1));
            end if;
         end Check_Param_Names;
      begin
         if Pending_Is_Function and then not Contains (Comments, "@return") then
            Fail ("function GNATdoc comment is missing @return");
         elsif Pending_Has_Param and then not Contains (Comments, "@param") then
            Fail ("parameterized GNATdoc comment is missing @param");
         end if;

         if Pending_Has_Param then
            Check_Param_Names;
         end if;

         Pending_Subprogram := False;
         Pending_Is_Function := False;
         Pending_Has_Param := False;
         Pending_Comments := Null_Unbounded_String;
         Pending_Declaration := Null_Unbounded_String;
      end Finish_Pending;

      procedure Check_Line (Raw : String) is
         Line      : constant String := Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
         Prior     : constant String := To_String (Previous);
         Comments  : constant String := To_String (Comment_Text);
         Is_Func   : constant Boolean :=
           Starts_With (Line, "function ") or else Starts_With (Line, "overriding function ");
         Has_Param : constant Boolean := Contains (Line, "(");
      begin
         if Is_Subprogram_Spec_Line (Line) then
            if not Starts_With (Prior, "--") then
               Fail ("subprogram spec is missing preceding GNATdoc comment");
            end if;

            Pending_Subprogram := True;
            Pending_Is_Function := Is_Func;
            Pending_Has_Param := Has_Param;
            Pending_Comments := To_Unbounded_String (Comments);
            Pending_Declaration := To_Unbounded_String (Line);
         elsif Pending_Subprogram and then Line /= "" and then not Starts_With (Line, "--") then
            Pending_Has_Param := Pending_Has_Param or else Has_Param;
            Append (Pending_Declaration, " ");
            Append (Pending_Declaration, Line);
         end if;

         if Pending_Subprogram and then Contains (Line, ";") then
            Finish_Pending;
         end if;

         if Starts_With (Line, "--") then
            Append (Comment_Text, Line);
            Append (Comment_Text, ASCII.LF);
         elsif Line /= "" then
            Comment_Text := Null_Unbounded_String;
         end if;

         if Line /= "" then
            Previous := To_Unbounded_String (Line);
         end if;
      end Check_Line;
   begin
      if Content = "" then
         return;
      end if;

      for Index in Content'Range loop
         if Content (Index) = ASCII.LF then
            Check_Line (Content (Line_Start .. Index - 1));
            Line_Number := Line_Number + 1;
            Line_Start := Index + 1;
         end if;
      end loop;

      if Line_Start <= Content'Last then
         Check_Line (Content (Line_Start .. Content'Last));
      end if;
   end Check_GNATdoc_In_File;

   procedure Check_GNATdoc_In_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name = "." or else Name = ".." then
               null;
            elsif Ada.Directories.Kind (Dir_Entry) = Ada.Directories.Directory then
               if not Is_Generated_Directory_Name (Name) then
                  Check_GNATdoc_In_Tree (Full);
               end if;
            elsif Name'Length >= 4 and then Name (Name'Last - 3 .. Name'Last) = ".ads" then
               Check_GNATdoc_In_File (Full);
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_GNATdoc_In_Tree;

   procedure Check_GNATdoc_Comments is
   begin
      Check_GNATdoc_In_Tree (Root & "/src");
      Check_GNATdoc_In_Tree (Root & "/tests/tests/src");
      Check_GNATdoc_In_Tree (Root & "/tools/src");
   end Check_GNATdoc_Comments;

   procedure Check_Ada_Keyword_Identifier_In_File (Path : String) is
      Content     : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Line_Number : Natural := 1;
      Line_Start  : Positive := Content'First;

      procedure Fail (Name : String) is
      begin
         Put_Line
           (Standard_Error,
            Path & ":" & Natural'Image (Line_Number)
            & ": Ada reserved word used as identifier: " & Name);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Fail;

      procedure Check_Name (Name : String) is
      begin
         if Name /= "" and then Is_Ada_Reserved_Word (Name) then
            Fail (Name);
         end if;
      end Check_Name;

      procedure Check_Line (Raw : String) is
         Line     : constant String := Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
         Colon    : constant Natural := Ada.Strings.Fixed.Index (Line, ":");
         Assign   : constant Natural := Ada.Strings.Fixed.Index (Line, "=>");
      begin
         if Line = "" or else Starts_With (Line, "--") then
            return;
         elsif Starts_With (Line, "overriding function ") then
            Check_Name (Token_After (Line, "overriding function "));
         elsif Starts_With (Line, "overriding procedure ") then
            Check_Name (Token_After (Line, "overriding procedure "));
         elsif Starts_With (Line, "function ") then
            Check_Name (Token_After (Line, "function "));
         elsif Starts_With (Line, "procedure ") then
            Check_Name (Token_After (Line, "procedure "));
         elsif Starts_With (Line, "type ") then
            Check_Name (Token_After (Line, "type "));
         elsif Starts_With (Line, "subtype ") then
            Check_Name (Token_After (Line, "subtype "));
         elsif Starts_With (Line, "package body ") then
            null;
         elsif Starts_With (Line, "package ") then
            Check_Name (Token_After (Line, "package "));
         elsif Colon > 0 and then (Assign = 0 or else Colon < Assign) then
            declare
               Name : constant String :=
                 Ada.Strings.Fixed.Trim (Line (Line'First .. Colon - 1), Ada.Strings.Both);
            begin
               if Is_Single_Identifier (Name) then
                  Check_Name (Name);
               end if;
            end;
         end if;
      end Check_Line;
   begin
      if Content = "" then
         return;
      end if;

      for Index in Content'Range loop
         if Content (Index) = ASCII.LF then
            Check_Line (Content (Line_Start .. Index - 1));
            Line_Number := Line_Number + 1;
            Line_Start := Index + 1;
         end if;
      end loop;

      if Line_Start <= Content'Last then
         Check_Line (Content (Line_Start .. Content'Last));
      end if;
   end Check_Ada_Keyword_Identifier_In_File;

   procedure Check_Ada_Keyword_Identifiers_In_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name = "." or else Name = ".." then
               null;
            elsif Ada.Directories.Kind (Dir_Entry) = Ada.Directories.Directory then
               if not Is_Generated_Directory_Name (Name) then
                  Check_Ada_Keyword_Identifiers_In_Tree (Full);
               end if;
            elsif Name'Length >= 4
              and then (Name (Name'Last - 3 .. Name'Last) = ".ads"
                        or else Name (Name'Last - 3 .. Name'Last) = ".adb")
            then
               Check_Ada_Keyword_Identifier_In_File (Full);
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_Ada_Keyword_Identifiers_In_Tree;

   procedure Check_Ada_Keyword_Identifiers is
   begin
      Check_Ada_Keyword_Identifiers_In_Tree (Root & "/src");
      Check_Ada_Keyword_Identifiers_In_Tree (Root & "/tests/tests/src");
      Check_Ada_Keyword_Identifiers_In_Tree (Root & "/tools/src");
   end Check_Ada_Keyword_Identifiers;

   procedure Check_AUnit_Test_Registration is
      package Test_Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type        => String,
         Hash                => Ada.Strings.Hash,
         Equivalent_Elements => "=");

      Path       : constant String := Combined_Suite;
      All_Suites : constant String := Root & "/tests/tests/src/all_suites.adb";
      Runner     : constant String := Root & "/tests/tests/src/tests.adb";
      Content    : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Declared   : Test_Name_Sets.Set;
      Registered : Test_Name_Sets.Set;
      Case_Types : Test_Name_Sets.Set;
      Suite_Cases : Test_Name_Sets.Set;

      procedure Fail (Message : String) is
      begin
         Put_Line (Standard_Error, Path & ": " & Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Fail;

      procedure Check_Line (Raw : String) is
         Line : constant String := Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
         Name : constant String := Token_After (Line, "procedure ");
      begin
         if Starts_With (Name, "Test_") then
            Declared.Include (Name);
         elsif Starts_With (Line, "type ")
           and then Ada.Strings.Fixed.Index (Line, " is new AUnit.Test_Cases.Test_Case") /= 0
         then
            declare
               Case_Name : constant String := Token_After (Line, "type ");
            begin
               if Case_Name /= "" then
                  Case_Types.Include (Case_Name);
               end if;
            end;
         end if;
      end Check_Line;

      procedure Collect_Declared_Tests is
         Line_Start : Positive := Content'First;
      begin
         if Content = "" then
            return;
         end if;

         for Index in Content'Range loop
            if Content (Index) = ASCII.LF then
               Check_Line (Content (Line_Start .. Index - 1));
               Line_Start := Index + 1;
            end if;
         end loop;

         if Line_Start <= Content'Last then
            Check_Line (Content (Line_Start .. Content'Last));
         end if;
      end Collect_Declared_Tests;

      procedure Collect_Registered_Tests is
         Search_From : Positive := Content'First;
      begin
         loop
            declare
               Found : constant Natural :=
                 Ada.Strings.Fixed.Index
                   (Source  => Content,
                    Pattern => "Test_",
                    From    => Search_From);
            begin
               exit when Found = 0;

               declare
                  Stop : Natural := Found;
               begin
                  while Stop <= Content'Last and then Is_Identifier_Character (Content (Stop)) loop
                     Stop := Stop + 1;
                  end loop;

                  if Stop + 6 <= Content'Last
                    and then Content (Stop .. Stop + 6) = "'Access"
                  then
                     declare
                        Name : constant String := Content (Found .. Stop - 1);
                     begin
                        if Registered.Contains (Name) then
                           Fail ("AUnit Test_* routine is registered more than once: " & Name);
                        end if;

                        Registered.Include (Name);
                     end;
                  end if;

                  Search_From := Natural'Min (Stop + 1, Content'Last);
               end;
            end;
         end loop;
      end Collect_Registered_Tests;

      procedure Collect_Suite_Cases is
         Marker      : constant String := "Result.Add_Test (new ";
         Search_From : Positive := Content'First;
      begin
         loop
            declare
               Found : constant Natural :=
                 Ada.Strings.Fixed.Index
                   (Source  => Content,
                    Pattern => Marker,
                    From    => Search_From);
            begin
               exit when Found = 0;

               declare
                  Start : constant Natural := Found + Marker'Length;
                  Stop  : Natural := Start;
               begin
                  while Stop <= Content'Last and then Is_Identifier_Character (Content (Stop)) loop
                     Stop := Stop + 1;
                  end loop;

                  if Stop > Start then
                     declare
                        Name : constant String := Content (Start .. Stop - 1);
                     begin
                        if Suite_Cases.Contains (Name) then
                           Fail ("AUnit test case type is added to Suite more than once: " & Name);
                        end if;

                        Suite_Cases.Include (Name);
                     end;
                  end if;

                  Search_From := Natural'Min (Stop + 1, Content'Last);
               end;
            end;
         end loop;
      end Collect_Suite_Cases;
   begin
      Collect_Declared_Tests;
      Collect_Registered_Tests;
      Collect_Suite_Cases;

      if Declared.Is_Empty then
         Fail ("AUnit suite declares no Test_* routines");
      end if;

      if Case_Types.Is_Empty then
         Fail ("AUnit suite declares no Test_Case types");
      end if;

      for Name of Declared loop
         if not Registered.Contains (Name) then
            Fail ("AUnit Test_* routine is not registered: " & Name);
         end if;
      end loop;

      for Name of Registered loop
         if not Declared.Contains (Name) then
            Fail ("AUnit registration references an undeclared Test_* routine: " & Name);
         end if;
      end loop;

      for Name of Case_Types loop
         if not Suite_Cases.Contains (Name) then
            Fail ("AUnit Test_Case type is not added to Suite: " & Name);
         end if;
      end loop;

      for Name of Suite_Cases loop
         if not Case_Types.Contains (Name) then
            Fail ("AUnit Suite references an undeclared Test_Case type: " & Name);
         end if;
      end loop;

      Project_Tools.Files.Require_Contains
        (All_Suites,
         "with Files_Suite;",
         "AUnit aggregate suite must depend on the files suite");
      Project_Tools.Files.Require_Contains
        (All_Suites,
         "Result.Add_Test (Files_Suite.Suite);",
         "AUnit aggregate suite must add the files suite");
      Project_Tools.Files.Require_Contains
        (Runner,
         "with All_Suites;",
         "AUnit executable must import the aggregate suite");
      Project_Tools.Files.Require_Contains
        (Runner,
         "Test_Runner_With_Status (All_Suites.Suite)",
         "AUnit executable must run the aggregate suite with status reporting");
      Project_Tools.Files.Require_Contains
        (Runner,
         "Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);",
         "AUnit executable must propagate failed test status");
   end Check_AUnit_Test_Registration;

   function Has_Non_Ada_Tooling_Extension (Name : String) return Boolean is
      Lower_Name : constant String := Ada.Characters.Handling.To_Lower (Name);
   begin
      return
        Ends_With (Lower_Name, ".py")
        or else Ends_With (Lower_Name, ".sh")
        or else Ends_With (Lower_Name, ".bash")
        or else Ends_With (Lower_Name, ".zsh")
        or else Ends_With (Lower_Name, ".fish")
        or else Ends_With (Lower_Name, ".ps1")
        or else Ends_With (Lower_Name, ".bat")
        or else Ends_With (Lower_Name, ".cmd")
        or else Ends_With (Lower_Name, ".pl")
        or else Ends_With (Lower_Name, ".rb")
        or else Ends_With (Lower_Name, ".awk")
        or else Ends_With (Lower_Name, ".sed")
        or else Ends_With (Lower_Name, ".lua")
        or else Ends_With (Lower_Name, ".php")
        or else Ends_With (Lower_Name, ".js")
        or else Ends_With (Lower_Name, ".ts");
   end Has_Non_Ada_Tooling_Extension;

   function Has_Parser_Generator_Extension (Name : String) return Boolean is
      Lower_Name : constant String := Ada.Characters.Handling.To_Lower (Name);
   begin
      return
        Ends_With (Lower_Name, ".y")
        or else Ends_With (Lower_Name, ".yy")
        or else Ends_With (Lower_Name, ".l")
        or else Ends_With (Lower_Name, ".ll")
        or else Ends_With (Lower_Name, ".g4")
        or else Ends_With (Lower_Name, ".peg");
   end Has_Parser_Generator_Extension;

   function Has_Shebang (Path : String) return Boolean is
      File   : Ada.Text_IO.File_Type;
      Buffer : String (1 .. 2);
      Last   : Natural := 0;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      if not Ada.Text_IO.End_Of_File (File) then
         Ada.Text_IO.Get_Line (File, Buffer, Last);
      end if;
      Ada.Text_IO.Close (File);
      return Last = 2 and then Buffer = "#!";
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return False;
   end Has_Shebang;

   procedure Check_Ada_Only_Tooling_In_Tree (Path : String);

   procedure Check_Ada_Only_Tooling_File
     (Name : String;
      Full : String) is
   begin
      if Has_Non_Ada_Tooling_Extension (Name) then
         Put_Line (Standard_Error, Full & ": non-Ada helper tooling is not allowed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      elsif Has_Parser_Generator_Extension (Name) then
         Put_Line (Standard_Error, Full & ": external parser generator input is not allowed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      elsif Has_Shebang (Full) then
         Put_Line (Standard_Error, Full & ": shebang helper tooling is not allowed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
   end Check_Ada_Only_Tooling_File;

   procedure Check_Ada_Only_Tooling_In_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name = "." or else Name = ".." then
               null;
            elsif Ada.Directories.Kind (Dir_Entry) = Ada.Directories.Directory then
               if not Is_Generated_Directory_Name (Name) then
                  Check_Ada_Only_Tooling_In_Tree (Full);
               end if;
            else
               Check_Ada_Only_Tooling_File (Name, Full);
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_Ada_Only_Tooling_In_Tree;

   procedure Check_Ada_Only_Tooling_At_Project_Root is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      Ada.Directories.Start_Search
        (Search,
         Directory => Root,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => False,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            Check_Ada_Only_Tooling_File (Name, Full);
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_Ada_Only_Tooling_At_Project_Root;

   procedure Check_Ada_Only_Tooling is
   begin
      Check_Ada_Only_Tooling_At_Project_Root;
      Check_Ada_Only_Tooling_In_Tree (Root & "/config");
      Check_Ada_Only_Tooling_In_Tree (Root & "/scripts");
      Check_Ada_Only_Tooling_In_Tree (Root & "/src");
      Check_Ada_Only_Tooling_In_Tree (Root & "/tests");
      Check_Ada_Only_Tooling_In_Tree (Root & "/tools");
      Check_Ada_Only_Tooling_In_Tree (Root & "/share");
   end Check_Ada_Only_Tooling;

   function Is_Source_String_Delimiter
     (Text  : String;
      Index : Positive)
      return Boolean is
   begin
      if Text (Index) /= '"' then
         return False;
      elsif Index > Text'First and then Text (Index - 1) = ''' then
         return False;
      end if;

      return True;
   end Is_Source_String_Delimiter;

   function Looks_Like_User_Text (Literal : String) return Boolean is
      Has_Letter : Boolean := False;
      Has_Space  : Boolean := False;
   begin
      --  Shell/command fragments and similar code carry metacharacters that
      --  never appear in user-visible prose; they are not localizable text.
      for Char of Literal loop
         if Char in '$' | ';' | '|' | '<' | '>' then
            return False;
         end if;
      end loop;

      if Literal = "/Type /Page"
        or else Literal = "untitled "
        or else Literal = "untitled.txt"
        or else Literal = "[Trash Info]"
        or else Literal = "Path="
        or else Literal = "DeletionDate="
        or else Literal = "default_view_mode = "
        or else Literal = "show_hidden_files = "
        or else Literal = "sort_field = "
        or else Literal = "sort_ascending = "
        or else Literal = "high_contrast_theme = "
        or else Literal = "icon_theme = "
        or else Literal = "font_pixel_size = "
        or else Literal = "info_pane_open = "
        or else Literal = "use_system_default_opener = "
        or else Literal = "window_width = "
        or else Literal = "window_height = "
        or else Literal = "bookmark = "
      then
         return False;
      end if;

      for Char of Literal loop
         if (Char >= 'A' and then Char <= 'Z') or else (Char >= 'a' and then Char <= 'z') then
            Has_Letter := True;
         elsif Char = ' ' then
            Has_Space := True;
         end if;
      end loop;

      return Has_Letter and then Has_Space;
   end Looks_Like_User_Text;

   procedure Check_No_User_Text_Literals (Path : String) is
      Content       : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Index         : Natural := Content'First;
      Line          : Natural := 1;
   begin
      while Index <= Content'Last loop
         if Content (Index) = ASCII.LF then
            Line := Line + 1;
            Index := Index + 1;
         elsif Content (Index) = '-'
           and then Index < Content'Last
           and then Content (Index + 1) = '-'
         then
            --  Skip the rest of a comment line: its prose may contain quoted
            --  phrases that are documentation, not hard-coded user-visible
            --  string literals. (Outside a string literal, "--" always starts
            --  an Ada comment.)
            while Index <= Content'Last and then Content (Index) /= ASCII.LF loop
               Index := Index + 1;
            end loop;
         elsif Is_Source_String_Delimiter (Content, Index) then
            Index := Index + 1;
            declare
               Literal : Unbounded_String;
               Closed  : Boolean := False;
            begin
               while Index <= Content'Last and then not Closed loop
                  if Content (Index) = '"' then
                     if Index < Content'Last and then Content (Index + 1) = '"' then
                        Append (Literal, '"');
                        Index := Index + 2;
                     else
                        Closed := True;
                        Index := Index + 1;
                     end if;
                  else
                     if Content (Index) = ASCII.LF then
                        Line := Line + 1;
                     end if;
                     Append (Literal, Content (Index));
                     Index := Index + 1;
                  end if;
               end loop;

               if Looks_Like_User_Text (To_String (Literal)) then
                  Put_Line
                    (Standard_Error,
                     Path & ":" & Natural'Image (Line)
                     & ": hard-coded user-visible text literal: "
                     & To_String (Literal));
                  Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
                  raise Program_Error;
               end if;
            end;
         else
            Index := Index + 1;
         end if;
      end loop;
   end Check_No_User_Text_Literals;

   procedure Check_No_User_Text_Literals_In_Source_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name = "." or else Name = ".." then
               null;
            elsif Ada.Directories.Kind (Dir_Entry) = Ada.Directories.Directory then
               if not Is_Generated_Directory_Name (Name) then
                  Check_No_User_Text_Literals_In_Source_Tree (Full);
               end if;
            elsif Name /= "files-localization.adb"
              and then (Ends_With (Name, ".adb") or else Ends_With (Name, ".ads"))
            then
               Check_No_User_Text_Literals (Full);
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_No_User_Text_Literals_In_Source_Tree;

   procedure Check_Command_Localization_Keys is
      Commands : constant String := Root & "/src/files-commands.adb";
      Catalog  : constant String := Root & "/share/files.catalog";
      Content  : constant String := To_String (Project_Tools.Text.Read_Text_File (Commands));
      Index    : Natural := Content'First;

      procedure Require_Key (Key : String) is
      begin
         if Starts_With (Key, "command.") then
            Project_Tools.Files.Require_Contains
              (Catalog,
               "en." & Key & " = ",
               "command localization key must exist in share/files.catalog: " & Key);
         end if;
      end Require_Key;
   begin
      while Index <= Content'Last loop
         if Is_Source_String_Delimiter (Content, Index) then
            Index := Index + 1;
            declare
               Literal : Unbounded_String;
               Closed  : Boolean := False;
            begin
               while Index <= Content'Last and then not Closed loop
                  if Content (Index) = '"' then
                     if Index < Content'Last and then Content (Index + 1) = '"' then
                        Append (Literal, '"');
                        Index := Index + 2;
                     else
                        Closed := True;
                        Index := Index + 1;
                     end if;
                  else
                     Append (Literal, Content (Index));
                     Index := Index + 1;
                  end if;
               end loop;

               Require_Key (To_String (Literal));
            end;
         else
            Index := Index + 1;
         end if;
      end loop;
   end Check_Command_Localization_Keys;

   procedure Check_Catalog_Unique_Keys is
      package String_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type        => String,
         Hash                => Ada.Strings.Hash,
         Equivalent_Elements => "=");

      Catalog     : constant String := Root & "/share/files.catalog";
      Content     : constant String := To_String (Project_Tools.Text.Read_Text_File (Catalog));
      Seen        : String_Sets.Set;
      Line_Number : Natural := 1;
      Line_Start  : Positive := Content'First;

      procedure Check_Line (Raw : String) is
         Line   : constant String := Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
         Equals : constant Natural := Ada.Strings.Fixed.Index (Line, "=");
      begin
         if Line = "" or else Starts_With (Line, "#") then
            return;
         elsif Equals = 0 then
            return;
         end if;

         declare
            Key : constant String :=
              Ada.Strings.Fixed.Trim (Line (Line'First .. Equals - 1), Ada.Strings.Both);
         begin
            if Seen.Contains (Key) then
               Put_Line
                 (Standard_Error,
                  Catalog & ":" & Natural'Image (Line_Number) & ": duplicate localization key: " & Key);
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;

            Seen.Insert (Key);
         end;
      end Check_Line;
   begin
      if Content = "" then
         return;
      end if;

      for Index in Content'Range loop
         if Content (Index) = ASCII.LF then
            Check_Line (Content (Line_Start .. Index - 1));
            Line_Number := Line_Number + 1;
            Line_Start := Index + 1;
         end if;
      end loop;

      if Line_Start <= Content'Last then
         Check_Line (Content (Line_Start .. Content'Last));
      end if;
   end Check_Catalog_Unique_Keys;

   procedure Check_Catalog_Format is
      Catalog     : constant String := Root & "/share/files.catalog";
      Content     : constant String := To_String (Project_Tools.Text.Read_Text_File (Catalog));
      Line_Number : Natural := 1;
      Line_Start  : Positive := Content'First;

      procedure Fail
        (Message : String)
      is
      begin
         Put_Line
           (Standard_Error,
            Catalog & ":" & Natural'Image (Line_Number) & ": " & Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Fail;

      function Is_Key_Character
        (Char : Character)
         return Boolean is
      begin
         return
           (Char >= 'a' and then Char <= 'z')
           or else (Char >= '0' and then Char <= '9')
           or else Char = '.'
           or else Char = '_';
      end Is_Key_Character;

      function Is_Locale_Character
        (Char : Character)
         return Boolean is
      begin
         return
           (Char >= 'a' and then Char <= 'z')
           or else (Char >= 'A' and then Char <= 'Z')
           or else (Char >= '0' and then Char <= '9')
           or else Char = '_'
           or else Char = '-';
      end Is_Locale_Character;

      function Is_Localized_Key
        (Key : String)
         return Boolean
      is
         Dot : constant Natural := Ada.Strings.Fixed.Index (Key, ".");
      begin
         if Dot <= Key'First or else Dot = Key'Last then
            return False;
         end if;

         for Position in Key'First .. Dot - 1 loop
            if not Is_Locale_Character (Key (Position)) then
               return False;
            end if;
         end loop;

         for Position in Dot + 1 .. Key'Last loop
            if not Is_Key_Character (Key (Position)) then
               return False;
            end if;
         end loop;

         return True;
      end Is_Localized_Key;

      procedure Check_Line (Raw : String) is
         Line   : constant String := Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
         Equals : constant Natural := Ada.Strings.Fixed.Index (Line, "=");
      begin
         if Line = "" or else Starts_With (Line, "#") then
            return;
         elsif Equals = 0 then
            Fail ("localization catalog entry must contain an equals sign");
         elsif Equals = Line'First then
            Fail ("localization catalog entry must contain a key before the equals sign");
         elsif Line (Equals - 1) /= ' ' then
            Fail ("localization catalog entry must use ' = ' between key and value");
         elsif Equals < Line'Last and then Line (Equals + 1) /= ' ' then
            Fail ("localization catalog entry must use ' = ' between key and value");
         end if;

         declare
            Key : constant String :=
              Ada.Strings.Fixed.Trim (Line (Line'First .. Equals - 1), Ada.Strings.Both);
         begin
            if Key = "default_locale" then
               null;
            elsif not Is_Localized_Key (Key) then
               Fail ("localization catalog key must be locale-prefixed and use stable key characters");
            end if;
         end;
      end Check_Line;
   begin
      if Content = "" then
         return;
      end if;

      for Index in Content'Range loop
         if Content (Index) = ASCII.LF then
            Check_Line (Content (Line_Start .. Index - 1));
            Line_Number := Line_Number + 1;
            Line_Start := Index + 1;
         end if;
      end loop;

      if Line_Start <= Content'Last then
         Check_Line (Content (Line_Start .. Content'Last));
      end if;
   end Check_Catalog_Format;

   procedure Check_Catalog_Baseline_Keys is
      Catalog : constant String := Root & "/share/files.catalog";
   begin
      Project_Tools.Files.Require_Contains
        (Catalog,
         "default_locale = en",
         "localization catalog must declare the default English locale");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.cli.help.usage = ",
         "localization catalog must include CLI help text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.startup.window.ready = ",
         "localization catalog must include startup window labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.startup.error = ",
         "localization catalog must include startup error labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.window = ",
         "localization catalog must include runtime smoke labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.rectangles = ",
         "localization catalog must include runtime smoke rectangle labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.glyphs = ",
         "localization catalog must include runtime smoke glyph labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.missing_glyphs = ",
         "localization catalog must include runtime smoke missing-glyph labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.font = ",
         "localization catalog must include runtime smoke font labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.vertices = ",
         "localization catalog must include runtime smoke vertex labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.vulkan_status = ",
         "localization catalog must include runtime smoke Vulkan status labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.vulkan_result = ",
         "localization catalog must include runtime smoke Vulkan result labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.framebuffer_readback = ",
         "localization catalog must include runtime smoke framebuffer readback labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.frames_attempted = ",
         "localization catalog must include runtime smoke attempted-frame labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.frames_presented = ",
         "localization catalog must include runtime smoke presented-frame labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.framebuffer_hash = ",
         "localization catalog must include runtime smoke framebuffer hash labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.framebuffer_bytes = ",
         "localization catalog must include runtime smoke framebuffer byte-count labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.text_failed = ",
         "localization catalog must include runtime smoke text-failure diagnostics");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.no_windows = ",
         "localization catalog must include runtime smoke no-window diagnostics");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.no_display = ",
         "localization catalog must include runtime smoke display diagnostics");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.no_vulkan = ",
         "localization catalog must include runtime smoke diagnostics");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.ready = ",
         "localization catalog must include runtime smoke ready diagnostics");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.runtime.smoke.requires_live_harness = ",
         "localization catalog must include live-smoke harness diagnostics");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.cli.help.path = ",
         "localization catalog must include CLI path help text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.cli.help.option.runtime_smoke = ",
         "localization catalog must include runtime-smoke CLI option text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.cli.help.option.live_smoke = ",
         "localization catalog must include live-smoke CLI option text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.cli.help.option.settings = ",
         "localization catalog must include settings CLI option text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.cli.help.option.help = ",
         "localization catalog must include help CLI option text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.command.view.small = ",
         "localization catalog must include command labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.command.view.small.description = ",
         "localization catalog must include command descriptions");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.command.palette.empty = ",
         "localization catalog must include command-palette empty-state text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.root.filesystem = ",
         "localization catalog must include root-selector labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.root.detail.prefix = ",
         "localization catalog must include root-selector detail formatting");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.status.empty_directory = ",
         "localization catalog must include directory empty-state text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.filter.placeholder = find",
         "localization catalog must include filter placeholder text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.status.items = ",
         "localization catalog must include item-count status labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.status.visible = ",
         "localization catalog must include visible-count status labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.status.selected = ",
         "localization catalog must include selected-count status labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.status.missing_metadata = ",
         "localization catalog must include missing-metadata fallback text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.info.name = ",
         "localization catalog must include info-pane labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.info.extra.directory.count.prefix = ",
         "localization catalog must include filetype-specific metadata labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.details.name = ",
         "localization catalog must include details-view column labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.details.size.unit.bytes = ",
         "localization catalog must include details-view size units");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.details.size.unit.kib = ",
         "localization catalog must include scaled KB details-view size unit");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.details.size.unit.mib = ",
         "localization catalog must include scaled MB details-view size unit");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.details.size.unit.gib = ",
         "localization catalog must include scaled GB details-view size unit");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.settings.title = ",
         "localization catalog must include settings pane labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.settings.help.open_action_command = ",
         "localization catalog must include settings field help text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.settings.options.default_view = ",
         "localization catalog must include settings option text");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.accessibility.toolbar = ",
         "localization catalog must include accessibility labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.accessibility.main_view = ",
         "localization catalog must include main-view accessibility labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.accessibility.info_pane = ",
         "localization catalog must include info-pane accessibility labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.accessibility.command_palette_search = ",
         "localization catalog must include command-palette accessibility labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.accessibility.command_disabled = ",
         "localization catalog must include disabled command accessibility labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.accessibility.root_selector = ",
         "localization catalog must include root-selector accessibility labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.error.path.missing = ",
         "localization catalog must include recoverable error messages");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.error.rename.disabled = ",
         "localization catalog must include rename enablement errors");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.error.open_action.execution = ",
         "localization catalog must include open-action execution errors");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.error.open_action.unsafe_placeholder = ",
         "localization catalog must include unsafe open-action placeholder errors");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.command.file.delete_permanently = ",
         "localization catalog must include permanent-delete command labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.command.file.generate_thumbnails = ",
         "localization catalog must include thumbnail-generation command labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.command.directory.search_recursive = ",
         "localization catalog must include recursive-search command labels");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.error.settings.save = ",
         "localization catalog must include settings persistence errors");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.error.settings.closed = ",
         "localization catalog must include settings pane state errors");
      Project_Tools.Files.Require_Contains
        (Catalog,
         "en.error.window.create = ",
         "localization catalog must include window creation errors");
   end Check_Catalog_Baseline_Keys;

   procedure Check_Error_Localization_Test_Coverage is
      Catalog      : constant String := Root & "/share/files.catalog";
      Tests        : constant String := Combined_Suite;
      Content      : constant String := To_String (Project_Tools.Text.Read_Text_File (Catalog));
      Line_First   : Natural := Content'First;
      Line_Last    : Natural := Content'First;
      Separator    : Natural;
      Covered_Key  : Unbounded_String;

      procedure Check_Line (Line : String) is
      begin
         if Starts_With (Line, "en.error.") then
            Separator := Ada.Strings.Fixed.Index (Line, " = ");
            if Separator = 0 then
               return;
            end if;

            Covered_Key := To_Unbounded_String (Line (Line'First + 3 .. Separator - 1));
            Project_Tools.Files.Require_Contains
              (Tests,
               "Add_Error_Key (""" & To_String (Covered_Key) & """);",
               "localization tests must cover recoverable error key " & To_String (Covered_Key));
         end if;
      end Check_Line;
   begin
      while Line_First <= Content'Last loop
         Line_Last := Line_First;
         while Line_Last <= Content'Last and then Content (Line_Last) /= ASCII.LF loop
            Line_Last := Line_Last + 1;
         end loop;

         if Line_Last > Line_First then
            Check_Line (Content (Line_First .. Line_Last - 1));
         end if;

         Line_First := Line_Last + 1;
      end loop;
   end Check_Error_Localization_Test_Coverage;

   function Is_Complete_Localization_Key (Key : String) return Boolean is
   begin
      return
        Key /= ""
        and then Key /= "settings.conf"
        and then Key (Key'Last) /= '.'
        and then
          (Starts_With (Key, "accessibility.")
           or else Starts_With (Key, "cli.")
           or else Starts_With (Key, "command.")
           or else Starts_With (Key, "details.")
           or else Starts_With (Key, "dialog.")
           or else Starts_With (Key, "error.")
           or else Starts_With (Key, "info.")
           or else Starts_With (Key, "root.")
           or else Starts_With (Key, "runtime.")
           or else Starts_With (Key, "settings.")
           or else Starts_With (Key, "startup.")
           or else Starts_With (Key, "status."));
   end Is_Complete_Localization_Key;

   function Is_Indirect_Localization_Key (Key : String) return Boolean is
   begin
      return
        Key /= ""
        and then Key (Key'Last) /= '.'
        and then Key /= "settings.conf"
        and then not Contains (Key, "|")
        and then
          (Starts_With (Key, "accessibility.")
           or else Starts_With (Key, "cli.")
           or else Starts_With (Key, "command.")
           or else Starts_With (Key, "details.")
           or else Starts_With (Key, "dialog.")
           or else Starts_With (Key, "error.")
           or else Starts_With (Key, "info.")
           or else Starts_With (Key, "root.")
           or else Starts_With (Key, "runtime.")
           or else Starts_With (Key, "settings.")
           or else Starts_With (Key, "startup.")
           or else Starts_With (Key, "status."));
   end Is_Indirect_Localization_Key;

   procedure Check_Indirect_Localization_Keys_In_File (Path : String) is
      Catalog : constant String := Root & "/share/files.catalog";
      Content : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Index   : Natural := Content'First;
   begin
      while Index <= Content'Last loop
         if Is_Source_String_Delimiter (Content, Index) then
            Index := Index + 1;
            declare
               Literal : Unbounded_String;
               Closed  : Boolean := False;
            begin
               while Index <= Content'Last and then not Closed loop
                  if Content (Index) = '"' then
                     if Index < Content'Last and then Content (Index + 1) = '"' then
                        Append (Literal, '"');
                        Index := Index + 2;
                     else
                        Closed := True;
                        Index := Index + 1;
                     end if;
                  else
                     Append (Literal, Content (Index));
                     Index := Index + 1;
                  end if;
               end loop;

               if Is_Indirect_Localization_Key (To_String (Literal)) then
                  Project_Tools.Files.Require_Contains
                    (Catalog,
                     "en." & To_String (Literal) & " = ",
                     Path & ": localization key must exist in share/files.catalog: " & To_String (Literal));
               end if;
            end;
         else
            Index := Index + 1;
         end if;
      end loop;
   end Check_Indirect_Localization_Keys_In_File;

   procedure Check_Indirect_Localization_Keys_In_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name = "." or else Name = ".." then
               null;
            elsif Ada.Directories.Kind (Dir_Entry) = Ada.Directories.Directory then
               if not Is_Generated_Directory_Name (Name) then
                  Check_Indirect_Localization_Keys_In_Tree (Full);
               end if;
            elsif Name'Length >= 4
              and then Name /= "files-commands.adb"
              and then (Name (Name'Last - 3 .. Name'Last) = ".ads"
                        or else Name (Name'Last - 3 .. Name'Last) = ".adb")
            then
               Check_Indirect_Localization_Keys_In_File (Full);
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_Indirect_Localization_Keys_In_Tree;

   procedure Check_Direct_Localization_Call_Keys_In_File (Path : String) is
      Catalog : constant String := Root & "/share/files.catalog";
      Content : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));

      procedure Check_Marker (Marker : String) is
         Search_From : Positive := Content'First;
      begin
         loop
            declare
               Found : constant Natural :=
                 Ada.Strings.Fixed.Index
                   (Source  => Content,
                    Pattern => Marker,
                    From    => Search_From);
            begin
               exit when Found = 0;

               declare
                  Index  : Natural := Found + Marker'Length;
                  Key    : Unbounded_String;
                  Closed : Boolean := False;
               begin
                  while Index <= Content'Last and then not Closed loop
                     if Content (Index) = '"' then
                        if Index < Content'Last and then Content (Index + 1) = '"' then
                           Append (Key, '"');
                           Index := Index + 2;
                        else
                           Closed := True;
                           Index := Index + 1;
                        end if;
                     else
                        Append (Key, Content (Index));
                        Index := Index + 1;
                     end if;
                  end loop;

                  if Is_Complete_Localization_Key (To_String (Key)) then
                     Project_Tools.Files.Require_Contains
                       (Catalog,
                        "en." & To_String (Key) & " = ",
                        Path & ": localization key must exist in share/files.catalog: " & To_String (Key));
                  end if;

                  Search_From := Natural'Min (Index, Content'Last);
               end;
            end;
         end loop;
      end Check_Marker;
   begin
      if Content = "" then
         return;
      end if;

      Check_Marker ("Files.Localization.Text (""");
      Check_Marker ("Localized (""");
   end Check_Direct_Localization_Call_Keys_In_File;

   procedure Check_Direct_Localization_Call_Keys_In_Tree (Path : String) is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
   begin
      if not Project_Tools.Files.Directory_Exists (Path) then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
           Ada.Directories.Directory     => True,
           Ada.Directories.Special_File  => False]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
         begin
            if Name = "." or else Name = ".." then
               null;
            elsif Ada.Directories.Kind (Dir_Entry) = Ada.Directories.Directory then
               if not Is_Generated_Directory_Name (Name) then
                  Check_Direct_Localization_Call_Keys_In_Tree (Full);
               end if;
            elsif Name'Length >= 4
              and then (Name (Name'Last - 3 .. Name'Last) = ".ads"
                        or else Name (Name'Last - 3 .. Name'Last) = ".adb")
            then
               Check_Direct_Localization_Call_Keys_In_File (Full);
            end if;
         end;
      end loop;

      Ada.Directories.End_Search (Search);
      Started := False;
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Check_Direct_Localization_Call_Keys_In_Tree;

   procedure Check_Localization_Usage is
      Main_Manifest : constant String := Root & "/alire.toml";
      Localization  : constant String := Root & "/src/files-localization.adb";
      Check_Source  : constant String := Root & "/tools/src/check_all.adb";
   begin
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "i18n = ""*""",
         "files must depend on the i18n crate");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "i18n = { path = ""../i18n"" }",
         "files must pin i18n to the local relative crate");
      Project_Tools.Files.Require_Contains
        (Localization,
         "with I18N.Runtime;",
         "Files.Localization must use the i18n runtime");
      Project_Tools.Files.Require_Contains
        (Localization,
         "I18N.Runtime.Initialize",
         "Files.Localization must initialize the i18n runtime");
      Project_Tools.Files.Require_Contains
        (Localization,
         "I18N.Runtime.Render",
         "Files.Localization must render through the i18n runtime");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "if Literal = ""/Type /Page""" & ASCII.LF
         & "        or else Literal = ""untitled """,
         "hard-coded text checks must keep file-format marker exemptions narrow");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "or else Literal = ""untitled """,
         "hard-coded text checks must keep create-file name template exemptions narrow");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "or else Literal = ""untitled.txt""",
         "hard-coded text checks must keep default create-file name exemptions narrow");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "or else Literal = ""[Trash Info]""" & ASCII.LF
         & "        or else Literal = ""Path=""" & ASCII.LF
         & "        or else Literal = ""DeletionDate=""",
         "hard-coded text checks must keep trashinfo metadata exemptions narrow");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "or else Literal = ""default_view_mode = """ & ASCII.LF
         & "        or else Literal = ""show_hidden_files = """ & ASCII.LF
         & "        or else Literal = ""sort_field = """ & ASCII.LF
         & "        or else Literal = ""sort_ascending = """ & ASCII.LF
         & "        or else Literal = ""high_contrast_theme = """ & ASCII.LF
         & "        or else Literal = ""icon_theme = """,
         "hard-coded text checks must keep settings syntax exemptions narrow");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "and then Key /= ""settings.conf""" & ASCII.LF
         & "        and then not Contains (Key, ""|"")",
         "indirect localization key checks must ignore settings filenames");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "and then not Contains (Key, ""|"")",
         "indirect localization key checks must ignore structured metadata tokens");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "and then Name /= ""files-commands.adb""",
         "indirect localization key checks must not treat stable command identifiers as catalog keys");

      Check_No_User_Text_Literals_In_Source_Tree (Root & "/src");
      Check_Catalog_Unique_Keys;
      Check_Catalog_Format;
      Check_Catalog_Baseline_Keys;
      Check_Error_Localization_Test_Coverage;
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "startup window label is localized",
         "localization tests must cover startup window labels");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "startup report uses localized window label",
         "startup report tests must build expected window labels through localization");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "startup error label is localized",
         "localization tests must cover startup error labels");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "startup report uses localized error label and diagnostic",
         "startup report tests must build expected error text through localization");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "runtime smoke text-failure label is localized",
         "localization tests must cover runtime smoke text-failure diagnostics");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "runtime smoke no-window label is localized",
         "localization tests must cover runtime smoke no-window diagnostics");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "runtime smoke report uses localized empty-startup diagnostic",
         "runtime smoke tests must build empty-startup expected text through localization");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "runtime smoke no-display label is localized",
         "localization tests must cover runtime smoke display diagnostics");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "runtime smoke ready label is localized",
         "localization tests must cover runtime smoke ready diagnostics");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "runtime smoke report uses localized window label",
         "runtime smoke tests must build expected window labels through localization");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "runtime smoke report uses localized vertex-count label",
         "runtime smoke tests must build expected metric labels through localization");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "runtime smoke report exposes missing-glyph fallback count",
         "runtime smoke tests must cover missing-glyph fallback diagnostics");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "runtime smoke report exposes selected text font path",
         "runtime smoke tests must cover selected font diagnostics");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "CLI help flag description is localized",
         "localization tests must cover help-flag CLI text");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "detected Danish locale loads translated app catalog resources",
         "localization tests must cover translated locale resource loading");
      Project_Tools.Files.Require_Contains
        (Root & "/src/platform/windows/files-platform-windows.adb",
         "GetUserDefaultLocaleName",
         "Windows locale detection must use the native user-default locale API");
      Project_Tools.Files.Require_Contains
        (Root & "/src/platform/macos/files-platform-macos.adb",
         "CFLocaleCopyCurrent",
         "macOS locale detection must use the native CoreFoundation locale API");
      Project_Tools.Files.Require_Contains
        (Root & "/files.gpr",
         """-framework"", ""CoreFoundation""",
         "macOS locale detection must link CoreFoundation");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "Windows native locale detection binds GetUserDefaultLocaleName",
         "locale tests must cover Windows native locale binding");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "macOS native locale detection binds CoreFoundation locale APIs",
         "locale tests must cover macOS native locale binding");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "unknown localization key falls back to key text",
         "localization tests must cover unknown-key fallback");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "item-count label is localized",
         "localization tests must cover item-count status labels");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "visible-count label is localized",
         "localization tests must cover visible-count status labels");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "selected-count label is localized",
         "localization tests must cover selected-count status labels");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "toolbar landmark is localized",
         "localization tests must cover toolbar accessibility labels");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "main-view landmark is localized",
         "localization tests must cover main-view accessibility labels");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "info-pane landmark is localized",
         "localization tests must cover info-pane accessibility labels");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "command-palette search label is localized",
         "localization tests must cover command-palette search accessibility labels");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "root-selector landmark is localized",
         "localization tests must cover root-selector accessibility labels");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "error localization exists for",
         "localization tests must cover every recoverable error key");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "registered command name is localized for",
         "localization tests must cover registered command names");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "registered command description is localized for",
         "localization tests must cover registered command descriptions");
      Check_Command_Localization_Keys;
      Check_Indirect_Localization_Keys_In_Tree (Root & "/src");
      Check_Direct_Localization_Call_Keys_In_Tree (Root & "/src");
   end Check_Localization_Usage;

   procedure Require_Not_Contains
     (Path    : String;
      Pattern : String;
      Message : String) is
   begin
      if Project_Tools.Files.File_Contains (Path, Pattern) then
         Put_Line (Standard_Error, Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
   end Require_Not_Contains;

   procedure Check_Feature_Scope_Policy is
      Feature_Spec   : constant String := Root & "/src/files-features.ads";
      Feature_Policy : constant String := Root & "/src/files-features.adb";
      File_System_Spec : constant String := Root & "/src/files-file_system.ads";
      Tests          : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Feature_Spec,
         "type Feature_Id is",
         "feature policy must expose stable feature identifiers");
      Project_Tools.Files.Require_Contains
        (Feature_Spec,
         "Drag_And_Drop,",
         "feature policy must name drag-and-drop explicitly");
      Project_Tools.Files.Require_Contains
        (Feature_Spec,
         "Thumbnail_Generation,",
         "feature policy must name thumbnail generation explicitly");
      Project_Tools.Files.Require_Contains
        (Feature_Spec,
         "Recursive_Search,",
         "feature policy must name recursive search explicitly");
      Project_Tools.Files.Require_Contains
        (Feature_Spec,
         "File_Watching,",
         "feature policy must name file watching explicitly");
      Project_Tools.Files.Require_Contains
        (Feature_Spec,
         "Permanent_Delete,",
         "feature policy must name permanent deletion explicitly");
      Project_Tools.Files.Require_Contains
        (Feature_Spec,
         "Network_Filesystem_Special_Handling,",
         "feature policy must name network special handling explicitly");
      Project_Tools.Files.Require_Contains
        (Feature_Spec,
         "Shell_Open_By_Default,",
         "feature policy must name implicit shell opening explicitly");
      Project_Tools.Files.Require_Contains
        (Feature_Spec,
         "Gpu_Screenshot_Tests,",
         "feature policy must name GPU screenshot tests explicitly");
      Project_Tools.Files.Require_Contains
        (Feature_Spec,
         "function Included_In_First_Implementation",
         "feature policy must expose a testable inclusion predicate");
      Project_Tools.Files.Require_Contains
        (Feature_Policy,
         "when Shell_Open_By_Default =>" & ASCII.LF
         & "            return False;",
         "feature policy must keep only implicit shell execution excluded");
      Project_Tools.Files.Require_Contains
        (Feature_Policy,
         "when Drag_And_Drop" & ASCII.LF
         & "            | Thumbnail_Generation" & ASCII.LF
         & "            | Recursive_Search" & ASCII.LF
         & "            | File_Watching" & ASCII.LF
         & "            | Permanent_Delete" & ASCII.LF
         & "            | Network_Filesystem_Special_Handling" & ASCII.LF
         & "            | Gpu_Screenshot_Tests" & ASCII.LF
         & "            | Platform_Trash" & ASCII.LF
         & "            | Root_Discovery" & ASCII.LF
         & "            | Open_Action_Execution" & ASCII.LF
         & "            | Settings_Editing" & ASCII.LF
         & "            | Desktop_Packaging =>" & ASCII.LF
         & "            return True;",
         "feature policy must include advanced desktop filesystem features");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "function Is_Network_Filesystem_Type",
         "feature scope must classify network filesystem mounts");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "Root_Network_Mount",
         "feature scope must add network-specific root discovery");
      Require_Not_Contains
        (Root & "/src/files-file_system.adb",
         "Uses_Mime_Sniffing         => True",
         "feature scope must not enable MIME sniffing without an implementation");
      Require_Not_Contains
        (Root & "/src/files-file_system.adb",
         "Parses_Media_Codecs        => True",
         "feature scope must not claim media codec parsing without an implementation");
      Require_Not_Contains
        (Root & "/src/files-operations.adb",
         "Shell_Requires_Explicit_Opt_In => False",
         "feature scope must not make shell open actions implicit");
      Project_Tools.Files.Require_Contains
        (File_System_Spec,
         "function Plan_Drop_Import",
         "advanced scope must expose drag-and-drop import planning");
      Project_Tools.Files.Require_Contains
        (File_System_Spec,
         "function Execute_Drop_Import",
         "advanced scope must expose drag-and-drop import execution");
      Project_Tools.Files.Require_Contains
        (File_System_Spec,
         "function Generate_Thumbnail",
         "advanced scope must expose thumbnail generation");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "Try_Write_Decoded_P3_Thumbnail",
         "thumbnail generation must decode supported source images before fallback rendering");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "Try_Write_Decoded_Png_Thumbnail",
         "thumbnail generation must decode PNG source pixels before fallback rendering");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "Try_Write_Gdk_Pixbuf_Thumbnail",
         "thumbnail generation must use a native image loader for JPEG thumbnails");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "function Load_Cached_Thumbnail",
         "directory loading must decode cached thumbnails into model-owned pixels");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "function Should_Auto_Generate_Thumbnail",
         "directory loading must decide which files get automatic thumbnails");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "or else Extension = ""webp""",
         "automatic thumbnails must not depend only on configured image filetypes");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "function Thumbnail_For_Item",
         "directory loading must auto-generate missing image thumbnails");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.ads",
         "Thumbnail_Pixels    : Files.Types.Byte_Vectors.Vector;",
         "directory items must carry cached thumbnail pixels");
      Project_Tools.Files.Require_Contains
        (File_System_Spec,
         "function Search_Recursive",
         "advanced scope must expose recursive search");
      Project_Tools.Files.Require_Contains
        (File_System_Spec,
         "function Detect_Directory_Change",
         "advanced scope must expose polling-based file watching");
      Project_Tools.Files.Require_Contains
        (File_System_Spec,
         "function Delete_Permanently",
         "advanced scope must expose explicit permanent deletion");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-operations.ads",
         "function Delete_Selected_Permanently",
         "advanced scope must expose permanent delete as a command operation");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-operations.ads",
         "function Generate_Selected_Thumbnails",
         "advanced scope must expose thumbnail generation as a command operation");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-model.ads",
         "function Directory_Signature_Of",
         "model must store the directory signature used by polling file watching");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-model.ads",
         "procedure Set_Directory_Signature",
         "model must expose controlled updates for the watched directory signature");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-operations.ads",
         "function Refresh_If_Changed",
         "operations must expose polling refresh for file watching");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-operations.ads",
         "function Run_Recursive_Search",
         "operations must expose recursive search as a command operation");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-operations.ads",
         "function Import_Dropped_Paths",
         "operations must expose drag-and-drop import as a command operation");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-controller.adb",
         "when Files.Commands.Delete_Selected_Permanently_Command =>",
         "controller must route permanent delete through the central command registry");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-controller.adb",
         "when Files.Commands.Generate_Thumbnails_Command =>",
         "controller must route thumbnail generation through the central command registry");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-controller.adb",
         "when Files.Commands.Search_Recursive_Command =>",
         "controller must route recursive search through the central command registry");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-controller.ads",
         "function Handle_Drop_Import",
         "controller must expose a drop-import entry point for window events");
      Project_Tools.Files.Require_Contains
        (Root & "/src/glfw-windows-drop.adb",
         "glfwSetDropCallback",
         "desktop runtime must bind native GLFW file-drop callbacks");
      Project_Tools.Files.Require_Contains
        (Root & "/src/glfw-windows-icon.adb",
         "glfwSetWindowIcon",
         "desktop runtime must bind the native GLFW window icon");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-application-windows.adb",
         "Glfw.Windows.Icon.Set_Files_Icon",
         "desktop runtime must apply the application icon to created windows");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-application-windows.adb",
         "Drop_Source : Files.Drop_Events.Drop_Event_Source",
         "desktop runtime must queue native file drops through the event-source backend");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-drop_events.ads",
         "type Drop_Event_Source is private",
         "drop automation must expose a private Ada event-source backend");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-drop_events.ads",
         "procedure Queue",
         "drop automation must expose queued native event injection");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-drop_events.ads",
         "procedure Take",
         "drop automation must expose deterministic drop draining");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-application-windows.adb",
         "Handle_Drop_Input",
         "desktop runtime must drain native file drops through controller routing");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-application-windows.adb",
         "glfwWaitEventsTimeout",
         "desktop runtime must wake periodically while waiting for native events");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-application-windows.adb",
         "Handle_File_Watch_Poll",
         "desktop runtime must poll directory changes from the event loop");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-application-windows.adb",
         "inotify_init1",
         "desktop runtime must use native filesystem watching when available");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-application-windows.adb",
         "Drain_Native_Watch",
         "desktop runtime must drain native filesystem watch events");
      Project_Tools.Files.Require_Contains
        (Tests,
         "network filesystem special handling belongs to the implementation",
         "feature tests must cover network filesystem special handling inclusion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shell open actions remain opt-in",
         "feature tests must cover shell execution opt-in policy");
      Project_Tools.Files.Require_Contains
        (Tests,
         "GPU screenshot comparison tests belong to the implementation",
         "feature tests must cover GPU screenshot comparison inclusion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "all project helper tooling remains implemented in Ada",
         "feature tests must cover the Ada-only helper tooling policy");
      Project_Tools.Files.Require_Contains
        (Tests,
         "drag-and-drop import belongs to the implementation",
         "feature tests must cover drag-and-drop inclusion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "thumbnail generation belongs to the implementation",
         "feature tests must cover thumbnail generation inclusion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "recursive search belongs to the implementation",
         "feature tests must cover recursive search inclusion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "file watching belongs to the implementation",
         "feature tests must cover file watching inclusion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "permanent deletion belongs to the implementation",
         "feature tests must cover permanent deletion inclusion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "platform trash belongs to the first implementation",
         "feature tests must cover platform trash inclusion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "open-action execution belongs to the first implementation",
         "feature tests must cover open-action execution inclusion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "thumbnail generation writes a cache artifact",
         "advanced filesystem tests must cover thumbnail artifact creation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "directory loading auto-generates image thumbnails",
         "advanced filesystem tests must cover normal directory thumbnail generation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "directory loading auto-generates thumbnails for image extensions",
         "advanced filesystem tests must cover extension-based thumbnail generation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan icon atlas rasterizes large-icons cached thumbnail pixels",
         "advanced filesystem tests must cover rendered large-icons thumbnail pixels");
      Project_Tools.Files.Require_Contains
        (Tests,
         "non-large item icon command keeps filetype icon",
         "advanced filesystem tests must reject thumbnails outside large-icons view");
      Project_Tools.Files.Require_Contains
        (Tests,
         "drop import copy executes",
         "advanced filesystem tests must cover drag-and-drop import execution");
      Project_Tools.Files.Require_Contains
        (Tests,
         "controller drop import succeeds",
         "advanced filesystem tests must cover controller drop-import routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "recursive search finds nested matches",
         "advanced filesystem tests must cover recursive search results");
      Project_Tools.Files.Require_Contains
        (Tests,
         "polling directory watcher detects added entries",
         "advanced filesystem tests must cover directory change detection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "changed directory watcher refresh succeeds",
         "advanced filesystem tests must cover polling watcher refresh");
      Project_Tools.Files.Require_Contains
        (Tests,
         "explicit permanent delete removes a tree",
         "advanced filesystem tests must cover permanent delete execution");
      Project_Tools.Files.Require_Contains
        (Tests,
         "permanent delete routes through command registry",
         "advanced filesystem tests must cover permanent-delete command routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "thumbnail generation routes through command registry",
         "advanced filesystem tests must cover thumbnail-generation command routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "recursive search routes through command registry",
         "advanced filesystem tests must cover recursive-search command routing");
   end Check_Feature_Scope_Policy;

   procedure Check_Open_Action_Shell_Safety is
      Settings_Body   : constant String := Root & "/src/files-settings.adb";
      Operations_Body : constant String := Root & "/src/files-operations.adb";
      Tests           : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Use_Shell : Boolean := False;",
         "open-action parsing must default to non-shell execution");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Starts_With (Files.Types.To_Lower (To_String (Clean)), ""shell:"")",
         "open-action parsing must require an explicit shell prefix");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Use_Shell  : Boolean := False)",
         "open-action construction must default to non-shell execution");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Use_Shell  => Use_Shell",
         "open-action parsing must preserve the explicit shell flag");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Starts_With (Files.Types.To_Lower (To_String (Clean)), ""shell:"")",
         "open-action parsing must normalize shell-prefix case before shell opt-in");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Args.Append (To_Unbounded_String (Token));",
         "open-action parsing must keep shell arguments as an argument vector");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Append (Result, ""shell:"");",
         "open-action serialization must preserve explicit shell opt-in");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "if Action.Use_Shell then",
         "open-action execution must branch on the explicit shell flag");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Args (2) := new String'(Shell_Command_Line (Action));",
         "explicit shell execution must pass a quoted command line as one argument");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Shell_Path   : constant String := Shell_Executable;",
         "explicit shell execution must capture the selected shell before spawning");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Exit_Status := GNAT.OS_Lib.Spawn (Shell_Path, Args.all);",
         "explicit shell execution must spawn the captured shell path");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Exit_Status := GNAT.OS_Lib.Spawn (To_String (Action.Executable), Args.all);",
         "non-shell open actions must execute the configured executable directly");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "elsif Argument_Count = 0 then",
         "zero-argument open actions must avoid heap argument-list allocation");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Empty_Args : GNAT.OS_Lib.Argument_List (1 .. 0);",
         "zero-argument open actions must use an explicit empty argument vector");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Append (Result, Shell_Quote (To_String (Argument)));",
         "explicit shell command construction must quote each argument");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shell execution is opt-in through explicit prefix",
         "explicit shell opt-in must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shell action arguments are still parsed as a vector",
         "explicit shell actions must keep parsed argv structure before execution");
      Project_Tools.Files.Require_Contains
        (Tests,
         "placeholder expansion preserves explicit shell flag",
         "explicit shell placeholder expansion must preserve shell opt-in");
      Project_Tools.Files.Require_Contains
        (Tests,
         "uppercase shell prefix is normalized",
         "explicit shell parsing must accept case-insensitive shell prefix");
      Project_Tools.Files.Require_Contains
        (Tests,
         "serialized shell action preserves shell opt-in",
         "explicit shell serialization must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "explicit shell action keeps semicolon argument as one vector value",
         "explicit shell quoting must remain covered by AUnit");
   end Check_Open_Action_Shell_Safety;

   procedure Check_Open_Action_Settings_Validation is
      Settings_Body : constant String := Root & "/src/files-settings.adb";
      Tests         : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "not Action_Token_Modifiers_Are_Known (Token)",
         "direct open-action insertion must reject unknown or malformed modifiers");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "function Structured_Filetype_Suffix_Is_Known",
         "open-action validation must distinguish structured filetype suffixes from modifiers");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "return Clean = ""json""" & ASCII.LF
         & "        or else Clean = ""xml""",
         "open-action validation must allow common structured filetype suffixes");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "function Modifier_Suffix_Start",
         "open-action token parsing must locate valid modifier suffixes explicitly");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "elsif Plus = Clean'Last or else Clean (Clean'Last) = '+' then",
         "open-action modifier validation must reject dangling modifier separators");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Last = Position then",
         "open-action modifier validation must reject empty modifier segments");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "function Mapping_Key_Is_Valid",
         "direct settings mapping helpers must share key validation");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "function Mapping_Value_Is_Valid",
         "direct settings mapping helpers must share value validation");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "function Contains_Line_Break",
         "settings helper validation must reject line breaks in serializable fields");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Files.UTF8.Decode_Next_Codepoint (Text, Index, Codepoint);",
         "settings helper validation must decode UTF-8 before rejecting Unicode line separators");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "or else Byte_Value = Character'Pos (ASCII.VT)" & ASCII.LF
         & "              or else Byte_Value = Character'Pos (ASCII.FF)",
         "settings helper validation must reject vertical-tab and form-feed controls");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "or else Codepoint = 16#2028#" & ASCII.LF
         & "           or else Codepoint = 16#2029#",
         "settings helper validation must reject Unicode line and paragraph separators");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "not Mapping_Key_Is_Valid (Key) or else not Mapping_Value_Is_Valid (Value)",
         "direct extension and icon mappings must reject unrepresentable keys and values");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "function Open_Action_Base_Key_Is_Valid",
         "open-action settings validation must use a dedicated base-key predicate");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "or else Character_Value = '""'",
         "open-action base-key validation must reject quote syntax characters");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "or else Character_Value = '['",
         "open-action base-key validation must reject bracket syntax characters");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "or else not Open_Action_Base_Key_Is_Valid ((if Plus = 0 then Key else Key (Key'First .. Plus - 1)))",
         "direct open-action insertion must reject invalid filetype tokens");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "or else (Plus = Token'First)",
         "draft open-action validation must explicitly reject modifier-only tokens");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "or else Trim (To_String (Action.Executable)) = """"",
         "direct open-action insertion must reject empty executables");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "not Action_Token_Modifiers_Are_Known (Key)",
         "settings parsing must reject unknown or malformed open-action modifiers");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Has_Unsafe_Placeholder_Usage (Action)",
         "settings parsing must reject unsafe open-action placeholders");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "or else not Action_Text_Is_Serializable (Action)",
         "settings parsing must reject non-serializable open-action text");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Contains_Known_Placeholder (To_String (Action.Executable))",
         "settings validation must reject placeholders in open-action executables");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "or else not Action_Text_Is_Serializable (Action)",
         "direct open-action insertion must reject line breaks in executable or arguments");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "function Next_Action_Token",
         "settings parsing must tokenize open actions without shell-style string interpolation");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Text (First) = '""' then",
         "settings parsing must handle quoted open-action executable and argument tokens");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "and then Text (Last + 1) = '""'",
         "settings parsing must preserve doubled quotes inside quoted action tokens");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Append (Value, '""');",
         "settings parsing must unescape doubled quotes inside quoted action tokens");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Last <= Text'Last" & ASCII.LF
         & "           and then Text (Last) /= ' '" & ASCII.LF
         & "           and then Text (Last) /= ASCII.HT",
         "settings parsing must reject quoted open-action tokens followed by trailing junk");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Text (Last) = '""' then",
         "settings parsing must reject unquoted quote characters in action tokens");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Character_Value = '""' then",
         "settings serialization must escape quotes inside open-action tokens");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Append (Result, "
         & '"' & '"' & '"' & '"' & '"' & '"'
         & ");",
         "settings serialization must double embedded quote characters");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Append (Result, Action_Token_Text (To_String (Argument)));",
         "settings serialization must preserve each open-action argument as a separate token");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion ignores unknown modifiers",
         "direct open-action unknown modifier rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion accepts structured filetype suffixes",
         "direct open-action structured-suffix support must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "structured-suffix modifier-specific open action is found",
         "settings parser structured-suffix modifier lookup must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct extension mapping trims values and replaces existing entries",
         "direct extension mapping replacement must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct extension mapping ignores empty normalized extension",
         "direct extension mapping empty-key rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct extension mapping ignores empty filetype value",
         "direct extension mapping empty-value rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct extension mapping ignores unrepresentable extension keys",
         "direct extension mapping key validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct extension mapping ignores line-break extension keys",
         "direct extension mapping line-break key validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct extension mapping ignores vertical-tab extension keys",
         "direct extension mapping vertical-tab key validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct extension mapping ignores Unicode line-separator extension keys",
         "direct extension mapping Unicode line-separator key validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct extension mapping ignores unrepresentable values",
         "direct extension mapping value validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct extension mapping ignores form-feed values",
         "direct extension mapping form-feed value validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct extension mapping ignores Unicode line-separator values",
         "direct extension mapping Unicode line-separator value validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct icon mapping trims values and replaces existing entries",
         "direct icon mapping replacement must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct icon mapping ignores empty filetype key",
         "direct icon mapping empty-key rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct icon mapping ignores empty icon value",
         "direct icon mapping empty-value rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct icon mapping ignores unrepresentable filetype keys",
         "direct icon mapping key validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct icon mapping ignores line-break filetype keys",
         "direct icon mapping line-break key validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct icon mapping ignores vertical-tab filetype keys",
         "direct icon mapping vertical-tab key validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct icon mapping ignores Unicode line-separator filetype keys",
         "direct icon mapping Unicode line-separator key validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct icon mapping ignores unrepresentable values",
         "direct icon mapping value validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct icon mapping ignores form-feed values",
         "direct icon mapping form-feed value validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct icon mapping ignores Unicode line-separator values",
         "direct icon mapping Unicode line-separator value validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion ignores trailing modifier separator after a modifier",
         "direct open-action trailing modifier rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion ignores empty modifier segments",
         "direct open-action empty modifier segment rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion ignores empty executable",
         "direct open-action empty executable rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion ignores unrepresentable filetype keys",
         "direct open-action filetype-key validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion ignores quoted filetype keys",
         "direct open-action quoted-key validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion ignores bracketed filetype keys",
         "direct open-action bracketed-key validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion ignores modifier-only token",
         "direct open-action modifier-only rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "draft rejects current modifier-only open-action token",
         "settings draft validation must cover current modifier-only token rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "draft rejects stored modifier-only open-action tokens",
         "settings draft validation must cover stored modifier-only token rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion ignores embedded placeholders",
         "direct open-action embedded-placeholder rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion ignores executable placeholders",
         "direct open-action executable-placeholder rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion ignores executable line breaks",
         "direct open-action executable line-break rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion ignores executable form feeds",
         "direct open-action executable form-feed rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion ignores argument line breaks",
         "direct open-action argument line-break rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion ignores argument vertical tabs",
         "direct open-action argument vertical-tab rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion ignores executable Unicode line separators",
         "direct open-action executable Unicode separator rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion ignores argument Unicode line separators",
         "direct open-action argument Unicode separator rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "unknown open-action modifier is rejected",
         "settings parser unknown modifier rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty open action key is rejected",
         "settings parser must cover empty open-action key rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "quoted open-action filetype key is rejected",
         "settings parser must cover quoted open-action key rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bracketed open-action filetype key is rejected",
         "settings parser must cover bracketed open-action key rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "action token field rejects quoted filetype keys",
         "settings field diagnostics must cover quoted open-action key rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "action token field rejects bracketed filetype keys",
         "settings field diagnostics must cover bracketed open-action key rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "modifier-only open action key is rejected",
         "settings parser must cover modifier-only open-action key rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "dangling open-action modifier separator is rejected",
         "settings parser must cover dangling open-action modifier rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty open-action modifier segment is rejected",
         "settings parser must cover empty open-action modifier segment rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "embedded open-action placeholders are rejected",
         "settings parser unsafe placeholder rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "open-action executable placeholders are rejected",
         "settings parser executable placeholder rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "open-action executable vertical tabs are rejected",
         "settings parser executable control-character rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "open-action argument form feeds are rejected",
         "settings parser argument control-character rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings parser rejects Unicode line-separator mapping values",
         "settings parser Unicode separator mapping rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings parser rejects Unicode line-separator open actions",
         "settings parser Unicode separator open-action rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "unterminated quoted open action reports deterministic diagnostic key",
         "settings parser quoted-token validation must reject unterminated quotes");
      Project_Tools.Files.Require_Contains
        (Tests,
         "quoted open action trailing junk reports deterministic diagnostic key",
         "settings parser quoted-token validation must reject trailing junk");
      Project_Tools.Files.Require_Contains
        (Tests,
         "unquoted open-action executable quote is rejected",
         "settings parser quoted-token validation must reject unquoted executable quotes");
      Project_Tools.Files.Require_Contains
        (Tests,
         "unquoted open-action argument quote is rejected",
         "settings parser quoted-token validation must reject unquoted argument quotes");
      Project_Tools.Files.Require_Contains
        (Tests,
         "quoted executable preserves doubled quote",
         "settings parser must preserve doubled quotes in open-action executables");
      Project_Tools.Files.Require_Contains
        (Tests,
         "quoted argument preserves doubled quote",
         "settings parser must preserve doubled quotes in open-action arguments");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty quoted argument is preserved",
         "settings parser must preserve empty quoted open-action arguments");
      Project_Tools.Files.Require_Contains
        (Tests,
         "argument after empty quoted argument is preserved",
         "settings parser must continue after empty quoted open-action arguments");
      Project_Tools.Files.Require_Contains
        (Tests,
         "serialized open action preserves executable quote",
         "settings serialization must preserve quotes in open-action executables");
      Project_Tools.Files.Require_Contains
        (Tests,
         "serialized open action preserves argument quote",
         "settings serialization must preserve quotes in open-action arguments");
      Project_Tools.Files.Require_Contains
        (Tests,
         "serialized open action preserves empty argument",
         "settings serialization must preserve empty open-action arguments");
      Project_Tools.Files.Require_Contains
        (Tests,
         "equals-containing filetype mapping value parses",
         "settings parser must cover equals signs in mapping values");
      Project_Tools.Files.Require_Contains
        (Tests,
         "equals-containing action argument parses",
         "settings parser must cover equals signs in open-action arguments");
      Project_Tools.Files.Require_Contains
        (Tests,
         "serialized open action preserves equals argument",
         "settings serialization must preserve equals signs in open-action arguments");
      Project_Tools.Files.Require_Contains
        (Tests,
         "serialized filetype mapping preserves equals",
         "settings serialization must preserve equals signs in mapping values");
      Project_Tools.Files.Require_Contains
        (Tests,
         "quoted filetype mapping with trailing junk is rejected",
         "settings parser must cover quoted filetype mapping trailing junk");
      Project_Tools.Files.Require_Contains
        (Tests,
         "quoted icon mapping with trailing junk is rejected",
         "settings parser must cover quoted icon mapping trailing junk");
   end Check_Open_Action_Settings_Validation;

   procedure Check_Open_Action_Placeholder_Contract is
      Settings_Body : constant String := Root & "/src/files-settings.adb";
      Tests         : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "function Expand_Placeholders",
         "settings must keep open-action placeholder expansion centralized and testable");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Result.Arguments.Clear;",
         "placeholder expansion must rebuild the argument vector without mutating the source action");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Value = ""{path}"" then",
         "placeholder expansion must replace whole-argument path placeholders only");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "elsif Value = ""{parent}"" then",
         "placeholder expansion must replace whole-argument parent placeholders only");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "elsif Value = ""{name}"" then",
         "placeholder expansion must replace whole-argument name placeholders only");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "elsif Value = ""{stem}"" then",
         "placeholder expansion must replace whole-argument stem placeholders only");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "elsif Value = ""{extension}"" then",
         "placeholder expansion must replace whole-argument extension placeholders only");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "else" & ASCII.LF
         & "               Result.Arguments.Append (Argument);",
         "placeholder expansion must preserve literal non-placeholder arguments");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "function Safe_Simple_Name",
         "placeholder expansion must guard filename extraction errors");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Is_Path_Separator (Value (Index)) then",
         "placeholder expansion must recognize Unix and Windows separators");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "function Is_Path_Separator",
         "placeholder expansion must centralize path separator recognition");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "function UNC_Share_Root_Last",
         "placeholder expansion must recognize UNC share roots");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "return Value (Separator + 1 .. Value'Last);",
         "placeholder name extraction must use the last recognized separator");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "function Trim_Trailing_Path_Separators",
         "placeholder expansion must trim trailing separators before deriving path parts");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Clean     : constant String := Trim_Trailing_Path_Separators (Path);",
         "placeholder expansion must preserve the original path while deriving parts from a clean path");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "function Safe_Containing_Directory",
         "placeholder expansion must guard parent-directory extraction errors");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Dot = 0 or else Dot = Name'First then" & ASCII.LF
         & "            return Name;",
         "placeholder stem expansion must keep leading-dot names intact");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Dot = 0 or else Dot = Name'First or else Dot = Name'Last then",
         "placeholder extension expansion must ignore missing, leading, and trailing dots");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "return Normalize_Extension (Name (Dot + 1 .. Name'Last));",
         "placeholder extension expansion must normalize extracted extensions");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "return Contains_Known_Placeholder (Argument)" & ASCII.LF
         & "        and then not Is_Whole_Placeholder (Argument);",
         "embedded placeholder detection must distinguish unsafe interpolation from whole arguments");
      Project_Tools.Files.Require_Contains
        (Tests,
         "path placeholder expands as one argument",
         "placeholder tests must cover path expansion as a single argv value");
      Project_Tools.Files.Require_Contains
        (Tests,
         "parent placeholder expands",
         "placeholder tests must cover parent directory expansion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "name placeholder expands",
         "placeholder tests must cover filename expansion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "stem placeholder expands",
         "placeholder tests must cover filename stem expansion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "extension placeholder expands",
         "placeholder tests must cover extension expansion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "dotfile stem keeps leading-dot name",
         "placeholder tests must cover leading-dot stem behavior");
      Project_Tools.Files.Require_Contains
        (Tests,
         "dotfile extension expands to empty",
         "placeholder tests must cover leading-dot extension behavior");
      Project_Tools.Files.Require_Contains
        (Tests,
         "trailing-dot extension expands to empty",
         "placeholder tests must cover trailing-dot extension behavior");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty path parent expands to empty",
         "placeholder tests must cover empty path expansion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "relative path parent expands to current directory",
         "placeholder tests must cover relative path parent expansion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Windows path parent expands",
         "placeholder tests must cover Windows-style parent expansion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Windows drive-root path parent keeps root separator",
         "placeholder tests must cover Windows drive-root parent expansion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Windows placeholder extension ignores dotted directory names",
         "placeholder tests must cover Windows-style leaf extension extraction");
      Project_Tools.Files.Require_Contains
        (Tests,
         "UNC placeholder parent expands without losing the share root",
         "placeholder tests must cover UNC leaf parent expansion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "UNC share-root parent preserves the share root",
         "placeholder tests must cover UNC share-root parent expansion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "trailing separator name expands from trimmed path",
         "placeholder tests must cover name derivation from paths with trailing separators");
      Project_Tools.Files.Require_Contains
        (Tests,
         "path placeholder preserves trailing separator verbatim",
         "placeholder tests must cover original path preservation during placeholder expansion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "embedded path placeholder remains literal",
         "placeholder tests must cover literal embedded path placeholders");
      Project_Tools.Files.Require_Contains
        (Tests,
         "embedded stem placeholder remains literal",
         "placeholder tests must cover literal embedded stem placeholders");
      Project_Tools.Files.Require_Contains
        (Tests,
         "embedded placeholders are visible to safety checks",
         "placeholder tests must cover embedded placeholder safety detection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "executable placeholders make open actions unsafe",
         "placeholder tests must cover executable placeholder safety detection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "whole-argument placeholder is safe",
         "placeholder tests must cover whole-argument placeholder safety");
      Project_Tools.Files.Require_Contains
        (Tests,
         "unknown placeholder token is not treated as a known placeholder",
         "placeholder tests must cover unsupported placeholder tokens staying literal");
      Project_Tools.Files.Require_Contains
        (Tests,
         "unknown placeholder remains literal after expansion",
         "placeholder tests must cover unsupported placeholder expansion as a literal argument");
   end Check_Open_Action_Placeholder_Contract;

   procedure Check_Open_Action_Lookup_Contract is
      Settings_Body : constant String := Root & "/src/files-settings.adb";
      Tests         : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Modifiers (Files.Types.Shift_Key) then",
         "open-action modifier tokens must start with shift when active");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Modifiers (Files.Types.Control_Key) then",
         "open-action modifier tokens must include control after shift");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Modifiers (Files.Types.Alt_Key) then",
         "open-action modifier tokens must include alt after control");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Modifiers (Files.Types.Meta_Key) then",
         "open-action modifier tokens must include meta last");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Full_Token : constant String := Base_Token & Modifier_Token (Modifiers);",
         "open-action lookup must build the full filetype-plus-modifier token");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Settings.Open_Actions.Contains (Full_Token) then",
         "open-action lookup must try modifier-specific actions first");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "elsif Settings.Open_Actions.Contains (Base_Token) then",
         "open-action lookup must fall back to the unmodified filetype action");
      Project_Tools.Files.Require_Contains
        (Tests,
         "modifier tokens are emitted in stable lookup order",
         "open-action tests must cover stable modifier token ordering");
      Project_Tools.Files.Require_Contains
        (Tests,
         "missing modifier action falls back to unmodified filetype",
         "open-action tests must cover modifier lookup fallback");
      Project_Tools.Files.Require_Contains
        (Tests,
         "fallback token is unmodified filetype",
         "open-action tests must verify fallback reports the base token");
      Project_Tools.Files.Require_Contains
        (Tests,
         "missing open action records full normalized modifier order",
         "open-action tests must cover full normalized missing-action diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "lookup token uses normalized modifier order",
         "open-action tests must cover normalized parsed modifier order");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct open-action insertion normalizes modifiers",
         "open-action tests must cover direct insertion modifier normalization");
   end Check_Open_Action_Lookup_Contract;

   procedure Check_Operations_Open_Action_Contract is
      Operations_Body : constant String := Root & "/src/files-operations.adb";
      Tests           : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "function Prepare_Open_Selected_Action",
         "operations must expose open-action preparation without spawning");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "if Files.Model.Selected_Count (Model) = 0 or else Files.Model.Selection_Includes_Temporary (Model) then",
         "open operations must reject empty and temporary selections");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "return Disabled (Model, ""error.selection.empty"");",
         "open operations must record a localized disabled-selection diagnostic");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Files.Model.Set_Error (Model, ""error.open_action.multi_directory"");",
         "multi-selection open must reject directory entries before any open-action spawn");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Files.Settings.Lookup_Open_Action (Settings, To_String (Item.Filetype), Modifiers);",
         "file open must look up actions by filetype and active modifiers");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Files.Settings.Expand_Placeholders (Lookup.Action, To_String (Item.Full_Path));",
         "file open must expand placeholders against the selected file path");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Files.Settings.Has_Unsafe_Placeholder_Usage (Lookup.Action)",
         "file open must reject unsafe placeholder usage before execution");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "function Shell_Executable return String",
         "explicit shell open actions must keep shell executable selection centralized");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "function Safe_Environment_Value (Name : String) return String",
         "explicit shell open actions must guard environment variable reads");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Comspec : constant String := Safe_Environment_Value (""COMSPEC"");",
         "explicit shell open actions must support Windows COMSPEC selection through guarded reads");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Shell   : constant String := Safe_Environment_Value (""SHELL"");",
         "explicit shell open actions must support POSIX SHELL selection");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "return ""/bin/sh"";",
         "explicit shell open actions must keep a deterministic POSIX fallback shell");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "function Shell_Command_Option return String",
         "explicit shell open actions must centralize shell command option selection");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "return ""/C"";",
         "explicit shell open actions must use the Windows shell command option for COMSPEC");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "return ""-c"";",
         "explicit shell open actions must use the POSIX shell command option otherwise");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "and then Executable_Is_Available (Shell_Executable);",
         "explicit shell open actions must preflight the selected shell executable");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Files.File_System.Load_Directory (To_String (Prepared.Path), Settings);",
         "directory open must load the destination through the filesystem layer");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Files.Model.Navigate_To (Model, To_String (Load.Path), Load.Items);",
         "directory open must navigate the model with loaded immutable item data");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Open_Action_Executable_Is_Available (Prepared.Action)",
         "file open must preflight executable availability before spawning");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Execute_Open_Action (Prepared.Action, Exit_Status)",
         "file open must execute prepared actions through the operation executor");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Attempted => True",
         "file open results must expose whether process execution was attempted");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Exit_Known => True",
         "file open results must expose known process exit status");
      Project_Tools.Files.Require_Contains
        (Tests,
         "pending create open preparation reports disabled selection",
         "open-operation tests must cover temporary selection rejection during preparation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "multi-directory open is rejected",
         "open-operation tests must cover deterministic multi-directory rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "file open action can be prepared without spawn",
         "open-operation tests must cover preparation separate from execution");
      Project_Tools.Files.Require_Contains
        (Tests,
         "file open executes an action",
         "open-operation tests must cover configured file action execution");
      Project_Tools.Files.Require_Contains
        (Tests,
         "multi-file open preflights all actions before spawning",
         "open-operation tests must cover multi-file preflight before execution");
      Project_Tools.Files.Require_Contains
        (Tests,
         "multi-file open action can be prepared",
         "open-operation tests must cover multi-file preparation without execution");
      Project_Tools.Files.Require_Contains
        (Tests,
         "multi-file open preparation preflights all actions",
         "open-operation tests must cover multi-file preparation preflight");
      Project_Tools.Files.Require_Contains
        (Tests,
         "multi-file open preparation failure records no process attempt",
         "open-operation tests must cover non-executing multi-file preparation failures");
      Project_Tools.Files.Require_Contains
        (Tests,
         "multi-file open preflights missing executables before spawning",
         "open-operation tests must cover multi-file executable preflight before execution");
      Project_Tools.Files.Require_Contains
        (Tests,
         "multi-file executable preflight failure does not execute earlier selected action",
         "open-operation tests must prove executable preflight failures do not partially execute");
      Project_Tools.Files.Require_Contains
        (Tests,
         "multi-file open execution failure reports failing path",
         "open-operation tests must cover failing path metadata for multi-file execution failures");
      Project_Tools.Files.Require_Contains
        (Tests,
         "multi-file open execution failure exposes failing executable",
         "open-operation tests must cover failing executable metadata for multi-file execution failures");
      Project_Tools.Files.Require_Contains
        (Tests,
         "multi-file open execution failure records exit status",
         "open-operation tests must cover exit-status metadata for multi-file execution failures");
      Project_Tools.Files.Require_Contains
        (Tests,
         "missing open executable is represented",
         "open-operation tests must cover executable preflight failures");
      Project_Tools.Files.Require_Contains
        (Tests,
         "explicit shell uses SHELL fallback",
         "open-operation tests must cover POSIX shell executable selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "explicit shell prefers COMSPEC when present",
         "open-operation tests must cover Windows shell executable selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "missing shell executable is rejected before spawn",
         "open-operation tests must cover explicit shell executable preflight failures");
      Project_Tools.Files.Require_Contains
        (Tests,
         "explicit shell action keeps semicolon argument as one vector value",
         "open-operation tests must cover explicit shell argument-vector preservation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "file open quotes explicit shell arguments before execution",
         "open-operation tests must cover explicit shell argument quoting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "explicit shell action can execute shell builtins",
         "open-operation tests must cover explicit shell execution semantics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "nonzero explicit shell builtin is represented",
         "open-operation tests must cover explicit shell execution failures");
      Project_Tools.Files.Require_Contains
        (Tests,
         "failed open action execution is represented",
         "open-operation tests must cover failed process execution as data");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Return routes file open command",
         "open-operation tests must cover keyboard routing into the central command registry");
      Project_Tools.Files.Require_Contains
        (Tests,
         "double-click file routes open command",
         "open-operation tests must cover pointer activation through the central command registry");
   end Check_Operations_Open_Action_Contract;

   procedure Check_Settings_Serialization_Contract is
      Settings_Body : constant String := Root & "/src/files-settings.adb";
      Tests         : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "return To_Text (Default_Settings);",
         "default settings text must be produced through the normal serializer");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "package Sorting is new String_Vectors.Generic_Sorting",
         "settings serialization must keep deterministic key ordering");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Append_Line (""[settings]"");",
         "settings serialization must write the settings section");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Append_Line (""[filetypes]"");",
         "settings serialization must write filetype mappings");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Append_Line (""[icons]"");",
         "settings serialization must write icon mappings");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Append_Line (""[open-actions]"");",
         "settings serialization must write open actions");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Append (Result, ""shell:"");",
         "settings serialization must preserve explicit shell open-action opt-in");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Append (Result, '""');",
         "settings serialization must quote values that need quoting");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Append_Line (""icon_theme = "" & Action_Token_Text (To_String (Settings.Icon_Theme_Name)));",
         "settings serialization must quote icon theme values through the token writer");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Append_Line (""icon_theme = "" & Action_Token_Text (To_String (Draft.Icon_Theme_Name)));",
         "settings draft serialization must quote icon theme values through the token writer");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Append (Result, "
         & '"' & '"' & '"' & '"' & '"' & '"'
         & ");",
         "settings serialization must double embedded quote characters");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "return Save_Text (Path, To_Text (Applied.Settings));",
         "settings draft saves must serialize the applied settings model");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "function Load_File" & ASCII.LF
         & "     (Path : String)" & ASCII.LF
         & "      return Settings_Parse_Result" & ASCII.LF
         & "   is" & ASCII.LF
         & "      File : Ada.Text_IO.File_Type;" & ASCII.LF
         & "      Text : Unbounded_String := Null_Unbounded_String;" & ASCII.LF
         & "   begin" & ASCII.LF
         & "      if Path = """" then" & ASCII.LF
         & "         return" & ASCII.LF
         & "           (Success   => False,",
         "settings loader must reject empty settings paths before missing-file fallback");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "procedure Safe_Close",
         "settings persistence must centralize guarded file cleanup");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Safe_Close (File);",
         "settings persistence must use guarded file cleanup while recovering from errors");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Ada.Text_IO.Put (File, Text);" & ASCII.LF
         & "      Ada.Text_IO.Close (File);",
         "settings save must report close-time write failures instead of suppressing them");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Ada.Text_IO.Close (File);" & ASCII.LF
         & "         exception" & ASCII.LF
         & "            when others =>" & ASCII.LF
         & "               null;",
         "settings file cleanup must not raise while recovering from load or save errors");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "and then Ada.Directories.Kind (Path) /= Ada.Directories.Ordinary_File",
         "settings persistence must reject non-file destinations before writing");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Ada.Directories.Create_Path (Parent);",
         "settings persistence must create missing parent directories");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Ada.Directories.Kind (Parent) /= Ada.Directories.Directory then",
         "settings persistence must reject non-directory parent paths");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File then",
         "default settings creation must accept existing regular files without overwriting");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Path = """" then",
         "default settings creation must reject empty settings paths before filesystem probing");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "return Save_Text (Path, Default_Settings_Text);",
         "default settings creation must route missing files through guarded persistence");
      Project_Tools.Files.Require_Contains
        (Tests,
         "serialized settings text parses",
         "settings serialization round-trip must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty settings file path is rejected",
         "settings tests must cover rejected empty settings load paths");
      Project_Tools.Files.Require_Contains
        (Tests,
         "serialized quoted action preserves placeholder argument",
         "settings serialization quote preservation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "serialized shell action preserves shell opt-in",
         "settings serialization shell-prefix preservation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "serialized icon theme quotes embedded quote",
         "settings serialization must cover scalar icon-theme token quoting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "duplicate scalar settings parse deterministically",
         "settings parser tests must cover duplicate scalar setting behavior");
      Project_Tools.Files.Require_Contains
        (Tests,
         "duplicate default view setting uses the last value",
         "settings parser tests must cover duplicate default-view replacement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "duplicate hidden-file setting uses the last value",
         "settings parser tests must cover duplicate hidden-file replacement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "duplicate sort field setting uses the last value",
         "settings parser tests must cover duplicate sort-field replacement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "default settings text parses",
         "default settings serialization must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "default settings map directory icons",
         "default settings tests must cover built-in directory icon mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "default settings map symlink icons",
         "default settings tests must cover built-in symlink icon mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "default settings map executable icons",
         "default settings tests must cover built-in executable icon mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "default settings map text icons",
         "default settings tests must cover built-in text icon mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "default settings map Ada icons",
         "default settings tests must cover built-in Ada icon mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "default settings map PNG icons",
         "default settings tests must cover built-in image icon mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "default settings map tar icons",
         "default settings tests must cover built-in archive icon mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "default settings map audio icons",
         "default settings tests must cover built-in audio icon mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings text can be saved to a new path",
         "settings persistence tests must cover saving to a new settings path");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings save parent failure reports not-file diagnostic",
         "settings persistence tests must cover non-directory parent diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "ensure default settings creates parent directories",
         "settings persistence tests must cover default-file parent creation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "ensure default settings accepts existing regular file",
         "settings persistence tests must cover existing default-file preservation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "ensure default settings rejects empty settings path",
         "settings persistence tests must cover empty default settings paths");
      Project_Tools.Files.Require_Contains
        (Tests,
         "ensure default settings does not overwrite",
         "settings persistence tests must cover default-file non-overwrite behavior");
      Project_Tools.Files.Require_Contains
        (Tests,
         "ensure default settings rejects directory path",
         "settings persistence tests must cover default-file non-file rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "ensure default settings parent failure reports not-file diagnostic",
         "settings persistence tests must cover default-file parent diagnostics");
   end Check_Settings_Serialization_Contract;

   procedure Check_Settings_Editor_Contract is
      Settings_Body   : constant String := Root & "/src/files-settings.adb";
      Model_Body      : constant String := Root & "/src/files-model.adb";
      Controller_Body : constant String := Root & "/src/files-controller.adb";
      Commands_Body   : constant String := Root & "/src/files-commands.adb";
      Tests           : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "function Allowed_With_Settings_Pane",
         "settings pane command gating must remain centralized");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "Toggle_Settings_Pane_Command" & ASCII.LF
         & "            | Save_Settings_Command" & ASCII.LF
         & "            | Reset_Settings_Command" & ASCII.LF
         & "            | Open_Command_Palette_Command" & ASCII.LF
         & "            | Close_Command_Palette_Command =>",
         "settings pane must only allow settings and overlay commands by default");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "function Validate_Draft",
         "settings editor must validate drafts before applying or saving");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if not Draft_Mapping_Vectors_Are_Aligned (Draft) then",
         "settings draft validation must reject misaligned mapping vectors");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "function Draft_Mapping_Key_Text",
         "settings draft mapping edits must normalize keys before replacement");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "if Draft_Mapping_Key_Text (Kind, Keys.Element (Index)) = Key_Text then",
         "settings draft mapping edits must replace normalized duplicate rows");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "function Pair_Count",
         "settings editor row movement must use paired mapping rows");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "procedure Normalize_Settings_Draft",
         "settings editor must normalize externally supplied draft rows");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "procedure Delete_If_Present",
         "settings editor row removal must tolerate orphan mapping entries");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Key_Error : constant String := Draft_Mapping_Key_Error (Draft);",
         "settings draft validation must report mapping-key diagnostics");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Value_Error : constant String := Draft_Mapping_Value_Error (Draft);",
         "settings draft validation must report mapping-value diagnostics");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "return Parse (Draft_Settings_Text (Draft));",
         "settings draft validation must pass through the normal settings parser");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "Parsed : constant Settings_Parse_Result := Validate_Draft (Draft);",
         "settings draft apply must validate before mutating settings");
      Project_Tools.Files.Require_Contains
        (Tests,
         "normalized draft action replacement does not add a duplicate row",
         "tests must cover normalized settings draft action replacement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings field accepts structured-suffix modifier tokens",
         "tests must cover structured-suffix field diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "draft applies structured-suffix modifier action",
         "tests must cover draft application for structured-suffix open actions");
      Project_Tools.Files.Require_Contains
        (Tests,
         "saved draft persists structured-suffix open action executable",
         "tests must cover draft persistence for structured-suffix open actions");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "return Save_Text (Path, To_Text (Applied.Settings));",
         "settings draft save must serialize the applied settings model");
      Project_Tools.Files.Require_Contains
        (Settings_Body,
         "return Make_Draft (Default_Settings);",
         "settings reset must restore the default settings draft");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Files.Model.Begin_Settings_Edit (Model, Files.Settings.Make_Draft (Settings));",
         "settings pane opening must seed a draft from active settings");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Model.Settings_Pane_Open := not Model.Settings_Pane_Open;" & ASCII.LF
         & "      if Model.Settings_Pane_Open then" & ASCII.LF
         & "         Clear_Edit_State (Model);",
         "settings pane opening must clear pending rename and create-file edit state");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Model.Settings_Pane_Open := True;" & ASCII.LF
         & "      Clear_Edit_State (Model);",
         "settings draft entry must clear pending rename and create-file edit state");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "function Settings_Drafts_Equal",
         "settings editor result reporting must compare complete draft state");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "and then Settings_Drafts_Equal (Draft, Old_Draft)",
         "settings editor result reporting must not rely only on mapping lengths and indexes");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "or else Field > 12",
         "settings click handling must reject out-of-range field identifiers before model clamping");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "return Field in 7 | 9 | 11;",
         "settings click add/remove actions must only accept rendered mapping button fields");
      Project_Tools.Files.Require_Contains
        (Tests,
         "pure settings command does not open unseeded settings pane",
         "settings editor tests must cover pure settings toggle safety");
      Project_Tools.Files.Require_Contains
        (Tests,
         "pure settings command can close seeded settings pane",
         "settings editor tests must cover pure settings close behavior");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings pane opening clears pending create state",
         "settings editor tests must cover clearing pending create state on open");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings pane opening clears pending rename state",
         "settings editor tests must cover clearing pending rename state on open");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings pane opening clears active rename state",
         "settings editor tests must cover clearing active rename state on open");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Files.Model.Set_Settings_Draft (Model, Files.Settings.Reset_Draft_To_Defaults);",
         "settings reset command must replace the active draft with defaults");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Files.Settings.Apply_Draft (Settings, Files.Model.Settings_Draft_Of (Model));",
         "controller settings save must apply the visible draft");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Saved := Files.Settings.Save_Text (Settings_Path, Files.Settings.To_Text (Applied.Settings));",
         "controller settings save must write the applied settings text");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "if not Saved.Success then" & ASCII.LF
         & "         Files.Model.Set_Error (Model, To_String (Saved.Error_Key));",
         "controller settings save must handle write failures before live settings updates");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Settings := Applied.Settings;",
         "controller settings save must update the live settings model");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Operation := Files.Operations.Refresh (Model, Settings);",
         "controller settings save must refresh the current directory with new settings");
      Project_Tools.Files.Require_Contains
        (Tests,
         "closed settings pane cannot save settings",
         "settings editor tests must cover closed-pane save rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings draft validates editable values",
         "settings editor tests must cover draft validation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings draft applies to a settings model",
         "settings editor tests must cover applying drafts");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings draft saves to disk",
         "settings editor tests must cover draft persistence");
      Project_Tools.Files.Require_Contains
        (Tests,
         "invalid settings draft is not saved",
         "settings editor tests must cover invalid draft rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "misaligned filetype draft removal clears orphan key",
         "settings editor tests must cover repairing orphan filetype rows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "misaligned icon draft removal clears orphan value",
         "settings editor tests must cover repairing orphan icon rows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "misaligned open-action draft removal clears orphan key",
         "settings editor tests must cover repairing orphan open-action rows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "repaired misaligned open-action draft validates",
         "settings editor tests must cover validating repaired malformed drafts");
      Project_Tools.Files.Require_Contains
        (Tests,
         "begin settings edit drops orphan filetype rows",
         "settings editor tests must cover draft normalization on entry");
      Project_Tools.Files.Require_Contains
        (Tests,
         "begin settings edit syncs stale filetype selection",
         "settings editor tests must cover selected draft row resynchronization");
      Project_Tools.Files.Require_Contains
        (Tests,
         "draft rejects quoted open-action keys",
         "settings editor tests must cover quoted open-action key draft rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "draft rejects bracketed open-action keys",
         "settings editor tests must cover bracketed open-action key draft rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "controller rejects invalid settings draft",
         "settings editor tests must cover controller validation failures");
      Project_Tools.Files.Require_Contains
        (Tests,
         "controller saves edited settings draft",
         "settings editor tests must cover controller save success");
      Project_Tools.Files.Require_Contains
        (Tests,
         "controller settings save failure preserves live settings",
         "settings editor tests must cover failed writes preserving live settings");
      Project_Tools.Files.Require_Contains
        (Tests,
         "controller settings save reports post-save refresh failure",
         "settings editor tests must cover post-save refresh failure reporting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "reset settings draft restores default view mode",
         "settings editor tests must cover reset-to-defaults behavior");
      Project_Tools.Files.Require_Contains
        (Tests,
         "unsupported settings field does not clamp focus",
         "settings editor tests must cover invalid field click rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings value-field add click does not create a mapping row",
         "settings editor tests must cover forged value-field add-button rejection");
   end Check_Settings_Editor_Contract;

   procedure Check_Filesystem_Mutation_Safety is
      File_System_Body : constant String := Root & "/src/files-file_system.adb";
      Operations_Body  : constant String := Root & "/src/files-operations.adb";
      Tests            : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "elsif Ada.Directories.Exists (Path) then",
         "create-file mutation must refuse existing destinations");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Error_Key => To_Unbounded_String (""error.file.exists"")",
         "create-file mutation must report existing destination diagnostics");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Created : Boolean := False;",
         "create-file mutation must track whether it created a destination");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "procedure Delete_Created_File_If_Present is",
         "create-file mutation failures must clean up destinations created by the failed attempt");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Created := True;",
         "create-file mutation must mark the destination only after creation succeeds");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Delete_Created_File_If_Present;",
         "create-file mutation exception handling must remove newly-created failed destinations");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "and then Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File",
         "create-file mutation cleanup must only delete ordinary files it created");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "or else Ada.Directories.Kind (Parent) /= Ada.Directories.Directory",
         "create-file mutation must require an existing directory parent");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Exists_Safely (Path : String) return Boolean is",
         "rename mutation must use exception-safe path existence checks");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "if not Exists_Safely (From_Path) then",
         "rename mutation must precheck source existence safely");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Same_Existing_Path return Boolean is",
         "rename mutation must detect same-path no-op renames before destination checks");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "return From_Path = To_Path and then Exists_Safely (From_Path);",
         "rename same-path fallback must not raise while handling malformed paths");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "if not Ada.Directories.Exists (To_String (Item.Full_Path)) then",
         "rename no-op operation must reject stale missing selected sources");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "elsif Same_Existing_Path then",
         "rename mutation must allow same-path renames as successful no-ops");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "elsif Exists_Safely (To_Path)",
         "rename mutation must refuse existing destinations");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Ada.Directories.Rename (From_Path, To_Path);",
         "rename mutation must use Ada filesystem rename after validation");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Files.File_System.Move_To_Trash_Preflight (To_String (Item.Full_Path));",
         "multi-delete must preflight every selected item before mutation");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Move_To_Trash_Preflight",
         "trash mutation must expose a non-mutating preflight helper");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "if Environment_Equals (""FILES_TRASH_BACKEND"", ""windows"") then",
         "trash backend selection must use guarded environment comparison");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Xdg_Data_Home : constant String := Safe_Environment_Value (""XDG_DATA_HOME"");",
         "trash base selection must read XDG_DATA_HOME through guarded environment access");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Trash_Capabilities_Of_Current_Environment return Trash_Capabilities",
         "trash support must expose observable capability metadata");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Permanent_Delete    => False",
         "trash capabilities must not opt into permanent deletion");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Multi_Item_Preflight => True",
         "trash capabilities must advertise all-or-nothing multi-item preflight");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Native_Trash_Request_For",
         "trash support must expose native-backend request metadata");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Requires_Native_Api     => Backend in Trash_Windows_Recycle_Bin | Trash_Macos_Native",
         "native trash requests must distinguish OS-native backends from local trash moves");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Can_Use_Current_Process => Backend not in Trash_Windows_Recycle_Bin | Trash_Macos_Native",
         "native trash requests must identify when current-process execution is allowed");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Evaluate_Native_Trash",
         "trash support must expose non-mutating native-backend evaluation");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Would_Delete     => False",
         "native trash evaluation must not claim permanent deletion behavior");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Mutation := Move_To_Trash (To_String (Request.Path));",
         "current-process native trash execution must still route through the guarded trash move");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Trash_Backend_For_Base = Trash_Windows_Recycle_Bin",
         "trash preflight must reject native backends that are not available through this binding");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Source_Exists return Boolean is",
         "trash preflight must use exception-safe source existence checks");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "elsif not Source_Exists then",
         "trash preflight must reject missing source paths before mutation");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "elsif Base = """" then",
         "trash preflight must reject unavailable trash roots before mutation");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "elsif not Path_Can_Be_Directory (Base) then",
         "trash preflight must reject trash roots that cannot be directories");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "elsif Is_Same_Or_Inside (Base, Path)",
         "trash preflight must reject nested source/trash relationships");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "or else Is_Same_Or_Inside (Path, Base)",
         "trash preflight must reject sources that contain the configured trash root");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Clean_Child (Next) = '/' or else Clean_Child (Next) = '\'",
         "trash preflight nested-path checks must require a path-boundary separator");
      Project_Tools.Files.Require_Contains
        (Tests,
         "trash preflight accepts sibling paths sharing a prefix",
         "trash preflight tests must cover path-boundary prefix siblings");
      Project_Tools.Files.Require_Contains
        (Tests,
         "trash prefix-sibling preflight has no diagnostic",
         "trash preflight tests must cover successful prefix-sibling diagnostics");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);" & ASCII.LF
         & "                  pragma Unreferenced (Reload);" & ASCII.LF
         & "               begin" & ASCII.LF
         & "                  Files.Model.Set_Error (Model, To_String (Preflight.Error_Key));",
         "preflight delete failures must reload stale models without losing the original diagnostic");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Files.File_System.Move_To_Trash (To_String (Item.Full_Path));",
         "delete must route through the platform trash operation");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings);" & ASCII.LF
         & "                  pragma Unreferenced (Reload);" & ASCII.LF
         & "               begin" & ASCII.LF
         & "                  Files.Model.Set_Error (Model, To_String (Mutation.Error_Key));",
         "trash mutation failures must reload stale models without losing the original diagnostic");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Trash_Deletion_Date",
         "trash metadata timestamp formatting must remain a tested helper");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "while Remaining >= 1.0 loop",
         "trash metadata timestamp formatting must floor fractional seconds");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         """DeletionDate="" & Trash_Deletion_Date (Ada.Calendar.Clock)",
         "trashinfo metadata writing must use the guarded timestamp formatter");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Unique_Trash_Name",
         "trash moves must choose collision-safe destination names");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Candidate := To_Unbounded_String (""untitled "" & Counter_Text & "".txt"");" & ASCII.LF
         & "         exit when Counter = Positive'Last;" & ASCII.LF
         & "         Counter := Counter + 1;",
         "untitled name generation must not overflow its collision counter");
      Project_Tools.Files.Require_Contains
        (Tests,
         "untitled name generation skips directory collisions",
         "untitled name generation must treat occupied directory names as collisions");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Candidate := To_Unbounded_String (Name & ""."" & Image_No_Space (Counter));" & ASCII.LF
         & "            exit when Counter = Positive'Last;" & ASCII.LF
         & "            Counter := Counter + 1;",
         "trash collision naming must not overflow its collision counter");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "or else Ada.Directories.Exists (Join_Path (Info_Directory, To_String (Candidate) & "".trashinfo""))",
         "trash collision detection must account for existing metadata sidecars");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Trash_Info_Path_Value",
         "trashinfo path values must be encoded through a dedicated helper");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Delete_Info_File_If_Present;",
         "trash failures must clean up metadata sidecars after failed moves");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.ads",
         "function Valid_Leaf_Name",
         "filesystem mutation API must expose shared leaf-name validation");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Valid_Leaf_Name",
         "filesystem mutations must own shared leaf-name validation");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Mutation_Leaf_Name",
         "direct filesystem mutations must extract destination leaf names safely");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "elsif not Valid_Leaf_Name (Name) then",
         "direct file creation must reject invalid leaf names before mutation");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "elsif not Valid_Leaf_Name (Name) then" & ASCII.LF
         & "         return" & ASCII.LF
         & "           (Success   => False," & ASCII.LF
         & "            Error_Key => To_Unbounded_String (""error.name.invalid""));",
         "direct rename must reject invalid leaf names before mutation");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Name = """"",
         "file mutation leaf-name validation must reject empty names");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Name = "".""",
         "file mutation leaf-name validation must reject dot names");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Name = ""..""",
         "file mutation leaf-name validation must reject parent-directory names");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Name (Name'Last) = ' '",
         "file mutation leaf-name validation must reject trailing spaces");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Name (Name'Last) = '.'",
         "file mutation leaf-name validation must reject trailing dots");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Is_Windows_Device_Name (Name)",
         "file mutation leaf-name validation must reject reserved device names");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Base = ""CONIN$""",
         "file mutation leaf-name validation must reject console input device names");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Base = ""CONOUT$""",
         "file mutation leaf-name validation must reject console output device names");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Character_Value = '/'",
         "file mutation leaf-name validation must reject path separators");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Character_Value = '\'",
         "file mutation leaf-name validation must reject platform path separators");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Codepoint < 32",
         "file mutation leaf-name validation must reject control characters");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "not Files.UTF8.Is_Valid (Name)",
         "file mutation leaf-name validation must use the shared UTF-8 validator");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Is_All_Whitespace",
         "file mutation leaf-name validation must reject whitespace-only names");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Ends_With_Whitespace",
         "file mutation leaf-name validation must reject trailing Unicode whitespace");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Files.UTF8.Whitespace_Separator_Length (Name, Position)",
         "file mutation leaf-name validation must use the shared UTF-8 whitespace helper");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Files.UTF8.Decode_Next_Codepoint",
         "file mutation leaf-name validation must decode through the shared UTF-8 helper");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Codepoint in 16#80# .. 16#9F#",
         "file mutation leaf-name validation must reject encoded C1 controls explicitly");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Codepoint < 128",
         "file mutation leaf-name validation must still inspect ASCII reserved filename characters");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.ads",
         "function Is_Valid",
         "shared UTF-8 helper must expose strict validation for mutation paths");
      Require_Not_Contains
        (Operations_Body,
         "function Valid_UTF8_Sequence_Length",
         "file mutation leaf-name validation must not keep a local UTF-8 parser");
      Require_Not_Contains
        (Operations_Body,
         "function Valid_Leaf_Name",
         "operations must not duplicate filesystem leaf-name validation");
      Require_Not_Contains
        (Operations_Body,
         "function Windows_Device_Basename",
         "operations must not duplicate reserved-device validation helpers");
      Require_Not_Contains
        (Operations_Body,
         "function Is_All_Whitespace",
         "operations must not duplicate whitespace-only validation helpers");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper rejects overlong multibyte text",
         "tests must cover strict shared UTF-8 validation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct create rejects invalid leaf names",
         "tests must cover direct filesystem create leaf-name validation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct rename rejects invalid leaf names",
         "tests must cover direct filesystem rename leaf-name validation");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "elsif not Files.File_System.Valid_Leaf_Name (Name) then",
         "create-file commit must use shared filesystem leaf-name validation before mutation");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings, Name);",
         "create-file commit must reload the directory with the new item selected");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Files.Model.Clear_Edit_State (Model);" & ASCII.LF
         & "      Files.Model.Set_Error (Model, """");" & ASCII.LF
         & "      return" & ASCII.LF
         & "        Make_Result" & ASCII.LF
         & "          (Operation_Success,",
         "create-file commit must clear edit and error state after a successful reload");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "if not Files.File_System.Valid_Leaf_Name (New_Name) then",
         "rename commit must use shared filesystem leaf-name validation before mutation");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Reload : constant Operation_Result := Reload_Current_Directory (Model, Settings, New_Name);",
         "rename commit must reload the directory with the renamed item selected");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Files.Model.Clear_Edit_State (Model);" & ASCII.LF
         & "         Files.Model.Set_Error (Model, """");" & ASCII.LF
         & "         return" & ASCII.LF
         & "           Make_Result" & ASCII.LF
         & "             (Operation_Success,",
         "rename commit must clear edit and error state after a successful reload");
      Project_Tools.Files.Require_Contains
        (Tests,
         "partial multi-delete does not move earlier files before preflight failure",
         "multi-delete preflight failure must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "partial multi-delete keeps error state",
         "multi-delete preflight diagnostics must remain covered by AUnit after stale-model reloads");
      Project_Tools.Files.Require_Contains
        (Tests,
         "multi-delete nested trash preflight preserves model error",
         "nested trash preflight diagnostics must remain covered by AUnit after stale-model reloads");
      Project_Tools.Files.Require_Contains
        (Tests,
         "multi-delete preflights nested trash targets",
         "nested trash preflight failures must remain covered for multi-selection delete");
      Project_Tools.Files.Require_Contains
        (Tests,
         "multi-delete nested trash preflight does not move earlier selected files",
         "nested trash preflight must remain covered for all-or-nothing multi-delete behavior");
      Project_Tools.Files.Require_Contains
        (Tests,
         "multi-delete nested trash preflight does not create a trash target for earlier files",
         "nested trash preflight must remain covered for avoiding partial trash staging");
      Project_Tools.Files.Require_Contains
        (Tests,
         "unavailable trash backend reports no metadata sidecar support",
         "trash capability tests must cover unavailable-backend metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "malformed trash target reports failed trash diagnostic",
         "trash preflight tests must cover malformed source path diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "trash capabilities expose native diagnostic policy",
         "trash capability tests must cover native diagnostic metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "trash capabilities expose multi-item preflight policy",
         "trash capability tests must cover multi-item preflight metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "XDG trash backend reports trashinfo sidecar support",
         "trash capability tests must cover XDG metadata sidecar support");
      Project_Tools.Files.Require_Contains
        (Tests,
         "XDG trash backend reports collision-safe naming",
         "trash capability tests must cover collision-safe trash naming metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "native trash capability does not opt into permanent deletion",
         "trash capability tests must cover permanent-deletion non-goal");
      Project_Tools.Files.Require_Contains
        (Tests,
         "native trash request records native API requirement",
         "native trash tests must cover native API request metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "native trash request does not claim local fallback",
         "native trash tests must cover unavailable local fallback for OS-native backends");
      Project_Tools.Files.Require_Contains
        (Tests,
         "native trash evaluation does not attempt mutation",
         "native trash tests must cover non-mutating native preflight");
      Project_Tools.Files.Require_Contains
        (Tests,
         "native trash result reports native-unavailable diagnostic",
         "native trash tests must cover localized unavailable diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "XDG trash request can execute in current process",
         "native trash tests must cover current-process execution for XDG trash");
      Project_Tools.Files.Require_Contains
        (Tests,
         "XDG trash execution records binding unit",
         "native trash tests must cover current-process binding metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "XDG trash execution moves source entry",
         "native trash tests must cover current-process move execution");
      Project_Tools.Files.Require_Contains
        (Tests,
         "trash deletion date does not round up near midnight",
         "trash deletion timestamp flooring must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "trash preflight rejects items already inside trash",
         "trash preflight nested-path rejection must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "trash collision chooses suffix",
         "trash collision-safe naming must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "trash sidecar-only collision chooses suffix",
         "trash sidecar-only collision-safe naming must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "trashinfo path percent-encodes spaces and percent signs",
         "trashinfo path escaping must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "failed nested trash removes stale trashinfo metadata",
         "trash metadata cleanup after failed moves must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "failed create leaves existing file content unchanged",
         "create no-overwrite behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "missing parent create reports parent diagnostic",
         "create parent validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "non-directory parent create reports parent diagnostic",
         "create non-directory parent validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create reports empty destination failure",
         "direct create mutation must reject empty destinations");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create refuses an existing directory destination",
         "direct create mutation must reject existing directory destinations");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct create mutation succeeds",
         "direct create mutation success path must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create commit clears temporary state",
         "create success must remain covered for temporary-state cleanup");
      Project_Tools.Files.Require_Contains
        (Tests,
         "created item is selected after reload",
         "create success must remain covered for post-reload selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create retry selects created file",
         "create retry success must remain covered for post-reload selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "failed rename preserves destination",
         "rename no-overwrite behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create refuses an existing file destination",
         "direct create helper must reject existing file destinations");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct existing-file create preserves file content",
         "direct create helper must preserve existing file contents");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct rename refuses an existing file destination",
         "direct rename helper must reject existing file destinations");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct rename preserves existing destination file",
         "direct rename helper must preserve existing file destinations");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct failed rename leaves source in place",
         "direct rename helper must preserve source files on destination collision");
      Project_Tools.Files.Require_Contains
        (Tests,
         "missing parent rename leaves source in place",
         "rename missing-parent validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "non-directory parent rename leaves source in place",
         "rename non-directory parent validation must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename reports missing source failure",
         "direct rename mutation must reject missing sources");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename reports empty destination failure",
         "direct rename mutation must reject empty destinations");
      Project_Tools.Files.Require_Contains
        (Tests,
         "malformed same-path rename reports source-missing diagnostic",
         "direct rename mutation must cover malformed same-path fallback safety");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty destination rename leaves source in place",
         "direct rename empty-destination failure must preserve source files");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct rename mutation succeeds",
         "direct rename mutation success path must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct same-path rename is a successful no-op",
         "rename same-path no-op behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct normalized same-path rename is a successful no-op",
         "rename normalized same-path no-op behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "same-name rename reports disappeared source",
         "rename same-name operation must cover stale missing selected sources");
      Project_Tools.Files.Require_Contains
        (Tests,
         "same-name disappeared source clears stale rename mode",
         "rename stale same-name failure must clear edit state after reload");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename commit clears edit state",
         "rename success must remain covered for edit-state cleanup");
      Project_Tools.Files.Require_Contains
        (Tests,
         "renamed item is selected after reload",
         "rename success must remain covered for post-reload selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects path separator names",
         "create invalid-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects Windows-reserved names",
         "create reserved-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects wildcard names",
         "create wildcard-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects trailing-dot names",
         "create trailing-dot invalid-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects trailing-space names",
         "create trailing-space invalid-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects NBSP-only names",
         "create Unicode whitespace-only invalid-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects trailing NBSP names",
         "create trailing Unicode whitespace behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects trailing ideographic-space names",
         "create trailing wide Unicode whitespace behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects reserved device names",
         "create reserved-device invalid-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects padded device names",
         "create padded-device invalid-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects mixed-case padded device names",
         "create mixed-case padded-device invalid-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects console device names",
         "create console-device invalid-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects embedded NUL names",
         "create NUL-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects control-character names",
         "create control-character behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects path separator names",
         "rename invalid-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects Windows-reserved names",
         "rename reserved-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects wildcard names",
         "rename wildcard-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects trailing-dot names",
         "rename trailing-dot invalid-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects trailing-space names",
         "rename trailing-space invalid-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects ideographic-space-only names",
         "rename Unicode whitespace-only invalid-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects trailing NBSP names",
         "rename trailing Unicode whitespace behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects trailing ideographic-space names",
         "rename trailing wide Unicode whitespace behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects reserved device names",
         "rename reserved-device invalid-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects padded device names",
         "rename padded-device invalid-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects mixed-case padded device names",
         "rename mixed-case padded-device invalid-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects console device names",
         "rename console-device invalid-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects embedded NUL names",
         "rename NUL-name behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects control-character names",
         "rename control-character behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create accepts two-byte UTF-8 names",
         "create UTF-8 two-byte behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create accepts three-byte UTF-8 names",
         "create UTF-8 three-byte behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create accepts four-byte UTF-8 names",
         "create UTF-8 four-byte behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects truncated UTF-8 names",
         "create malformed UTF-8 behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects overlong UTF-8 names",
         "create overlong UTF-8 behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create rejects UTF-8 encoded C1 control-character names",
         "create encoded-control UTF-8 behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects truncated UTF-8 names",
         "rename malformed UTF-8 behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects overlong UTF-8 names",
         "rename overlong UTF-8 behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename accepts UTF-8 names",
         "rename UTF-8 success behavior must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename rejects UTF-8 encoded C1 control-character names",
         "rename encoded-control UTF-8 behavior must remain covered by AUnit");
   end Check_Filesystem_Mutation_Safety;

   procedure Check_Filetype_Detection_Order is
      File_Types_Body : constant String := Root & "/src/files-file_types.adb";
   begin
      Project_Tools.Files.Require_Contains
        (File_Types_Body,
         "when Files.Types.Directory_Item =>",
         "filetype detection must classify directories before extension lookup");
      Project_Tools.Files.Require_Contains
        (File_Types_Body,
         "when Files.Types.Symlink_Item =>",
         "filetype detection must classify symlinks before extension lookup");
      Project_Tools.Files.Require_Contains
        (File_Types_Body,
         "when Files.Types.Executable_Item =>",
         "filetype detection must classify executables before extension lookup");
      Project_Tools.Files.Require_Contains
        (File_Types_Body,
         "Mapped : constant String := Filetype_For_Name (Settings, Name);",
         "filetype detection must only use extension mappings after kind-specific cases");
      Project_Tools.Files.Require_Contains
        (File_Types_Body,
         "Files.UTF8.Whitespace_Separator_Length (Name, First_Offset)",
         "filetype filename trimming must use the shared UTF-8 whitespace helper");
      Project_Tools.Files.Require_Contains
        (File_Types_Body,
         "Files.UTF8.Next_Boundary (Name, Position)",
         "filetype filename trimming must advance over whole UTF-8 units");
      Project_Tools.Files.Require_Contains
        (File_Types_Body,
         "function Leaf_Name (Name : String) return String is",
         "filetype detection must strip directory components before extension lookup");
      Project_Tools.Files.Require_Contains
        (File_Types_Body,
         "if Clean (Index) = '/' or else Clean (Index) = '\' then",
         "filetype leaf-name extraction must recognize Unix and Windows separators");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "filetype detection normalizes filename extension case before mapping",
         "filetype detection tests must cover filename extension case normalization");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "extension extraction trims vertical-tab and form-feed whitespace",
         "filetype detection tests must cover control whitespace extension trimming");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "extension extraction trims UTF-8 NBSP whitespace",
         "filetype detection tests must cover UTF-8 NBSP extension trimming");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "extension extraction trims UTF-8 line-separator whitespace",
         "filetype detection tests must cover UTF-8 line-separator extension trimming");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "filetype detection trims vertical-tab and form-feed filename whitespace before mapping",
         "filetype detection tests must cover control whitespace detection trimming");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "filetype detection trims UTF-8 NBSP filename whitespace before mapping",
         "filetype detection tests must cover UTF-8 NBSP detection trimming");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "filetype detection trims UTF-8 line-separator filename whitespace before mapping",
         "filetype detection tests must cover UTF-8 line-separator detection trimming");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "settings-aware executable helper item ignores extension mappings",
         "filetype detection tests must cover helper executable precedence over extension mapping");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "settings-aware symlink helper item ignores extension mappings",
         "filetype detection tests must cover helper symlink precedence over extension mapping");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "unknown item filetype still uses configured extension mappings",
         "filetype detection tests must cover unknown-kind extension mapping");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "other item filetype falls back deterministically without mapping",
         "filetype detection tests must cover other-kind fallback classification");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "directory icon falls back by item kind without mapping",
         "filetype detection tests must cover directory icon fallback by kind");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "symlink icon falls back by item kind without mapping",
         "filetype detection tests must cover symlink icon fallback by kind");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "executable icon falls back by item kind without mapping",
         "filetype detection tests must cover executable icon fallback by kind");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "other item icon falls back deterministically without mapping",
         "filetype detection tests must cover other-kind icon fallback");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "extension extraction normalizes case",
         "filetype detection tests must cover extension extraction case normalization");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "extension extraction ignores dotted directory names",
         "filetype detection tests must cover path leaf extension extraction");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "filetype detection ignores dotted directory names",
         "filetype detection tests must cover path leaf filetype detection");
   end Check_Filetype_Detection_Order;

   procedure Check_Directory_Loading_Contract is
      File_System_Body : constant String := Root & "/src/files-file_system.adb";
      Tests            : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Load_Directory",
         "filesystem layer must expose real directory loading");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Ada.Directories.Start_Search",
         "directory loading must inspect direct filesystem entries");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "procedure Safe_End_Search",
         "filesystem directory searches must centralize guarded cleanup");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "File : in out Ada.Text_IO.File_Type",
         "filesystem text-file cleanup must use a guarded close helper");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "File : in out Ada.Streams.Stream_IO.File_Type",
         "filesystem stream-file cleanup must use a guarded close helper");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Pointer : in out Interfaces.C.Strings.chars_ptr",
         "filesystem C-string cleanup must use a guarded free helper");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Ada.Text_IO.Close (File);" & ASCII.LF
         & "         exception" & ASCII.LF
         & "            when others =>" & ASCII.LF
         & "               null;",
         "filesystem text-file cleanup must not raise while recovering from file errors");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Ada.Streams.Stream_IO.Close (File);" & ASCII.LF
         & "         exception" & ASCII.LF
         & "            when others =>" & ASCII.LF
         & "               null;",
         "filesystem stream-file cleanup must not raise while recovering from file errors");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Interfaces.C.Strings.Free (Pointer);" & ASCII.LF
         & "         exception" & ASCII.LF
         & "            when others =>" & ASCII.LF
         & "               null;",
         "filesystem C-string cleanup must not raise while recovering from native API errors");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Safe_End_Search (Search, Started);",
         "filesystem directory searches must use guarded cleanup on success and failure");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Ada.Directories.End_Search (Search);" & ASCII.LF
         & "         exception" & ASCII.LF
         & "            when others =>" & ASCII.LF
         & "               null;",
         "filesystem search cleanup must not raise while recovering from directory errors");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "and then (Settings.Show_Hidden_Files or else Name (Name'First) /= '.')",
         "directory loading must apply the hidden-file setting while preserving the full model");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Files.File_Types.Detect_Filetype (Settings, Kind, Name)",
         "directory loading must classify filetypes through the filetype layer");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Creation_Time      => Ada.Calendar.Time_Of (1901, 1, 1)",
         "directory loading must use a deterministic missing-creation timestamp sentinel");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Item.Metadata_Error := True;",
         "directory loading must keep items visible when metadata reading fails");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "if Kind = Files.Types.Symlink_Item then" & ASCII.LF
         & "                     Item.Filetype_Extra :=" & ASCII.LF
         & "                       To_Unbounded_String (Extra_Info_Token (Full, Kind, Filetype));",
         "directory loading must preserve symlink target metadata before risky metadata reads");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Item.Error_Key := To_Unbounded_String (""error.metadata.read"");",
         "directory loading must report partial metadata errors with localized keys");
      if Contains (File_System_Body, "Sort_Directories_First") then
         Put_Line ("directory loading must not group directories separately from files");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "return Field_Less (Left, Right, Settings);",
         "directory loading must route ordering through the configured sort field");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Sorting.Sort (Items);",
         "directory loading must sort entries deterministically before returning them");
      Project_Tools.Files.Require_Contains
        (Tests,
         "all direct children are loaded",
         "directory loading tests must cover direct child enumeration");
      Project_Tools.Files.Require_Contains
        (Tests,
         "missing directory load reports failure",
         "directory loading tests must cover missing-directory failures");
      Project_Tools.Files.Require_Contains
        (Tests,
         "file path directory load reports failure",
         "directory loading tests must cover file paths rejected as directories");
      Project_Tools.Files.Require_Contains
        (Tests,
         "directory projection loads",
         "directory loading tests must cover configured item projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "directory items sort by name with files",
         "directory loading tests must cover non-grouped directory ordering");
      Project_Tools.Files.Require_Contains
        (Tests,
         "case-insensitive equal names use deterministic fallback order",
         "directory loading tests must cover stable name fallback ordering");
      Project_Tools.Files.Require_Contains
        (Tests,
         "hidden files are hidden by default",
         "directory loading tests must cover hidden-file filtering");
      Project_Tools.Files.Require_Contains
        (Tests,
         "show-hidden setting exposes dot files",
         "directory loading tests must cover hidden-file visibility settings");
      Project_Tools.Files.Require_Contains
        (Tests,
         "hidden file participates in stable sorting",
         "directory loading tests must keep hidden-file ordering deterministic when visible");
      Project_Tools.Files.Require_Contains
        (Tests,
         "leading-dot file loaded from disk does not use extension mapping",
         "directory loading tests must cover leading-dot filename extension behavior");
      Project_Tools.Files.Require_Contains
        (Tests,
         "hidden directories are hidden by default",
         "directory loading tests must cover hidden-directory filtering");
      Project_Tools.Files.Require_Contains
        (Tests,
         "show-hidden setting exposes dot directories",
         "directory loading tests must cover hidden-directory visibility settings");
      Project_Tools.Files.Require_Contains
        (Tests,
         "hidden directories sort by name with files",
         "directory loading tests must keep hidden directories in normal name ordering");
      Project_Tools.Files.Require_Contains
        (Tests,
         "hidden files remain in deterministic order",
         "directory loading tests must keep hidden file ordering deterministic");
      Project_Tools.Files.Require_Contains
        (Tests,
         "hidden files sort by name with other items",
         "directory loading tests must keep hidden files in normal name ordering");
      Project_Tools.Files.Require_Contains
        (Tests,
         "ascending size ties use name fallback",
         "directory loading tests must cover ascending size tie fallback");
      Project_Tools.Files.Require_Contains
        (Tests,
         "ascending size tie fallback is deterministic",
         "directory loading tests must cover deterministic ascending size ties");
      Project_Tools.Files.Require_Contains
        (Tests,
         "ascending size places larger item after ties",
         "directory loading tests must cover ascending size field ordering after ties");
      Project_Tools.Files.Require_Contains
        (Tests,
         "descending size places larger item first",
         "directory loading tests must cover descending size field ordering");
      Project_Tools.Files.Require_Contains
        (Tests,
         "descending size ties keep deterministic name fallback",
         "directory loading tests must cover descending size tie fallback");
      Project_Tools.Files.Require_Contains
        (Tests,
         "descending size tie fallback remains stable",
         "directory loading tests must cover stable descending size ties");
      Project_Tools.Files.Require_Contains
        (Tests,
         "modified sort orders older item first",
         "directory loading tests must cover ascending modified-time sorting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "descending modified sort orders newer item first",
         "directory loading tests must cover descending modified-time sorting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "sort field setting parses",
         "settings tests must cover persisted sort-field parsing for directory loading");
      Project_Tools.Files.Require_Contains
        (Tests,
         "sort direction setting parses",
         "settings tests must cover persisted sort-direction parsing for directory loading");
      Project_Tools.Files.Require_Contains
        (Tests,
         "creation timestamp is populated when the filesystem reports it",
         "directory metadata tests must cover optional creation timestamps");
      Project_Tools.Files.Require_Contains
        (Tests,
         "modified timestamp is available",
         "directory metadata tests must cover modified timestamp availability");
      Project_Tools.Files.Require_Contains
        (Tests,
         "file size is available",
         "directory metadata tests must cover file size availability");
      Project_Tools.Files.Require_Contains
        (Tests,
         "metadata policy uses extension mappings",
         "directory metadata tests must cover the declared filetype metadata policy");
      Project_Tools.Files.Require_Contains
        (Tests,
         "metadata policy does not claim MIME sniffing",
         "directory metadata tests must keep MIME sniffing out of first implementation policy");
      Project_Tools.Files.Require_Contains
        (Tests,
         "metadata policy parses image dimensions",
         "directory metadata tests must cover image-dimension metadata policy");
      Project_Tools.Files.Require_Contains
        (Tests,
         "JPEG dimensions tolerate fill bytes before frame markers",
         "directory metadata tests must cover JPEG marker fill bytes");
      Project_Tools.Files.Require_Contains
        (Tests,
         "metadata policy parses text encoding",
         "directory metadata tests must cover text-encoding metadata policy");
      Project_Tools.Files.Require_Contains
        (Tests,
         "metadata policy parses archive entry counts",
         "directory metadata tests must cover archive entry-count metadata policy");
      Project_Tools.Files.Require_Contains
        (Tests,
         "ZIP entry counting detects signatures split across read buffers",
         "directory metadata tests must cover archive signatures split across read buffers");
      Project_Tools.Files.Require_Contains
        (Tests,
         "metadata policy parses PDF page markers",
         "directory metadata tests must cover PDF marker metadata policy");
      Project_Tools.Files.Require_Contains
        (Tests,
         "metadata policy does not claim media codecs",
         "directory metadata tests must keep codec parsing out of first implementation policy");
      Project_Tools.Files.Require_Contains
        (Tests,
         "metadata policy parses Office package info",
         "directory metadata tests must cover Office package metadata policy");
      Project_Tools.Files.Require_Contains
        (Tests,
         "permission metadata has stable rwx shape",
         "directory metadata tests must cover permission metadata shape");
      Project_Tools.Files.Require_Contains
        (Tests,
         "executable metadata affects item kind",
         "directory metadata tests must cover executable metadata classification");
      Project_Tools.Files.Require_Contains
        (Tests,
         "executable permission is captured",
         "directory metadata tests must cover executable permission metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "regular file permissions are captured",
         "directory metadata tests must cover regular file permission metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "real symlink directory item ignores extension mappings",
         "directory metadata tests must cover real symlink filetype precedence");
      Project_Tools.Files.Require_Contains
        (Tests,
         "real symlink directory item records target metadata",
         "directory metadata tests must cover real symlink target metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "executable symlink filetype wins before executable metadata",
         "directory metadata tests must cover symlink precedence over executable classification");
      Project_Tools.Files.Require_Contains
        (Tests,
         "executable symlink item was loaded",
         "directory metadata tests must assert the executable symlink fixture was loaded");
      Project_Tools.Files.Require_Contains
        (Tests,
         "mapped regular-file icon classification trims filetype whitespace",
         "filetype tests must cover whitespace-trimmed mapped regular icon lookup");
      Project_Tools.Files.Require_Contains
        (Tests,
         "directory item counts are loaded as filetype-specific metadata",
         "directory metadata tests must cover directory-specific extra metadata");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "package Stream_IO renames Ada.Streams.Stream_IO;",
         "text line counting must use stream I/O instead of fixed-size text chunks");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "if Count < Extra_Line_Limit and then Saw_Byte and then not Last_Was_LF then",
         "text line counting must count a final unterminated physical line");
      Project_Tools.Files.Require_Contains
        (Tests,
         "long text lines count as one physical line",
         "directory metadata tests must cover long line counting without chunk overcounting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "UTF-8 text files expose text encoding metadata",
         "directory metadata tests must cover UTF-8 text metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "invalid text files expose binary encoding metadata",
         "directory metadata tests must cover invalid text encoding metadata");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "Byte_Value = 16#E0# and then Second < 16#A0#",
         "text encoding detection must reject overlong three-byte UTF-8 sequences");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "Byte_Value = 16#ED# and then Second > 16#9F#",
         "text encoding detection must reject UTF-8 surrogate sequences");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "Byte_Value = 16#F0# and then Second < 16#90#",
         "text encoding detection must reject overlong four-byte UTF-8 sequences");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "Byte_Value = 16#F4# and then Second > 16#8F#",
         "text encoding detection must reject out-of-range four-byte UTF-8 sequences");
      Project_Tools.Files.Require_Contains
        (Tests,
         "overlong UTF-8 text files expose binary encoding metadata",
         "directory metadata tests must cover overlong UTF-8 rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "surrogate UTF-8 text files expose binary encoding metadata",
         "directory metadata tests must cover surrogate UTF-8 rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Markdown files expose markdown line and encoding metadata",
         "directory metadata tests must cover Markdown metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "PNG dimensions are loaded as filetype-specific metadata",
         "directory metadata tests must cover image dimension metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "PDF files expose page marker metadata",
         "directory metadata tests must cover PDF page metadata");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "or else Next = ASCII.VT" & ASCII.LF
         & "              or else Next = ASCII.FF",
         "PDF page marker parsing must accept ASCII vertical-tab and form-feed whitespace");
      Project_Tools.Files.Require_Contains
        (Tests,
         "PDF page markers accept vertical tab and form feed separators",
         "directory metadata tests must cover PDF control-whitespace page separators");
      Project_Tools.Files.Require_Contains
        (Tests,
         "PDF control-whitespace item was loaded",
         "directory metadata tests must assert the PDF control-whitespace fixture was loaded");
      Project_Tools.Files.Require_Contains
        (Tests,
         "ZIP files expose entry-count metadata",
         "directory metadata tests must cover ZIP entry-count metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "DOCX files expose package entry-count metadata",
         "directory metadata tests must cover DOCX package metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "XLSX files expose package entry-count metadata",
         "directory metadata tests must cover XLSX package metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "MP3 files expose audio metadata",
         "directory metadata tests must cover audio metadata classification");
      Project_Tools.Files.Require_Contains
        (Tests,
         "MP4 files expose video metadata",
         "directory metadata tests must cover video metadata classification");
      Project_Tools.Files.Require_Contains
        (Tests,
         "compound gzip-tar archive files expose gzip format metadata",
         "directory metadata tests must cover compound archive format metadata");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-file_system.adb",
         "elsif Filetype = ""application/gzip-tar"" then" & ASCII.LF
         & "               return ""archive.format|gzip"";",
         "gzip-tar metadata must not reuse ZIP central-directory entry counting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Ada source files expose source metadata",
         "directory metadata tests must cover Ada source metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "JSON files expose source metadata",
         "directory metadata tests must cover JSON source metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "XML files expose source metadata",
         "directory metadata tests must cover XML source metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "directory item was loaded",
         "directory metadata tests must cover loaded directory items");
   end Check_Directory_Loading_Contract;

   procedure Check_Command_Registry_Contract is
      Commands_Spec : constant String := Root & "/src/files-commands.ads";
      Commands_Body : constant String := Root & "/src/files-commands.adb";
      Tests         : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Select_Small_Icons_Command",
         "command registry must include small-icons view command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Select_Large_Icons_Command",
         "command registry must include large-icons view command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Select_Details_Command",
         "command registry must include details view command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Toggle_Info_Pane_Command",
         "command registry must include info-pane command");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "when Toggle_Info_Pane_Command =>" & ASCII.LF
         & "            return Files.Model.Selected_Count (Model) > 0",
         "info-pane toggle command must require a selected item");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info toggle disabled with no selection",
         "command enablement tests must cover disabled info toggle without selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info toggle enabled with selection",
         "command enablement tests must cover enabled info toggle with selection");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Toggle_Settings_Pane_Command",
         "command registry must include settings-pane command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Focus_Path_Input_Command",
         "command registry must include path-focus command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Navigate_Home_Command",
         "command registry must include home navigation command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Navigate_Back_Command",
         "command registry must include back navigation command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Navigate_Forward_Command",
         "command registry must include forward navigation command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Create_File_Command",
         "command registry must include create-file command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Delete_Selected_Items_Command",
         "command registry must include delete-selected command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Rename_Selected_Items_Command",
         "command registry must include rename command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Open_Selected_Items_Command",
         "command registry must include open-selected command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Focus_Filter_Input_Command",
         "command registry must include filter-focus command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Open_Command_Palette_Command",
         "command registry must include open-palette command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Close_Command_Palette_Command",
         "command registry must include close-palette command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Select_Drive_Command",
         "command registry must include drive selector command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Open_Selected_Root_Command",
         "command registry must include selected-root open command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Eject_Selected_Root_Command",
         "command registry must include selected-root eject command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Clear_Filter_Command",
         "command registry must include clear-filter command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Select_All_Command",
         "command registry must include select-all command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Refresh_Directory_Command",
         "command registry must include refresh-directory command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Save_Settings_Command",
         "command registry must include settings save command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Reset_Settings_Command",
         "command registry must include settings reset command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Delete_Selected_Permanently_Command",
         "command registry must include explicit permanent delete command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Generate_Thumbnails_Command",
         "command registry must include thumbnail generation command");
      Project_Tools.Files.Require_Contains
        (Commands_Spec,
         "Search_Recursive_Command",
         "command registry must include recursive search command");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""view.small"";",
         "small-icons command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""view.large"";",
         "large-icons command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""view.details"";",
         "details command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""info.toggle"";",
         "info-pane command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""settings.toggle"";",
         "settings-pane command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""path.focus"";",
         "path-focus command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""navigate.home"";",
         "home command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""navigate.back"";",
         "back command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""navigate.forward"";",
         "forward command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""file.create"";",
         "create-file command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""file.delete_selected"";",
         "delete-selected command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""file.delete_permanently"";",
         "permanent-delete command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""file.rename"";",
         "rename command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""file.open_selected"";",
         "open-selected command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""file.generate_thumbnails"";",
         "thumbnail-generation command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""filter.focus"";",
         "filter-focus command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""palette.open"";",
         "open-palette command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""palette.close"";",
         "close-palette command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""drive.select"";",
         "drive selector command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""drive.open_selected"";",
         "selected-root open command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""drive.eject_selected"";",
         "selected-root eject command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""filter.clear"";",
         "clear-filter command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""directory.search_recursive"";",
         "recursive-search command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""directory.refresh"";",
         "refresh-directory command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""settings.save"";",
         "settings save command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return ""settings.reset"";",
         "settings reset command must have a stable identifier");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_1, Ctrl);",
         "small-icons shortcut must remain Control+1");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_2, Ctrl);",
         "large-icons shortcut must remain Control+2");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_3, Ctrl);",
         "details shortcut must remain Control+3");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_4, Ctrl);",
         "info-pane shortcut must remain Control+4");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_L, Ctrl);",
         "path-focus shortcut must remain Control+L");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_Home, Alt);",
         "home navigation shortcut must remain Alt+Home");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_Left, Alt);",
         "back navigation shortcut must remain Alt+Left");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_Right, Alt);",
         "forward navigation shortcut must remain Alt+Right");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_N, Ctrl);",
         "create-file shortcut must remain Control+N");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_A, Ctrl);",
         "select-all shortcut must remain Control+A");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_P, Ctrl);",
         "command-palette shortcut must remain Control+P");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_F, Ctrl);",
         "filter-focus shortcut must remain Control+F");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_D, Ctrl);",
         "drive-selector shortcut must remain Control+D");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_F, Ctrl_Shift);",
         "clear-filter shortcut must remain Control+Shift+F");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_R, Ctrl);",
         "refresh-directory shortcut must remain Control+R");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_S, Ctrl);",
         "settings-save shortcut must remain Control+S");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_Delete, Files.Types.No_Modifiers);",
         "delete-selected primary shortcut must remain Delete");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_Delete, [Files.Types.Shift_Key => True, others => False]);",
         "permanent-delete shortcut must remain Shift+Delete");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_Backspace, Files.Types.No_Modifiers);",
         "delete-selected secondary shortcut must remain Backspace");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_F2, Files.Types.No_Modifiers);",
         "rename shortcut must remain F2");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_Escape, Files.Types.No_Modifiers);",
         "close-palette shortcut must remain Escape");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "return (True, Files.Types.Key_Return, Files.Types.No_Modifiers);",
         "open-selected shortcut must remain Return");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "function Requires_Settings_Path",
         "command registry must expose settings-path dependency metadata");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "function Allowed_With_Root_Selector",
         "command registry must centralize root-selector modal command gating");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "when Select_Drive_Command" & ASCII.LF
         & "            | Open_Selected_Root_Command" & ASCII.LF
         & "            | Eject_Selected_Root_Command" & ASCII.LF
         & "            | Open_Command_Palette_Command" & ASCII.LF
         & "            | Close_Command_Palette_Command =>",
         "root-selector gating must allow only selector and palette commands");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "function Allowed_With_Settings_Pane",
         "command registry must centralize settings-pane modal command gating");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "if Files.Model.Settings_Pane_Is_Open (Model) then",
         "pure command execution must not open an unseeded settings pane");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "when Toggle_Settings_Pane_Command" & ASCII.LF
         & "            | Save_Settings_Command" & ASCII.LF
         & "            | Reset_Settings_Command" & ASCII.LF
         & "            | Open_Command_Palette_Command" & ASCII.LF
         & "            | Close_Command_Palette_Command =>",
         "settings-pane gating must allow only settings and palette commands");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "when Save_Settings_Command =>",
         "settings save command must require a settings path");
      Project_Tools.Files.Require_Contains
        (Tests,
         "command registry and shortcuts",
         "command registry contract must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "all expected commands are registered",
         "command registry tests must cover the full registered command count");
      Project_Tools.Files.Require_Contains
        (Tests,
         "permanent delete command identifier is registered",
         "command registry tests must cover permanent-delete command registration");
      Project_Tools.Files.Require_Contains
        (Tests,
         "thumbnail generation command identifier is registered",
         "command registry tests must cover thumbnail-generation command registration");
      Project_Tools.Files.Require_Contains
        (Tests,
         "recursive search command identifier is registered",
         "command registry tests must cover recursive-search command registration");
      Project_Tools.Files.Require_Contains
        (Tests,
         "permanent delete command is palette-only metadata",
         "command registry tests must cover permanent-delete command placement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "thumbnail generation command is palette-only metadata",
         "command registry tests must cover thumbnail-generation command placement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "recursive search command is palette-only metadata",
         "command registry tests must cover recursive-search command placement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "no-command has no toolbar or palette placement",
         "command registry tests must cover no-command placement metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "no-command does not require a settings path",
         "command registry tests must cover no-command settings-path metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "no-command is hidden from the command palette",
         "command registry tests must cover no-command palette visibility metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "drive selector is allowed while root selector is open",
         "command registry tests must cover root-selector allowed commands");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette open is allowed while root selector is open",
         "command registry tests must cover root-selector palette-open allowance");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette close is allowed while root selector is open",
         "command registry tests must cover root-selector palette-close allowance");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings pane is blocked while root selector is open",
         "command registry tests must cover root-selector settings-pane blocking");
      Project_Tools.Files.Require_Contains
        (Tests,
         "delete is blocked while root selector is open",
         "command registry tests must cover root-selector blocked background commands");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings-path commands are allowed while settings pane is open",
         "command registry tests must cover settings-pane gating for path-dependent commands");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings toggle is allowed while settings pane is open",
         "command registry tests must cover settings-pane toggle allowance");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette open is allowed while settings pane is open",
         "command registry tests must cover settings-pane palette-open allowance");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette close is allowed while settings pane is open",
         "command registry tests must cover settings-pane palette-close allowance");
      Project_Tools.Files.Require_Contains
        (Tests,
         "drive selector is blocked while settings pane is open",
         "command registry tests must cover settings-pane drive-selector blocking");
      Project_Tools.Files.Require_Contains
        (Tests,
         "background navigation is blocked while settings pane is open",
         "command registry tests must cover settings-pane background navigation blocking");
      Project_Tools.Files.Require_Contains
        (Tests,
         "registered command description key is non-empty",
         "command registry tests must cover command description keys");
      Project_Tools.Files.Require_Contains
        (Tests,
         "command description localization exists for",
         "command registry tests must cover localized command descriptions");
      Project_Tools.Files.Require_Contains
        (Tests,
         "drive selector exposes shortcut metadata",
         "command registry tests must cover drive-selector shortcut metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings save command uses S shortcut metadata",
         "command registry tests must cover settings-save shortcut metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "alt+home dispatches home command",
         "command registry tests must cover Alt+Home dispatch");
      Project_Tools.Files.Require_Contains
        (Tests,
         "alt+left dispatches back command",
         "command registry tests must cover Alt+Left dispatch");
      Project_Tools.Files.Require_Contains
        (Tests,
         "alt+right dispatches forward command",
         "command registry tests must cover Alt+Right dispatch");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+n dispatches create-file command",
         "command registry tests must cover Control+N dispatch");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+a dispatches select-all command",
         "command registry tests must cover Control+A dispatch");
      Project_Tools.Files.Require_Contains
        (Tests,
         "select-all selects every visible loaded item",
         "model tests must cover select-all visible selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Control+A routes select-all command",
         "controller tests must cover select-all keyboard routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+f dispatches filter focus command",
         "command registry tests must cover Control+F dispatch");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+shift+f dispatches clear-filter command",
         "command registry tests must cover Control+Shift+F dispatch");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+r dispatches refresh command",
         "command registry tests must cover Control+R dispatch");
      Project_Tools.Files.Require_Contains
        (Tests,
         "registered command identifier is unique",
         "command registry tests must cover unique command identifiers");
      Project_Tools.Files.Require_Contains
        (Tests,
         "registered command primary shortcut is unique",
         "command registry tests must cover primary shortcut uniqueness");
      Project_Tools.Files.Require_Contains
        (Tests,
         "registered command secondary shortcut is unique",
         "command registry tests must cover secondary shortcut uniqueness");
      Project_Tools.Files.Require_Contains
        (Tests,
         "registered command primary and secondary shortcuts do not collide",
         "command registry tests must cover same-command shortcut collisions");
      Project_Tools.Files.Require_Contains
        (Tests,
         "present primary shortcut routes back to command",
         "command registry tests must cover primary shortcut reverse lookup");
      Project_Tools.Files.Require_Contains
        (Tests,
         "present secondary shortcut routes back to command",
         "command registry tests must cover secondary shortcut reverse lookup");
      Project_Tools.Files.Require_Contains
        (Tests,
         "primary shortcut text is normalized",
         "command registry tests must cover shortcut text normalization");
      Project_Tools.Files.Require_Contains
        (Tests,
         "command shortcut search text includes secondary shortcuts",
         "command registry tests must cover searchable shortcut aggregation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "command shortcut search text includes delete shortcut alias",
         "command registry tests must cover delete shortcut alias search text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "command shortcut search text keeps canonical primary shortcut first",
         "command registry tests must cover canonical shortcut search text ordering");
      Project_Tools.Files.Require_Contains
        (Tests,
         "command shortcut search text includes control shortcut alias",
         "command registry tests must cover control shortcut alias search text");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "Append (Result, ""option+"");",
         "command shortcut search text must expose option aliases for Alt shortcuts");
      Project_Tools.Files.Require_Contains
        (Tests,
         "command shortcut search text includes option shortcut alias",
         "command registry tests must cover option shortcut alias search text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "command shortcut search text includes escape shortcut alias",
         "command registry tests must cover escape shortcut alias search text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "command shortcut search text includes return shortcut alias",
         "command registry tests must cover return shortcut alias search text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "no-command has no shortcut search text",
         "command registry tests must cover no-command shortcut search text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "drive selector is placed in left toolbar",
         "command registry tests must cover toolbar placement metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "small view command is placed in bottom bar",
         "command registry tests must cover bottom-bar placement metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename command is palette-only metadata",
         "command registry tests must cover command-palette-only placement metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "refresh command is palette-only metadata",
         "command registry tests must cover refresh command placement metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "open-selected command is palette-only metadata",
         "command registry tests must cover open-selected placement metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "context-close command is palette-only metadata",
         "command registry tests must cover context-close placement metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "eject-selected-root command is palette-only metadata",
         "command registry tests must cover root-eject placement metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings save command is palette-only metadata",
         "command registry tests must cover settings-save placement metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings save requires a settings path",
         "command registry tests must cover settings save path dependency");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings reset does not require a settings path",
         "command registry tests must cover settings reset path dependency");
   end Check_Command_Registry_Contract;

   procedure Check_Command_Palette_Search_Contract is
      Palette_Spec : constant String := Root & "/src/files-command_palette.ads";
      Palette_Body : constant String := Root & "/src/files-command_palette.adb";
      Tests        : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Palette_Spec,
         "Search command-palette entries by localized label, description,",
         "command-palette spec must document localized label and description search");
      Project_Tools.Files.Require_Contains
        (Palette_Spec,
         "shortcut text, or stable identifier.",
         "command-palette spec must document stable identifier and shortcut search");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "Files.Commands.Command_Palette_Visible (Id)",
         "command-palette search must filter through command visibility metadata");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "Identifier : constant String := Files.Commands.Identifier (Id);",
         "command-palette search must include stable command identifiers");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "Files.Localization.Text (Files.Commands.Name_Key (Id));",
         "command-palette search must include localized command labels");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "Files.Localization.Text (Files.Commands.Description_Key (Id));",
         "command-palette search must include localized command descriptions");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "Shortcuts : constant String := Files.Commands.Shortcut_Search_Text (Id);",
         "command-palette search must include primary and secondary shortcut text");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering.ads",
         "Shortcut_Text : UString;",
         "command-palette snapshots must expose shortcut text for rendering");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering.adb",
         "Display_Shortcut : constant String",
         "command-palette snapshots must keep display shortcut text separate from search aliases");
      Project_Tools.Files.Require_Contains
        (Tests,
         "snapshot captures palette result shortcut text",
         "rendering tests must cover palette shortcut text snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "snapshot displays canonical primary and secondary shortcuts without aliases",
         "rendering tests must cover alias-free palette shortcut display text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame renders command-palette result shortcut text",
         "rendering tests must cover palette shortcut text drawing");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering.adb",
         "function Command_Result_Accessible_Description",
         "command-palette accessibility metadata must use a dedicated description builder");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering.adb",
         "Localized (""accessibility.command_disabled"")",
         "command-palette accessibility metadata must include disabled-state text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes command-palette shortcut text in accessibility metadata",
         "rendering tests must cover palette shortcut text accessibility metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes disabled command-palette state in accessibility metadata",
         "rendering tests must cover palette disabled-state accessibility metadata");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "Files.UTF8.Whitespace_Separator_Length (Query, Position)",
         "command-palette search must use the shared UTF-8 whitespace separator helper");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.ads",
         "function Whitespace_Separator_Length",
         "shared UTF-8 helper must expose whitespace-separator measurement");
      Require_Not_Contains
        (Palette_Body,
         "function Query_Separator_Length",
         "command-palette search must not keep a local UTF-8 query separator parser");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "function Has_Query_Token",
         "command-palette search must distinguish whitespace-only queries from non-empty token searches");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper recognizes ASCII whitespace separators",
         "tests must cover shared UTF-8 whitespace separator handling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper does not treat punctuation as whitespace separator",
         "tests must cover punctuation not splitting whitespace-token queries");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "Natural'Min" & ASCII.LF
         & "                 (Field_Score (Identifier, Token, 0),",
         "command-palette search must score every query token across all searchable fields");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "Field_Score (Description, Token, 200)",
         "command-palette search must include description fields in token scoring");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "Field_Score (Shortcuts, Token, 300)",
         "command-palette search must include shortcut fields in token scoring");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "if Token_Score = No_Match_Score then" & ASCII.LF
         & "               return No_Match_Score;",
         "command-palette search must require every non-empty query token to match");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "Score := Saturating_Add (Score, Token_Score);",
         "command-palette search must accumulate token scores without overflow");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "if Base_Score > Natural'Last / Scale then",
         "command-palette search must guard registry-order score scaling from overflow");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "Enabled    => Files.Commands.Is_Enabled (Id, Model)",
         "command-palette results must preserve disabled command entries");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "Saturating_Score (Base_Score, Registry_Index)",
         "command-palette search must preserve deterministic registry-order tie breaking");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "if Has_Token then",
         "command-palette searches must only sort when the query contains a token");
      Project_Tools.Files.Require_Contains
        (Palette_Body,
         "Sorting.Sort (Results);",
         "command-palette non-empty token searches must sort by match score");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search finds every command by stable identifier",
         "command-palette tests must cover stable identifier search");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search finds every command by localized label",
         "command-palette tests must cover localized label search");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty palette search preserves registry order",
         "command-palette tests must cover empty search registry order");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty palette search exposes stable command identifiers",
         "command-palette tests must cover identifier fields in empty search results");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty palette search exposes localized command descriptions",
         "command-palette tests must cover description fields in empty search results");
      Project_Tools.Files.Require_Contains
        (Tests,
         "exact identifier palette search ranks exact identifier first",
         "command-palette tests must cover exact identifier ranking");
      Project_Tools.Files.Require_Contains
        (Tests,
         "exact identifier palette search scores above localized label prefix search",
         "command-palette tests must cover identifier score priority over localized labels");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search matches localized command descriptions",
         "command-palette tests must cover localized description search");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search matches description terms independently",
         "command-palette tests must cover order-independent description token matching");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search treats tabs as token separators",
         "command-palette tests must cover tab-separated query tokens");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search treats line feeds as token separators",
         "command-palette tests must cover line-feed-separated query tokens");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search treats carriage returns as token separators",
         "command-palette tests must cover carriage-return-separated query tokens");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search treats vertical tabs as token separators",
         "command-palette tests must cover vertical-tab-separated query tokens");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search treats form feeds as token separators",
         "command-palette tests must cover form-feed-separated query tokens");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search treats C1 next-line controls as token separators",
         "command-palette tests must cover C1 next-line-separated query tokens");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search treats UTF-8 NBSP as a token separator",
         "command-palette tests must cover UTF-8 NBSP-separated query tokens");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search treats UTF-8 line separator as a token separator",
         "command-palette tests must cover UTF-8 line-separator query tokens");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search can match separate tokens across identifier and description",
         "command-palette tests must cover cross-field token matching");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search matches primary command shortcuts",
         "command-palette tests must cover primary shortcut search");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search matches control shortcut aliases",
         "command-palette tests must cover common control shortcut aliases");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search matches option shortcut aliases",
         "command-palette tests must cover common option shortcut aliases");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search matches common control-shift shortcut order",
         "command-palette tests must cover common control-shift shortcut order");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search matches abbreviated control-shift shortcut aliases",
         "command-palette tests must cover abbreviated control-shift shortcut aliases");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search matches secondary command shortcuts",
         "command-palette tests must cover secondary shortcut search");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search matches delete shortcut aliases",
         "command-palette tests must cover delete shortcut alias search");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search matches escape shortcut aliases",
         "command-palette tests must cover escape shortcut alias search");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search matches return shortcut aliases",
         "command-palette tests must cover return shortcut alias search");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search trims leading and trailing identifier whitespace",
         "command-palette tests must cover trimmed identifier queries");
      Project_Tools.Files.Require_Contains
        (Tests,
         "trimmed identifier search returns the matching command",
         "command-palette tests must cover trimmed identifier results");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search matches primary shortcuts case-insensitively",
         "command-palette tests must cover case-insensitive primary shortcut search");
      Project_Tools.Files.Require_Contains
        (Tests,
         "mixed-case primary shortcut search returns the matching command",
         "command-palette tests must cover mixed-case shortcut result routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "mixed-case primary shortcut search keeps a finite score",
         "command-palette tests must cover mixed-case shortcut score bounds");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search trims shortcut query whitespace",
         "command-palette tests must cover trimmed shortcut queries");
      Project_Tools.Files.Require_Contains
        (Tests,
         "trimmed secondary shortcut search returns the matching command",
         "command-palette tests must cover trimmed secondary shortcut results");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search matches localized labels case-insensitively",
         "command-palette tests must cover case-insensitive localized labels");
      Project_Tools.Files.Require_Contains
        (Tests,
         "mixed-case localized label search returns the matching command",
         "command-palette tests must cover mixed-case localized label routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search ignores repeated token separators around cross-field queries",
         "command-palette tests must cover repeated separators around cross-field queries");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search requires every query token to match",
         "command-palette tests must reject partial multi-token matches");
      Project_Tools.Files.Require_Contains
        (Tests,
         "whitespace-only palette query is treated as empty search",
         "command-palette tests must cover whitespace-only queries");
      Project_Tools.Files.Require_Contains
        (Tests,
         "whitespace-only palette query preserves registry order",
         "command-palette tests must cover whitespace-only query result ordering");
      Project_Tools.Files.Require_Contains
        (Tests,
         "long repeated palette query remains searchable",
         "command-palette tests must cover long repeated query handling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "long repeated palette query keeps score bounded",
         "command-palette tests must cover bounded scores for long queries");
      Project_Tools.Files.Require_Contains
        (Tests,
         "disabled selection-dependent entries still appear",
         "command-palette tests must cover disabled entries remaining visible");
   end Check_Command_Palette_Search_Contract;

   procedure Check_Root_Selector_Contract is
      Commands_Body    : constant String := Root & "/src/files-commands.adb";
      Controller_Body  : constant String := Root & "/src/files-controller.adb";
      File_System_Body : constant String := Root & "/src/files-file_system.adb";
      Model_Body       : constant String := Root & "/src/files-model.adb";
      Operations_Body  : constant String := Root & "/src/files-operations.adb";
      Tests            : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "function Allowed_With_Root_Selector",
         "root selector command gating must remain centralized");
      Project_Tools.Files.Require_Contains
        (Commands_Body,
         "Select_Drive_Command" & ASCII.LF
         & "            | Open_Selected_Root_Command" & ASCII.LF
         & "            | Eject_Selected_Root_Command" & ASCII.LF
         & "            | Open_Command_Palette_Command" & ASCII.LF
         & "            | Close_Command_Palette_Command =>",
         "root selector must only allow drive, root, eject, and overlay commands by default");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Available_Root_Entries return Root_Entry_Vectors.Vector",
         "root discovery must expose metadata-rich root entries");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Safe_Environment_Value",
         "filesystem environment probing must centralize recoverable environment access");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Home                    : constant String := Safe_Environment_Value (""HOME"");",
         "root discovery must read HOME through guarded environment access");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Home_Path               : constant String := Safe_Environment_Value (""HOMEPATH"");",
         "root discovery must read HOMEPATH through guarded environment access");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Home_Drive_Profile      : constant String :=",
         "root discovery must compose Windows drive profile roots");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Xdg_Runtime_Dir         : constant String := Safe_Environment_Value (""XDG_RUNTIME_DIR"");",
         "root discovery must read runtime mount hints through guarded environment access");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Append_If_Directory (""/"", Root_Filesystem);",
         "root discovery must include the filesystem root when available");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Append_Proc_Mounts;",
         "root discovery must include mounted filesystems from platform metadata");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Is_Displayable_Root_Mount",
         "root discovery must filter raw platform mounts before showing drive choices");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Is_Pseudo_Mount_Type",
         "root discovery must exclude pseudo filesystem mounts from the drive chooser");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Is_Network_Filesystem_Type",
         "root discovery must classify network filesystem mounts");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Is_User_Visible_Mount_Point",
         "root discovery must limit proc mount rows to user-visible mount locations");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Is_Mount_Container",
         "root discovery must distinguish drive containers from selectable drives");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "return not Is_Mount_Container",
         "root discovery must exclude mount container directories from proc mount rows");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Append_Children (""/mnt"", Root_Mount);",
         "root discovery must inspect conventional mount roots");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Parent = ""/media"" or else Parent = ""/run/media""",
         "root discovery must recognize Linux media user-container directories");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Append_Children (Full, Kind);",
         "root discovery must scan media user containers without presenting them as drives");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Append_Children (Join_Path (Xdg_Runtime_Dir, ""gvfs""), Root_Network_Mount);",
         "root discovery must classify GVFS share mounts as network roots");
      Require_Not_Contains
        (File_System_Body,
         "Append_If_Directory (Run_Media_User, Root_User_Mount);",
         "root discovery must not present /run/media/$USER itself as a removable drive");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Append_If_Directory (String'(1 => Drive) & "":\"", Root_Windows_Drive);",
         "root discovery must inspect Windows drive roots");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Append_If_Directory (Home_Share, Root_Network_Mount);",
         "root discovery must classify Windows home shares as network roots");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Append_If_Directory (Home_Drive_Profile, Root_User_Mount);",
         "root discovery must include Windows drive profile directories");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Sorting.Sort (Roots);",
         "root discovery must return roots in deterministic order");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "function Path_Is_Queryable return Boolean is",
         "root volume detail lookup must guard malformed synthetic root paths");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "if Queryable then" & ASCII.LF
         & "         Volume_Size_For (Path_Text, Volume);",
         "root volume detail lookup must skip platform probes for malformed root paths");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Model.Root_Entries := Roots;",
         "root selector model must store the current root metadata entries");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Model.Root_Selector_Open := not Roots.Is_Empty;",
         "root selector model must not leave an invisible empty dropdown open");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Model.Root_Selected := (if Model.Root_Selector_Open then 1 else 0);",
         "root selector model must select the first row only when a row exists");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Model.Root_Entries.Clear;",
         "closing the root selector must clear stale root entries");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "procedure Clear_Root_Selector_State",
         "root selector model must centralize closed-state cleanup");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Clear_Root_Selector_State (Model);",
         "root selector model transitions must reuse closed-state cleanup");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct navigation clears stale root selector entries",
         "root selector tests must cover stale root entry cleanup after navigation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct rename clears stale root selector entries",
         "root selector tests must cover stale root entry cleanup after rename");
      Project_Tools.Files.Require_Contains
        (Tests,
         "direct create clears stale root selector entries",
         "root selector tests must cover stale root entry cleanup after create");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty root selector does not create an invisible modal command blocker",
         "root selector tests must cover empty-root invisible modal prevention");
      Project_Tools.Files.Require_Contains
        (Tests,
         "close command clears closed root selector entries",
         "root selector tests must cover clearing stale entries after close");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Model.Settings_Pane_Open := False;",
         "opening the root selector must close the settings pane");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Model.Command_Palette_Open := False;",
         "opening the root selector must close the command palette");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Path_Result : constant Files.File_System.Path_Result := Files.File_System.Normalize_Path (Root_Path);",
         "root activation must normalize selected root paths before loading");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Files.File_System.Load_Directory (To_String (Path_Result.Directory_Path), Settings);",
         "root activation must load the selected directory through the filesystem layer");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Files.Model.Navigate_To (Model, To_String (Load.Path), Load.Items);",
         "root activation must navigate the model with loaded root items");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Files.Model.Close_Root_Selector (Model);",
         "successful root activation must close the selector");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "return Disabled (Model, ""error.root.selection.empty"");",
         "root eject must reject missing root selection");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "return Disabled (Model, ""error.root.eject_unavailable"");",
         "root eject must report unavailable native eject support");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Files.Operations.Select_Root (Model, Settings, Root_Path);",
         "controller root selection must route through root operations");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "return Make_Result (Controller_Command_Executed, Files.Commands.Select_Drive_Command, Operation);",
         "direct root selection must report the drive selector command");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Files.Model.Set_Root_Selected_Index (Model, Root_Index);",
         "root row clicks must update the selected root before activation");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Files.Commands.Open_Selected_Root_Command",
         "root row clicks must report the open-selected-root command");
      Project_Tools.Files.Require_Contains
        (Tests,
         "drive selector opens root selector",
         "root selector tests must cover drive command opening");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root selector contains at least one root",
         "root selector tests must cover discovered roots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "available roots include HOMEDRIVE and HOMEPATH profile directory",
         "root selector tests must cover Windows drive profile root discovery");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root discovery excludes mount container rows",
         "root selector tests must cover mount-container exclusion guards");
      Project_Tools.Files.Require_Contains
        (Tests,
         "available roots collapse duplicate HOME and USERPROFILE directories",
         "root selector tests must cover normalized duplicate environment root removal");
      Project_Tools.Files.Require_Contains
        (Tests,
         "malformed root volume detail has no platform metadata",
         "root selector tests must cover malformed synthetic root volume details");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root selector renders localized root kind prefix",
         "root selector tests must cover localized root labels");
      Project_Tools.Files.Require_Contains
        (Tests,
         "eject command reports localized unavailable error",
         "root selector tests must cover eject failure diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root-open command reports root activation command",
         "root selector tests must cover selected-root activation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "metadata root selector overload closes settings pane",
         "root selector tests must cover modal exclusivity with settings");
      Project_Tools.Files.Require_Contains
        (Tests,
         "drive selector closes command palette",
         "root selector tests must cover palette cleanup");
      Project_Tools.Files.Require_Contains
        (Tests,
         "invalid root selection keeps selector open",
         "root selector tests must cover invalid path recovery");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root selection operation carries normalized path",
         "root selector tests must cover normalized selected-root navigation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root selection updates back history",
         "root selector tests must cover history updates after root activation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Right from last root row wraps to first row",
         "root selector tests must cover right-arrow wraparound");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Left from first root row wraps to last row",
         "root selector tests must cover left-arrow wraparound");
   end Check_Root_Selector_Contract;

   procedure Check_Event_Translation_Contract is
      Events_Body : constant String := Root & "/src/files-events.adb";
      Tests       : constant String := Combined_Suite;
   begin
      Require_Not_Contains
        (Events_Body,
         "with Ada.Directories;",
         "event translation must not import Ada.Directories for filesystem access");
      Require_Not_Contains
        (Events_Body,
         "with GNAT.OS_Lib;",
         "event translation must not import process execution APIs");
      Require_Not_Contains
        (Events_Body,
         "with Files.Model;",
         "event translation must not import mutable model state");
      Require_Not_Contains
        (Events_Body,
         "with Files.Operations;",
         "event translation must not import filesystem operations");
      Require_Not_Contains
        (Events_Body,
         "with Files.File_System;",
         "event translation must not import filesystem inspection or mutation APIs");
      Require_Not_Contains
        (Events_Body,
         "Files.Commands.Execute",
         "event translation must not directly execute commands");
      Require_Not_Contains
        (Events_Body,
         "Files.Operations.",
         "event translation must not route through operation execution");
      Require_Not_Contains
        (Events_Body,
         "Files.File_System.",
         "event translation must not inspect or mutate the filesystem");
      Require_Not_Contains
        (Events_Body,
         "Files.Model.",
         "event translation must not mutate or inspect live model state");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Files.Commands.Find_By_Shortcut (Key, Modifiers)",
         "keyboard event translation must dispatch shortcuts through the central command registry");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "function Command_Action",
         "event translation must centralize command-action construction");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "if Command /= Files.Commands.No_Command then",
         "keyboard event translation must prefer registered command shortcuts");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "return Command_Action (Command);",
         "keyboard command translation must use centralized command-action construction");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "return Command_Action (Command, Activate);",
         "click command translation must preserve activation through centralized command actions");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "or else" & ASCII.LF
         & "          (Modifiers (Files.Types.Shift_Key)",
         "arrow-key selection movement must allow Shift range selection");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "function Selection_Action",
         "event translation must centralize selection-action construction");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Kind            => Selection_Input_Action",
         "arrow-key event translation must produce selection actions");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "when Files.Types.Key_Left =>" & ASCII.LF
         & "               return" & ASCII.LF
         & "                 (Kind            => Selection_Input_Action," & ASCII.LF
         & "                  Direction       => Files.Types.Move_Left,",
         "left-arrow event translation must preserve left movement");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "when Files.Types.Key_Right =>" & ASCII.LF
         & "               return" & ASCII.LF
         & "                 (Kind            => Selection_Input_Action," & ASCII.LF
         & "                  Direction       => Files.Types.Move_Right,",
         "right-arrow event translation must preserve right movement");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "when Files.Types.Key_Up =>" & ASCII.LF
         & "               return" & ASCII.LF
         & "                 (Kind            => Selection_Input_Action," & ASCII.LF
         & "                  Direction       => Files.Types.Move_Up,",
         "up-arrow event translation must preserve upward movement");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "when Files.Types.Key_Down =>" & ASCII.LF
         & "               return" & ASCII.LF
         & "                 (Kind            => Selection_Input_Action," & ASCII.LF
         & "                  Direction       => Files.Types.Move_Down,",
         "down-arrow event translation must preserve downward movement");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Range_Selection => Modifiers (Files.Types.Shift_Key)",
         "arrow-key event translation must request Shift range selection");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Toggle_Selection => Modifiers (Files.Types.Control_Key)",
         "item click translation must preserve control-click selection toggles");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Range_Selection  => Modifiers (Files.Types.Shift_Key)",
         "item click translation must preserve shift-click range selection");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "function Saturating_Negated_Triple",
         "wheel event translation must saturate signed scroll deltas");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "function Scroll_Action",
         "event translation must centralize scroll-action construction");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "function Translate_Scroll",
         "wheel event translation must expose backend-neutral scroll actions");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "return Scroll_Action (Scroll_Auto, Lines);",
         "untargeted wheel events must preserve automatic scroll targeting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+p maps to palette command",
         "event translation must cover command-palette shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+l maps to path focus command",
         "event translation must cover path-focus shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+f maps to filter focus",
         "event translation must cover filter-focus shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+shift+f maps to clear filter",
         "event translation must cover clear-filter shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+1 maps to small-icons command",
         "event translation must cover small-icons shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+2 maps to large-icons command",
         "event translation must cover large-icons shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+3 maps to details command",
         "event translation must cover details shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+4 maps to info toggle command",
         "event translation must cover info-pane shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+n maps to create file",
         "event translation must cover create-file shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+d maps to drive selector",
         "event translation must cover drive-selector shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+r maps to refresh",
         "event translation must cover refresh shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+s maps to settings save",
         "event translation must cover settings-save shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "alt+left maps to back command",
         "event translation must cover history-back shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "alt+right maps to forward command",
         "event translation must cover history-forward shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "alt+home maps to home command",
         "event translation must cover home shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Delete maps to delete command",
         "event translation must cover delete shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Backspace maps to delete command",
         "event translation must cover secondary delete shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "F2 maps to rename command",
         "event translation must cover rename shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Return maps to open command",
         "event translation must cover open-selected shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Escape maps to context cancel",
         "event translation must cover Escape shortcut routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "left arrow maps to left selection movement",
         "event translation must cover arrow-key selection movement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shift-down requests range selection",
         "event translation tests must cover Shift-arrow range selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control-click item action requests selection toggle",
         "event translation must cover control-click selection toggles");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shift-click item action requests range selection",
         "event translation must cover shift-click range selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "positive wheel offset translates to scroll action",
         "event translation tests must cover positive wheel scrolling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "negative wheel offset translates to scroll action",
         "event translation tests must cover negative wheel scrolling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "large positive wheel offset saturates upward scroll lines",
         "event translation tests must cover saturated upward wheel scrolling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "large negative wheel offset saturates downward scroll lines",
         "event translation tests must cover saturated downward wheel scrolling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "zero wheel offset translates to no input action",
         "event translation tests must cover zero wheel scrolling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "wheel over main view targets main view",
         "event translation tests must cover targeted main-view wheel routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "wheel over info pane targets info pane",
         "event translation tests must cover targeted info-pane wheel routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "wheel over palette search field is inert",
         "event translation tests must cover inert command-palette search wheel routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "wheel over palette results targets palette",
         "event translation tests must cover targeted command-palette result wheel routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "open palette blocks wheel outside overlay",
         "event translation tests must cover command-palette wheel overlay blocking");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root selector blocks targeted main wheel translation",
         "event translation tests must cover root-selector wheel overlay blocking");
      Project_Tools.Files.Require_Contains
        (Tests,
         "drive toolbar toggle closes open root selector",
         "event translation tests must cover drive button toggling an open root selector");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette over root selector keeps palette wheel target",
         "event translation tests must cover palette wheel priority over root selector");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings pane blocks targeted main wheel translation",
         "event translation tests must cover settings-pane wheel overlay blocking");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings pane blocks targeted info wheel translation",
         "event translation tests must cover settings-pane info-area wheel overlay blocking");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette over settings pane keeps palette wheel target",
         "event translation tests must cover palette wheel priority over settings pane");
   end Check_Event_Translation_Contract;

   procedure Check_Event_Hit_Test_Contract is
      Events_Body    : constant String := Root & "/src/files-events.adb";
      Rendering_Body : constant String := Root & "/src/files-rendering.adb";
      Tests          : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "function Cursor_At",
         "text hit testing must keep cursor placement centralized");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Files.UTF8.Byte_Offset_For_Display_Column (Raw, Click_Column)",
         "text hit testing must convert clicked display columns to UTF-8 byte cursor offsets");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Saturating_Add (Click_X - Text_X, Char_W / 2) / Char_W",
         "text hit testing must avoid cursor-position addition overflow");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter click returns UTF-8 byte boundary after clicked character",
         "event translation tests must cover UTF-8-aware text click cursor offsets");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter click skips trailing combining marks at display-cell boundaries",
         "event translation tests must cover combining-mark text click cursor offsets");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter click counts malformed UTF-8 byte as replacement cell",
         "event translation tests must cover malformed UTF-8 replacement-cell cursor offsets");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "function Palette_Scrollbar_Click return Input_Action",
         "command-palette scrollbar hit testing must stay explicit");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Within (Y, Palette_Layout.Search_Y, Palette_Layout.Search_Height)",
         "command-palette search hit testing must use clipped search-field height");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Within (Y, Palette_Layout.Results_Y, Palette_Layout.Results_Height)",
         "command-palette result hit testing must use clipped result-area height");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "elsif Snapshot.Command_Palette_Open then",
         "command-palette hit testing must block clicks behind the overlay");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "elsif Snapshot.Root_Selector_Open then",
         "root-selector hit testing must block clicks behind the dropdown");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Settings_Click_Hit",
         "settings modal hit testing must stay routed through the modal handler");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "return Settings_Command_Click (Files.Commands.Reset_Settings_Command);",
         "settings modal reset clicks must route through the central command registry");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "return Settings_Command_Click (Files.Commands.Save_Settings_Command);",
         "settings modal save clicks must route through the central command registry");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "function Option_Hit_Width",
         "settings modal option hit testing must account for rendered remainder width");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Natural'Min" & ASCII.LF
         & "                      (Option_Count (Snapshot.Settings_Field_Index)," & ASCII.LF
         & "                       (X - Text_X) / Cell_W + 1)",
         "settings modal option clicks must clamp option indices to rendered options");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings sort remainder click maps modified option",
         "event hit-test tests must cover settings option remainder pixels");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "return Settings_Click (Field, 100);",
         "settings modal add-button clicks must use stable add action codes");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "return Settings_Click (Field, 101);",
         "settings modal remove-button clicks must use stable remove action codes");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-ui.ads",
         "function Calculate_Settings_Entry_Button_Layout",
         "UI must expose shared settings add/remove button layout");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-ui.ads",
         "function Calculate_Settings_Action_Button_Layout",
         "UI must expose shared settings action button layout");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-ui.ads",
         "function Calculate_Settings_Pane_Layout",
         "UI must expose shared settings pane layout");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Files.UI.Calculate_Settings_Pane_Layout",
         "settings modal hit testing must use shared settings pane layout");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Files.UI.Calculate_Settings_Pane_Layout",
         "settings modal rendering must use shared settings pane layout");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Files.UI.Calculate_Settings_Entry_Button_Layout (Pane_X, Pane_W, Line_Height)",
         "settings modal add/remove hit testing must use the shared localized button layout");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Files.UI.Calculate_Settings_Entry_Button_Layout (Pane_X, Pane_W, Line_Height)",
         "settings modal add/remove rendering must use the shared localized button layout");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Files.UI.Calculate_Settings_Action_Button_Layout (Text_X, Text_W)",
         "settings modal action hit testing must use the shared button layout");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Files.UI.Calculate_Settings_Action_Button_Layout (Text_X, Text_W)",
         "settings modal action rendering must use the shared button layout");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-ui.adb",
         "Pane_W : constant Natural := Natural'Min (Width, Wanted_W);",
         "shared settings modal layout must clamp preferred pane width to the window width");
      Project_Tools.Files.Require_Contains
        (Tests,
         "narrow settings pane clamps to the window width",
         "event tests must cover narrow settings pane width clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "narrow settings pane rejects clicks beyond the window width",
         "event tests must cover narrow settings pane hit-test clamping");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-ui.adb",
         "Saturating_Add (Content_H, Saturating_Multiply (Settings_Pane_Padding, 2))",
         "shared settings modal layout must use saturating pane height calculations");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-ui.adb",
         "Second_W : constant Natural := (if Text_Width > Offset then Text_Width - Offset else 0);",
         "shared settings action layout must assign remainder width to the second button");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-ui.adb",
         "Total_W  : constant Natural := Saturating_Add (Offset, Second_W);",
         "shared settings action layout must keep action width overflow-safe");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings hit tests use shared action button layout",
         "event hit-test tests must cover shared settings action layout");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings save remainder click maps save command",
         "event hit-test tests must cover settings save-button remainder pixels");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings hit tests use shared pane layout height",
         "event hit-test tests must cover shared settings pane layout");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "function Translate_Scroll_At",
         "targeted wheel hit testing must remain explicit");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Action.Scroll_Area := Scroll_Command_Palette;",
         "targeted wheel hit testing must route palette result scrolling to the palette");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Action.Scroll_Area := Scroll_Info_Pane;",
         "targeted wheel hit testing must route info-pane scrolling to the info pane");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "Action.Scroll_Area := Scroll_Main_View;",
         "targeted wheel hit testing must route main-view scrolling to the main view");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "if Snapshot.Root_Selector_Open or else Snapshot.Settings_Pane_Open then",
         "targeted wheel hit testing must block background scrolling behind modals");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter click clamps cursor to text start",
         "event hit-test tests must cover filter cursor start clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter click clamps cursor to text end",
         "event hit-test tests must cover filter cursor end clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search click clamps cursor to text start",
         "event hit-test tests must cover palette cursor start clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search click clamps cursor to text end",
         "event hit-test tests must cover palette cursor end clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "wide palette search click avoids cursor overflow",
         "event hit-test tests must cover high-coordinate text cursor hit testing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename click clamps cursor to text start",
         "event hit-test tests must cover rename cursor start clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename click clamps cursor to text end",
         "event hit-test tests must cover rename cursor end clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette blocks toolbar clicks behind overlay",
         "event hit-test tests must cover palette overlay blocking toolbar clicks");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette blocks root row clicks behind overlay",
         "event hit-test tests must cover palette overlay blocking root rows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette blocks info scrollbar clicks behind overlay",
         "event hit-test tests must cover palette overlay blocking info scrollbars");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette blocks main scrollbar clicks behind overlay",
         "event hit-test tests must cover palette overlay blocking main scrollbars");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette claims settings modal clicks behind overlay",
         "event hit-test tests must cover palette overlay priority over settings modal clicks");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search remains clickable over settings pane",
         "event hit-test tests must cover palette search priority over settings modal");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette search over settings targets command-palette input",
         "event hit-test tests must cover palette search focus over settings modal");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette result remains clickable over settings pane",
         "event hit-test tests must cover palette result priority over settings modal");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette scrollbar click translates to scroll",
         "event hit-test tests must cover palette scrollbar translation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "tiny palette search click uses clipped search height",
         "event hit-test tests must cover tiny command-palette search geometry");
      Project_Tools.Files.Require_Contains
        (Tests,
         "tiny palette rejects click after clipped search field",
         "event hit-test tests must cover clipped command-palette search boundaries");
      Project_Tools.Files.Require_Contains
        (Tests,
         "partial palette thumb click is inert",
         "event hit-test tests must cover partial command-palette scrollbar geometry");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info scrollbar below thumb scrolls down by a page step",
         "event hit-test tests must cover info-pane scrollbar lower-track clicks");
      Project_Tools.Files.Require_Contains
        (Tests,
         "main scrollbar below thumb scrolls down by a page step",
         "event hit-test tests must cover main-view scrollbar lower-track clicks");
      Project_Tools.Files.Require_Contains
        (Tests,
         "main scrollbar ignores click below padded track",
         "event hit-test tests must cover padded main scrollbar track bounds");
      Project_Tools.Files.Require_Contains
        (Tests,
         "saturated settings click avoids overflow",
         "event hit-test tests must cover saturated settings modal geometry");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings reset click maps command",
         "event hit-test tests must cover settings reset command hit testing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings save click maps command",
         "event hit-test tests must cover settings save command hit testing");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "if Snapshot.Settings_Can_Reset then",
         "settings action hit testing must honor snapshot reset enablement");
      Project_Tools.Files.Require_Contains
        (Events_Body,
         "if Snapshot.Settings_Can_Save then",
         "settings action hit testing must honor snapshot save enablement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "disabled settings reset click is ignored by hit testing",
         "event hit-test tests must cover disabled settings reset action button");
      Project_Tools.Files.Require_Contains
        (Tests,
         "disabled settings save click is ignored by hit testing",
         "event hit-test tests must cover disabled settings save action button");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings option click returns option index",
         "event hit-test tests must cover settings option hit testing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings blank option cell is inert",
         "event hit-test tests must cover inert settings option cells");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings add click returns add action code",
         "event hit-test tests must cover settings collection add hit testing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings remove click returns remove action code",
         "event hit-test tests must cover settings collection remove hit testing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings remove button sizes to localized label",
         "event hit-test tests must cover localized settings add/remove button layout");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame sizes settings remove button text to localized label",
         "rendering tests must cover localized settings remove button sizing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings diagnostic row stays inside modal pane",
         "event hit-test tests must cover settings modal diagnostic bounds");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info scrollbar click translates to scroll",
         "event hit-test tests must cover info-pane scrollbar translation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "main scrollbar click translates to scroll",
         "event hit-test tests must cover main-view scrollbar translation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control-shift item click keeps range selection precedence",
         "event hit-test tests must cover modified item-click precedence");
      Project_Tools.Files.Require_Contains
        (Tests,
         "wheel over main view targets main view",
         "event hit-test tests must cover targeted main-view wheel scrolling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "wheel over info pane targets info pane",
         "event hit-test tests must cover targeted info-pane wheel scrolling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "wheel over palette results targets palette",
         "event hit-test tests must cover targeted palette wheel scrolling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "open palette blocks wheel outside overlay",
         "event hit-test tests must cover palette wheel blocking");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root selector blocks targeted main wheel translation",
         "event hit-test tests must cover root-selector wheel blocking");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings pane blocks targeted main wheel translation",
         "event hit-test tests must cover settings-pane wheel blocking");
   end Check_Event_Hit_Test_Contract;

   procedure Check_UI_Command_Hit_Test_Contract is
      UI_Body : constant String := Root & "/src/files-ui.adb";
      Tests   : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "function Toolbar_Command_At",
         "UI must keep toolbar hit testing centralized");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "function Within",
         "UI hit testing must keep overflow-safe horizontal containment centralized");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "function Within_Rect",
         "UI hit testing must keep overflow-safe rectangle containment centralized");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "and then X - Start_X < Rect_Width;",
         "UI hit testing must subtract only after checking the coordinate origin");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "and then Y - Rect_Y < Rect_Height;",
         "UI hit testing must subtract vertical coordinates only after checking the origin");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "function Saturating_Multiply",
         "UI layout must keep line-height multiplication overflow-safe");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "function Saturating_Add",
         "UI layout must keep offset addition overflow-safe");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "Saturating_Multiply (Value / Denominator, Numerator)",
         "UI proportional layout must avoid raw scaled-product overflow");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-events.adb",
         "if Whole > Natural'Last / Numerator then",
         "event proportional hit testing must avoid raw scaled-product overflow");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-events.adb",
         "return Scaled_Down (Value, Factor, Denominator);",
         "event proportional hit testing must preserve scale when raw multiplication would overflow");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-ui.ads",
         "Toolbar_Button_Width : constant Natural := 40;",
         "toolbar button width must be fixed so icons do not shrink with the window");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "if Toolbar.Left_Width >= Saturating_Multiply (Toolbar_Button_Width, Toolbar_Button_Count) then",
         "toolbar button origins must use fixed placement when the left toolbar has room");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "Left           : constant Natural := (if Width >= Preferred_Left then Preferred_Left else 0);",
         "toolbar layout must hide left icon buttons when fixed-width buttons cannot fit");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "return Saturating_Add (Toolbar.Left_X, Scaled_Down "
         & "(Toolbar.Left_Width, Clamped_Index, Toolbar_Button_Count));",
         "toolbar button origins must keep saturated proportional fallback placement");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "if Button_Index >= 6 or else Next_X <= Button_X then" & ASCII.LF
         & "         return 0;",
         "toolbar button widths must reject invalid or saturated button ranges");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "Input_Y  : constant Natural := Toolbar_Input_Y (Line_Height);",
         "toolbar input hit testing must account for vertical input padding");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "Toolbar_H : constant Natural := Saturating_Multiply (Line_Height, 2);",
         "toolbar hit testing must derive toolbar height from saturated text metrics");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "return Files.Commands.Focus_Path_Input_Command;",
         "toolbar hit testing must route the middle path field through the command registry");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "return Files.Commands.Focus_Filter_Input_Command;",
         "toolbar hit testing must route the right filter field through the command registry");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "return Files.Commands.Select_Drive_Command;",
         "toolbar hit testing must route the drive selector through the command registry");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "return Files.Commands.Navigate_Home_Command;",
         "toolbar hit testing must route home through the command registry");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "return Files.Commands.Navigate_Back_Command;",
         "toolbar hit testing must route back through the command registry");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "return Files.Commands.Navigate_Forward_Command;",
         "toolbar hit testing must route forward through the command registry");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "return Files.Commands.Create_File_Command;",
         "toolbar hit testing must route create-file through the command registry");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "return Files.Commands.Delete_Selected_Items_Command;",
         "toolbar hit testing must route delete through the command registry");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "function Bottom_Bar_Command_At",
         "UI must keep bottom-bar hit testing centralized");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "Small_Needed   : constant Natural :=",
         "bottom-bar layout must derive compact command button widths from short labels");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "Files.UTF8.Display_Units (Text)",
         "bottom-bar layout must measure localized labels through the shared UTF-8 helper");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "Label_Pixel_Width (Files.Localization.Text (""command.view.small.short""), Cell_W)",
         "bottom-bar layout must size short labels through UTF-8-aware text measurement");
      Require_Not_Contains
        (UI_Body,
         "command.view.small.short"")'Length",
         "bottom-bar layout must not size localized labels by UTF-8 byte length");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "Toggle_W       : constant Natural := Natural'Min (Remaining, Toggle_Wanted);",
         "bottom-bar layout must clamp the info-pane toggle to available width");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "Bottom_Y : constant Natural := (if Height > Bottom_H then Height - Bottom_H else 0);",
         "bottom-bar hit testing must handle windows shorter than the padded bar");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "or else Y < Content_Y" & ASCII.LF
         & "        or else Y >= Saturating_Add (Content_Y, Line_Height)",
         "bottom-bar hit testing must reject zero-size and padded out-of-band coordinates");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "return Files.Commands.Select_Small_Icons_Command;",
         "bottom-bar hit testing must route small-icons mode through the command registry");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "return Files.Commands.Select_Large_Icons_Command;",
         "bottom-bar hit testing must route large-icons mode through the command registry");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "return Files.Commands.Select_Details_Command;",
         "bottom-bar hit testing must route details mode through the command registry");
      Project_Tools.Files.Require_Contains
        (UI_Body,
         "return Files.Commands.Toggle_Info_Pane_Command;",
         "bottom-bar hit testing must route info-pane toggle through the command registry");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test maps drive selector to command",
         "UI tests must cover toolbar drive selector command mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test maps home button to command",
         "UI tests must cover toolbar home command mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test keeps drive button at fixed width",
         "UI tests must cover fixed-width drive button ownership");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test maps back button to command",
         "UI tests must cover toolbar back command mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test keeps back button at fixed width",
         "UI tests must cover fixed-width back button ownership");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test maps forward button to command",
         "UI tests must cover toolbar forward command mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test keeps forward button at fixed width",
         "UI tests must cover fixed-width forward button ownership");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test maps create button to command",
         "UI tests must cover toolbar create-file command mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test keeps create button at fixed width",
         "UI tests must cover fixed-width create button ownership");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test maps delete button to command",
         "UI tests must cover toolbar delete command mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test keeps delete button at fixed width",
         "UI tests must cover fixed-width delete button ownership");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test maps left section end to path input",
         "UI tests must cover toolbar left/path section boundary ownership");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test maps path input to command",
         "UI tests must cover toolbar path-input command mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test maps filter input to command",
         "UI tests must cover toolbar filter-input command mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test maps uneven trailing left pixels to delete",
         "UI tests must cover proportional toolbar button remainder handling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test includes path input top padding",
         "UI tests must cover path-input vertical padding inclusion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test ignores coordinates below padded path input",
         "UI tests must cover path-input outside-bottom rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test includes filter input top padding",
         "UI tests must cover filter-input vertical padding inclusion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test ignores coordinates below toolbar",
         "UI tests must cover toolbar lower-bound rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test handles saturated coordinates without overflow",
         "UI tests must cover saturated toolbar coordinate handling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test handles saturated left-section coordinates without overflow",
         "UI tests must cover saturated toolbar left-section hit testing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar button helper saturates offset origins",
         "UI tests must cover saturated toolbar button origin helpers");
      Project_Tools.Files.Require_Contains
        (Tests,
         "narrow toolbar hit test includes padded path input top edge",
         "UI tests must cover collapsed toolbar padded input hit testing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "narrow toolbar hides fixed-width icon buttons",
         "UI tests must cover hidden toolbar icon buttons on narrow windows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar hit test hides icon buttons when fixed width cannot fit",
         "UI tests must cover narrow toolbar icon hit-test suppression");
      Project_Tools.Files.Require_Contains
        (Tests,
         "zero-width toolbar hit test stays empty",
         "UI tests must cover zero-width toolbar command hit testing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bottom-bar hit test maps small-icons button to command",
         "UI tests must cover bottom-bar small-icons command mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bottom-bar hit test maps large-icons button to command",
         "UI tests must cover bottom-bar large-icons command mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bottom-bar hit test maps small-large separator to large-icons command",
         "UI tests must cover bottom-bar small-large separator ownership");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bottom-bar hit test maps details button to command",
         "UI tests must cover bottom-bar details command mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bottom-bar hit test maps large-details separator to details command",
         "UI tests must cover bottom-bar large-details separator ownership");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bottom-bar hit test maps info-pane toggle to command",
         "UI tests must cover bottom-bar info-pane command mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bottom-bar hit test maps info-toggle separator to info-pane command",
         "UI tests must cover bottom-bar info-toggle separator ownership");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bottom-bar hit test ignores information section",
         "UI tests must cover inert bottom-bar information area");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bottom-bar hit test maps details-info separator ownership through sort button",
         "UI tests must cover bottom-bar details-sort separator ownership");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bottom-bar hit test ignores coordinates above bottom bar",
         "UI tests must cover bottom-bar upper-bound rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bottom-bar hit test ignores coordinate at window bottom edge",
         "UI tests must cover bottom-bar exclusive lower edge");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bottom-bar hit test ignores coordinates below window",
         "UI tests must cover bottom-bar below-window rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "short bottom-bar hit test ignores clipped top padding",
         "UI tests must cover short-window bottom-bar edge handling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bottom-bar hit test handles saturated coordinates without overflow",
         "UI tests must cover saturated bottom-bar coordinate handling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bottom-bar layout keeps a usable button at large line height",
         "UI tests must cover saturated bottom-bar line-height layout");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bottom-bar hit test handles saturated line height without overflow",
         "UI tests must cover saturated bottom-bar line-height hit testing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "narrow bottom-bar hit test keeps available pixels on small-icons command",
         "UI tests must cover narrow bottom-bar command hit testing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "zero-width bottom-bar hit test stays empty",
         "UI tests must cover zero-width bottom-bar command hit testing");
   end Check_UI_Command_Hit_Test_Contract;

   procedure Check_Controller_Command_Routing_Contract is
      Controller_Body : constant String := Root & "/src/files-controller.adb";
      Operations_Body : constant String := Root & "/src/files-operations.adb";
      Tests           : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "function Execute_Command",
         "controller command routing must keep a central execution entry point");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "procedure Reconcile_Palette_Selection",
         "controller must explicitly reconcile stale command-palette selection before execution");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "if Index = 0 or else Index > Count then" & ASCII.LF
         & "         Index := 1;",
         "command-palette selection reconciliation must clamp missing or stale selections");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Visible_Rows : constant Natural := 4;",
         "command-palette selection offset logic must use a complete-row page size");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "elsif Offset > Count - Visible_Rows then" & ASCII.LF
         & "         Offset := Count - Visible_Rows;",
         "command-palette selection offset logic must clamp stale result offsets");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "function Palette_Scroll_Steps",
         "command-palette wheel movement must keep bounded scroll-step policy explicit");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "procedure Page_Palette_Selection",
         "controller must keep command-palette page movement explicit");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Step    : constant Natural := 4;",
         "command-palette page movement must match the complete-row page size");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "procedure Jump_Palette_Selection",
         "controller must keep command-palette Home and End movement explicit");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "if Files.Model.Root_Selector_Is_Open (Model)" & ASCII.LF
         & "        and then not Files.Commands.Allowed_With_Root_Selector (Id)",
         "controller command routing must block background commands behind the root selector");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "elsif Files.Model.Settings_Pane_Is_Open (Model)" & ASCII.LF
         & "        and then not Files.Commands.Allowed_With_Settings_Pane (Id)",
         "controller command routing must block background commands behind the settings pane");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "return Make_Result (Controller_Ignored, Id);",
         "modal command routing blocks must report ignored commands without mutating through operations");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "elsif not Files.Commands.Is_Enabled (Id, Model) then",
         "controller command routing must check command enablement centrally");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "| Files.Commands.Toggle_Info_Pane_Command =>",
         "disabled info-pane toggle must report a selection error operation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "disabled info toggle returns operation data",
         "controller tests must cover disabled info-toggle operation data");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "if Operation.Status = Files.Operations.Operation_Disabled" & ASCII.LF
         & "        and then Length (Operation.Error_Key) = 0" & ASCII.LF
         & "        and then not Files.Commands.Requires_Settings_Path (Id)",
         "successful state-only commands must not leak disabled operation payloads");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Operation.Status := Files.Operations.Operation_Success;",
         "successful state-only controller commands must report operation success");
      Project_Tools.Files.Require_Contains
        (Tests,
         "enabled clear-filter reports successful state-only operation",
         "controller tests must cover successful pure command operation status");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "when Files.Types.Focus_Filter_Input =>" & ASCII.LF
         & "            Files.Model.Cancel_Focus_Or_Edit (Model);" & ASCII.LF
         & "            Operation.Status := Files.Operations.Operation_Success;",
         "filter-input commit must report a successful state-only operation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter Return reports successful state-only commit",
         "controller tests must cover successful filter-input commit status");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "when Files.Types.Focus_Settings_Input =>" & ASCII.LF
         & "            declare" & ASCII.LF
         & "               Parsed : constant Files.Settings.Settings_Parse_Result :=",
         "settings-input commit must keep explicit validation handling");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Operation.Status := Files.Operations.Operation_Failed;" & ASCII.LF
         & "                  Operation.Error_Key := Parsed.Error_Key;",
         "settings-input commit must report failed validation through operation data");
      Project_Tools.Files.Require_Contains
        (Tests,
         "invalid settings field Return reports validation failure",
         "controller tests must cover settings-input Return validation failure status");
      Project_Tools.Files.Require_Contains
        (Tests,
         "valid settings field Return reports validation success",
         "controller tests must cover settings-input Return validation success status");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings add button reports update",
         "controller tests must cover settings add-entry button behavior");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings remove button reports update",
         "controller tests must cover settings remove-entry button behavior");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings value-field remove button is ignored",
         "controller tests must cover ignored settings remove-entry value-field behavior");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "if Files.Model.Focus (Model) = Files.Types.Focus_None" & ASCII.LF
         & "           and then not Files.Model.Rename_Is_Active (Model)" & ASCII.LF
         & "           and then not Files.Model.Temporary_Item_Is_Active (Model)",
         "idle Escape must not report an executed context-cancel command");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "function Successful_Command_Result" & ASCII.LF
         & "     (Command : Files.Commands.Command_Id)" & ASCII.LF
         & "      return Controller_Result",
         "direct state-only command paths must use an explicit success operation helper");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "return Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);",
         "direct Escape context-cancel paths must report operation success when they mutate state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "idle Escape is ignored",
         "controller tests must cover idle Escape as a no-op");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root selector Escape reports successful state-only close",
         "controller tests must cover root-selector Escape operation success");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename Escape reports successful state-only cancel",
         "controller tests must cover rename Escape operation success");
      Project_Tools.Files.Require_Contains
        (Tests,
         "create Escape reports successful state-only cancel",
         "controller tests must cover create Escape operation success");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Files.Model.Cancel_Focus_Or_Edit (Model);" & ASCII.LF
         & "      if Visible_Index > Files.Model.Visible_Count (Model) then" & ASCII.LF
         & "         return Successful_Command_Result (Files.Commands.Close_Command_Palette_Command);",
         "item clicks must not select a stale row after canceling a temporary create item");
      Project_Tools.Files.Require_Contains
        (Tests,
         "temporary-row item click does not leave a zero selection",
         "controller tests must cover item-click cancellation of the only temporary row");
      Project_Tools.Files.Require_Contains
        (Tests,
         "pure save settings command keeps runtime path-resolution sentinel",
         "controller tests must preserve settings-path runtime resolution sentinel");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "return Execute_Command (Id, Model, Settings, Modifiers);",
         "controller command clicks must route through the central execution entry point");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "if not Files.Model.Root_Selector_Is_Open (Model)" & ASCII.LF
         & "        or else Root_Index = 0",
         "controller root-row clicks must require an open root selector");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Target = Files.Types.Focus_Command_Palette" & ASCII.LF
         & "        and then not Files.Model.Command_Palette_Is_Open (Model)",
         "controller text clicks must reject command-palette focus when the palette is closed");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Target = Files.Types.Focus_Settings_Input" & ASCII.LF
         & "        and then not Files.Model.Settings_Pane_Is_Open (Model)",
         "controller text clicks must reject settings focus when the settings pane is closed");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Target = Files.Types.Focus_Rename_Input" & ASCII.LF
         & "        and then not Files.Model.Rename_Is_Active (Model)",
         "controller text clicks must reject rename focus when rename mode is inactive");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "return Execute_Command (Files.Commands.Open_Selected_Items_Command, Model, Settings, Modifiers);",
         "controller item activation and unfocused Return must route through the open-selected command");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Execute_Command (Results.Element (Positive (Index)).Command, Model, Settings, Modifiers);",
         "controller palette Return must execute selected results through the central command entry point");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Execute_Command (Results.Element (Positive (Result_Index)).Command, Model, Settings, Modifiers);",
         "controller palette clicks must execute selected results through the central command entry point");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "return Execute_Command (Action.Command, Model, Settings, Modifiers);",
         "controller keyboard command actions must route through the central command entry point");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "function Handle_Targeted_Scroll",
         "controller must expose targeted scroll dispatch for hit-tested scroll areas");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Target /= Files.Events.Scroll_Command_Palette",
         "controller must block non-palette targeted scrolls while the command palette is open");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Files.Model.Root_Selector_Is_Open (Model)" & ASCII.LF
         & "        and then not Files.Model.Command_Palette_Is_Open (Model)",
         "controller targeted scroll routing must block background scrolling behind the root selector");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "Files.Model.Settings_Pane_Is_Open (Model)" & ASCII.LF
         & "        and then not Files.Model.Command_Palette_Is_Open (Model)",
         "controller targeted scroll routing must block background scrolling behind the settings pane");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "when Files.Events.Scroll_Auto =>",
         "controller targeted scroll routing must preserve automatic scroll fallback");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root selector blocks targeted auto scroll",
         "controller tests must cover root-selector blocking of targeted automatic scrolls");
      Project_Tools.Files.Require_Contains
        (Tests,
         "closed root selector row click does not navigate",
         "controller tests must cover stale closed-selector root row rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "closed palette text click does not focus input",
         "controller tests must cover stale closed-palette text click rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "closed settings text click does not focus input",
         "controller tests must cover stale closed-settings text click rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "inactive rename text click does not focus input",
         "controller tests must cover stale inactive-rename text click rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings pane blocks auto info scroll",
         "controller tests must cover settings-pane blocking of automatic info-pane scrolls");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings pane blocks auto main scroll",
         "controller tests must cover settings-pane blocking of automatic main-view scrolls");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "when Files.Events.Scroll_Command_Palette =>",
         "controller targeted scroll routing must support command-palette scrolling");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "when Files.Events.Scroll_Info_Pane =>",
         "controller targeted scroll routing must support info-pane scrolling");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "when Files.Events.Scroll_Main_View =>",
         "controller targeted scroll routing must support main-view scrolling");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "return Scroll_Info_Result (Model, Lines);",
         "controller targeted info-pane scrolls must reuse the info-pane scroll result path");
      Project_Tools.Files.Require_Contains
        (Controller_Body,
         "return Scroll_Main_Result (Model, Lines);",
         "controller targeted main-view scrolls must reuse the main-view scroll result path");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Control+L executes focus command",
         "controller tests must cover keyboard shortcut command routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "F2 executes rename command",
         "controller tests must cover rename shortcut command routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings pane blocks background delete command",
         "controller tests must cover settings modal command blocking");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings modal block preserves existing error",
         "controller tests must cover settings modal block diagnostic preservation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root selector blocks direct path focus command",
         "controller tests must cover root selector command blocking");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root selector blocks direct settings command",
         "controller tests must cover root selector blocking settings pane commands");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root selector settings block preserves existing error",
         "controller tests must cover root selector settings block diagnostic preservation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "modal command block does not replace existing error",
         "controller tests must cover root selector modal block diagnostic preservation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette Return executes selected command",
         "controller tests must cover command-palette Return execution");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette click executes result command",
         "controller tests must cover command-palette click execution");
      Project_Tools.Files.Require_Contains
        (Tests,
         "disabled palette Return reports localized error key",
         "controller tests must cover disabled command-palette Return diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "disabled palette click reports localized error key",
         "controller tests must cover disabled command-palette click diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "disabled clear palette click reports empty-filter error",
         "controller tests must cover disabled clear-filter palette diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "disabled root-open click reports empty-root error",
         "controller tests must cover disabled root-open palette diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "disabled settings save click reports closed-settings error",
         "controller tests must cover disabled settings-save palette diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "disabled settings reset click reports closed-settings error",
         "controller tests must cover disabled settings-reset palette diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "disabled create palette click reports pending-create error",
         "controller tests must cover disabled create-file palette diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings-modal disabled palette Return preserves existing error",
         "controller tests must cover modal disabled palette diagnostic preservation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter Backspace does not route delete command",
         "controller tests must cover text-field Backspace command suppression");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter Delete does not route delete command",
         "controller tests must cover text-field Delete command suppression");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-controller.adb",
         "Files.UTF8.Previous_Boundary (Text, Cursor)",
         "controller text deletion must use the shared UTF-8 previous-boundary helper");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-controller.adb",
         "Files.UTF8.Next_Boundary (Text, Cursor)",
         "controller text deletion must use the shared UTF-8 next-boundary helper");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-events.adb",
         "Files.UTF8.Byte_Offset_For_Display_Column (Raw, Click_Column)",
         "event click cursor placement must use the shared UTF-8 display-column helper");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-model.adb",
         "Files.UTF8.Previous_Boundary (Text, Cursor)",
         "model text cursor movement must use the shared UTF-8 previous-boundary helper");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-model.adb",
         "Files.UTF8.Boundary_At_Or_Before (Text, Cursor)",
         "model text cursor setting must normalize through the shared UTF-8 boundary helper");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-model.adb",
         "return Text_Boundary_At_Or_Before (Settings_Field_Text (Model), Model.Settings_Field_Cursor);",
         "model text cursor reads must normalize stale settings UTF-8 cursor boundaries");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter Left moves over whole UTF-8 input",
         "controller tests must cover UTF-8-aware left cursor movement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter Left moves over base and trailing combining marks together",
         "controller tests must cover combining-aware left cursor movement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "model cursor setter snaps combining mark starts to the base boundary",
         "model tests must cover combining-aware direct cursor placement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter Right moves over base and trailing combining marks together",
         "controller tests must cover combining-aware right cursor movement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter append leaves cursor after appended trailing combining mark",
         "controller tests must cover combining-aware append cursor placement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter click snaps UTF-8 cursor to character boundary",
         "controller tests must cover UTF-8-aware click cursor placement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "model cursor setter snaps UTF-8 cursor to character boundary",
         "model tests must cover UTF-8-aware direct cursor placement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings draft replacement snaps stale UTF-8 cursor to character boundary",
         "model tests must cover UTF-8-aware stale settings cursor reconciliation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter Backspace removes whole UTF-8 input",
         "controller tests must cover UTF-8-aware backward deletion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter Backspace removes base and trailing combining marks together",
         "controller tests must cover combining-aware backward deletion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter Delete removes whole UTF-8 input",
         "controller tests must cover UTF-8-aware forward deletion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter Delete removes base and trailing combining marks together",
         "controller tests must cover combining-aware forward deletion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper moves previous boundary over whole multibyte units",
         "tests must cover shared UTF-8 previous-boundary movement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper moves next boundary over whole multibyte units",
         "tests must cover shared UTF-8 next-boundary movement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper snaps interior offsets to earlier boundaries",
         "tests must cover shared UTF-8 boundary normalization");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper snaps combining mark starts to the base boundary",
         "tests must cover combining-aware boundary normalization");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper counts display units before byte cursor",
         "tests must cover shared UTF-8 display count before cursor");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper maps display column to UTF-8 byte offset",
         "tests must cover shared UTF-8 display-column byte mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Control+P routes through command registry from filter input",
         "controller tests must cover global command-palette shortcut routing from text fields");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Control+P routes through command registry from path input",
         "controller tests must cover global command-palette shortcut routing from path input");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette shortcut preserves edited path input text",
         "controller tests must cover path input state preservation across palette shortcuts");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Control+P routes from rename input",
         "controller tests must cover global command-palette shortcut routing from rename input");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette Backspace does not route delete command",
         "controller tests must cover command-palette Backspace command suppression");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette Control+Delete removes next query word",
         "controller tests must cover command-palette word deletion");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.adb",
         "or else Codepoint = 10" & ASCII.LF
         & "        or else Codepoint = 11" & ASCII.LF
         & "        or else Codepoint = 12" & ASCII.LF
         & "        or else Codepoint = 13",
         "shared UTF-8 word separators must include ASCII line-break whitespace");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.ads",
         "function Word_Separator_Length",
         "shared UTF-8 helper must expose word-separator measurement");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-controller.adb",
         "Files.UTF8.Previous_Word_Boundary (Text, Cursor)",
         "focused text previous-word movement must use the shared UTF-8 helper");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-controller.adb",
         "Files.UTF8.Next_Word_Boundary (Text, Cursor)",
         "focused text next-word movement must use the shared UTF-8 helper");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.adb",
         "Position := Previous_Boundary (Content, Position);",
         "shared previous-word helper must step by UTF-8 text boundaries");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.adb",
         "Position := Next_Boundary (Content, Position);",
         "shared next-word helper must step by UTF-8 text boundaries");
      Require_Not_Contains
        (Root & "/src/files-controller.adb",
         "function UTF8_Word_Separator_Length",
         "controller must not keep a local UTF-8 word-separator scanner");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper finds previous word boundary",
         "tests must cover shared UTF-8 previous-word helper");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper finds next word boundary",
         "tests must cover shared UTF-8 next-word helper");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper moves previous word boundary over whole multibyte text",
         "tests must cover previous-word movement over multibyte text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper moves next word boundary over combining text",
         "tests must cover next-word movement over combining text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Control+Left treats line feed as word separator",
         "controller tests must cover line-feed word navigation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Control+Backspace removes previous word across line feed",
         "controller tests must cover line-feed word deletion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Control+Left treats carriage return as word separator",
         "controller tests must cover carriage-return word navigation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Control+Left treats vertical tab as word separator",
         "controller tests must cover vertical-tab word navigation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Control+Backspace removes previous word across vertical tab",
         "controller tests must cover vertical-tab word deletion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Control+Delete removes next word across form feed",
         "controller tests must cover form-feed forward word deletion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Control+Left treats UTF-8 NBSP as word separator",
         "controller tests must cover UTF-8 no-break-space word navigation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Control+Backspace removes previous word across UTF-8 NBSP",
         "controller tests must cover UTF-8 no-break-space backward word deletion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Control+Delete removes next word across UTF-8 NBSP",
         "controller tests must cover UTF-8 no-break-space forward word deletion");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Control+Left treats UTF-8 line separator as word separator",
         "controller tests must cover UTF-8 line-separator word navigation");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-model.adb",
         "Model.Filter_Cursor := Length (Model.Filter_Value);",
         "filter focus must place the cursor at the current filter text end");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-model.adb",
         "Model.Path_Input_Value := To_Unbounded_String (Text);" & ASCII.LF
         & "      Model.Path_Input_Cursor := Text'Length;" & ASCII.LF
         & "      Model.Path_Input_Valid := True;" & ASCII.LF
         & "      Model.Path_Input_Error := Null_Unbounded_String;",
         "path input edits must clear stale validation state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter shortcut refocus places cursor at text end",
         "controller tests must cover deterministic filter cursor placement on refocus");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename Backspace edits text",
         "controller tests must cover rename-field Backspace editing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "modified Return does not commit path input",
         "controller tests must cover modified Return path-input suppression");
      Project_Tools.Files.Require_Contains
        (Tests,
         "path input edit clears stale validation state",
         "controller tests must cover path-input edit validation reset");
      Project_Tools.Files.Require_Contains
        (Tests,
         "file path input navigates to parent directory",
         "controller tests must cover path-input file paths resolving to parent directories");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Return open preserves modifier-specific action lookup",
         "controller tests must cover modifier-specific open action routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Backspace delete uses trash operation",
         "controller tests must cover secondary delete shortcut execution");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Control+P opens palette over rename state",
         "controller tests must cover command-palette priority over rename state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Escape first closes palette",
         "controller tests must cover Escape closing palette before other edit cancellation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "second Escape cancels pending rename",
         "controller tests must cover Escape rename cancellation after palette closes");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Escape cancels temporary item after path focus",
         "controller tests must cover Escape canceling focused temporary create state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty palette renders localized empty state",
         "controller tests must cover empty command-palette visual state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty palette exposes accessible status node",
         "controller tests must cover empty command-palette accessibility state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Down clamps extreme stale palette selection",
         "controller tests must cover stale command-palette selection clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "PageDown clamps extreme stale palette selection",
         "controller tests must cover page movement with stale command-palette selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "stale palette offset clamps to last full page",
         "controller tests must cover stale command-palette offset clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette PageDown jumps by page",
         "controller tests must cover command-palette PageDown movement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "paged palette keeps selected result visible",
         "controller tests must cover visible selected rows after paging");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette PageUp restores top offset",
         "controller tests must cover command-palette PageUp offset restoration");
      Project_Tools.Files.Require_Contains
        (Tests,
         "narrowed query reconciles selection",
         "controller tests must cover palette query narrowing selection reconciliation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "scrolled palette click executes visible absolute result",
         "controller tests must cover scrolled command-palette result clicks");
      Project_Tools.Files.Require_Contains
        (Tests,
         "single palette result ignores PageDown",
         "controller tests must cover single-result command-palette movement no-ops");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar click maps drive command",
         "event tests must cover toolbar click command mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "bottom-bar click maps details command",
         "event tests must cover bottom-bar click command mapping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root selector blocks targeted main scroll",
         "controller tests must cover root-selector targeted scroll blocking");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings pane blocks targeted info scroll",
         "controller tests must cover settings-pane targeted info scroll blocking");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings pane blocks targeted main scroll",
         "controller tests must cover settings-pane targeted main scroll blocking");
      Project_Tools.Files.Require_Contains
        (Tests,
         "large info scroll is handled",
         "controller tests must cover saturated info-pane targeted scrolling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "large main scroll is handled",
         "controller tests must cover saturated main-view targeted scrolling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "negative exact-count palette scroll advances instead of no-op",
         "controller tests must cover reverse exact-count command-palette wheel movement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "saturated targeted palette scroll is handled",
         "controller tests must cover saturated command-palette targeted scrolling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty palette ignores targeted scroll",
         "controller tests must cover empty command-palette targeted scrolling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette blocks targeted main scroll",
         "controller tests must cover palette blocking non-palette targeted scrolling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "failed home reports path diagnostic",
         "controller tests must cover failed home path normalization diagnostics");
      Project_Tools.Files.Require_Contains
        (Operations_Body,
         "Files.File_System.Normalize_Path (Files.Model.Home_Path (Model))",
         "home navigation must normalize the configured home path before loading");
      Project_Tools.Files.Require_Contains
        (Tests,
         "failed home preserves temporary create state",
         "controller tests must cover failed home preserving edit state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "failed refresh preserves command palette",
         "controller tests must cover failed refresh preserving command palette state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "failed back preserves back history",
         "controller tests must cover failed back preserving history state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "failed forward preserves forward history",
         "controller tests must cover failed forward preserving history state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "failed forward restores rename focus",
         "controller tests must cover failed forward preserving rename focus");
      Project_Tools.Files.Require_Contains
        (Tests,
         "new controller navigation clears forward history",
         "controller tests must cover path-input navigation clearing forward history");
   end Check_Controller_Command_Routing_Contract;

   procedure Check_Model_State_Contract is
      Model_Body : constant String := Root & "/src/files-model.adb";
      Tests      : constant String := Combined_Suite;
      Content    : constant String := To_String (Project_Tools.Text.Read_Text_File (Model_Body));
      Marker     : constant String := "Model.Command_Palette_Query := Null_Unbounded_String;";
      Reset      : constant String := "Model.Command_Palette_Cursor := 0;";
      Search     : Positive := Content'First;

      function Reset_Follows (From : Positive) return Boolean is
         Index : Natural := From;
         Lines : Natural := 0;
      begin
         while Index <= Content'Last and then Lines <= 5 loop
            if Index + Reset'Length - 1 <= Content'Last
              and then Content (Index .. Index + Reset'Length - 1) = Reset
            then
               return True;
            elsif Content (Index) = ASCII.LF then
               Lines := Lines + 1;
            end if;
            Index := Index + 1;
         end loop;

         return False;
      end Reset_Follows;
   begin
      loop
         declare
            Found : constant Natural :=
              Ada.Strings.Fixed.Index
                (Source  => Content,
                 Pattern => Marker,
                 From    => Search);
         begin
            exit when Found = 0;

            if not Reset_Follows (Found + Marker'Length) then
               Put_Line
                 (Standard_Error,
                  "files model must reset command-palette cursor whenever it clears the query");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;

            Search := Natural'Min (Found + Marker'Length, Content'Last);
         end;
      end loop;

      Project_Tools.Files.Require_Contains
        (Model_Body,
         "procedure Reconcile_Selection",
         "model must centralize visible-selection reconciliation");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Reconcile_Selection (Model);",
         "model filtering must reconcile selected items after visible projection changes");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "if Count = 0 then",
         "model selection movement must handle empty visible projections");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "elsif Current = 0 then",
         "model selection movement must select the first visible item when none is selected");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "if Current = 1 then",
         "model selection movement must wrap backward from the first visible item");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "if Current = Count then",
         "model selection movement must wrap forward from the last visible item");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "if Current_Path (Model) /= Directory_Path then",
         "model navigation must only push history when the path changes");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Model.Forward_History.Clear;",
         "model navigation must clear forward history on new navigation");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Model.Temporary_Active := False;",
         "model navigation and edit cancellation must clear temporary create state");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "return Selected_Count (Model) = 1 and then not Selected_Item_Is_Temporary (Model);",
         "model rename enablement must enforce single non-temporary selection");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "procedure Reconcile_Rename_With_Selection",
         "model must centralize stale rename cancellation after selection changes");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Effective_Selected_Item_Index (Model) /= Model.Rename_Item_Index",
         "model stale rename cancellation must compare against the original rename target");
      Project_Tools.Files.Require_Contains
        (Tests,
         "selection change cancels stale rename mode",
         "model tests must cover stale rename cancellation after selection changes");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter hiding rename target cancels rename mode",
         "model tests must cover stale rename cancellation after filtering");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Single_Item_Only       => True",
         "model rename policy must explicitly choose single-item rename");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Clear_Overlay_State_For_Edit (Model);",
         "model rename and create edit state must close stale overlays");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Model.Selected_Item_Index := Temporary_Item_Index;",
         "model create-file state must select the temporary item");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "procedure Toggle_Visible_Selection",
         "model must centralize deterministic multi-selection toggles");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Remove_Selected_Index (Model, Item_Index);",
         "model toggle selection must remove already selected items");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "else" & ASCII.LF
         & "         Add_Selected_Index (Model, Item_Index);" & ASCII.LF
         & "         Model.Selected_Item_Index := Item_Index;",
         "model toggle selection must add new selected items and make them primary");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "procedure Select_Visible_Range",
         "model must centralize deterministic visible range selection");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "First := Natural'Min (Natural (Anchor_Index), Natural (Target_Index));",
         "model range selection must normalize reverse anchor and target order");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "for Visible_Index in First .. Last loop",
         "model range selection must include every visible item in the range");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Model.Selected_Item_Indexes.Clear;",
         "model navigation and range selection must clear stale multi-selection state");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Model.Info_Pane_Scroll := 0;" & ASCII.LF
         & "      Reconcile_Rename_With_Selection (Model);",
         "model selection changes must reset info-pane scroll before stale rename reconciliation");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Model.Main_View_Scroll := 0;" & ASCII.LF
         & "      Model.Info_Pane_Scroll := 0;" & ASCII.LF
         & "      Model.Selected_Item_Index := 0;",
         "model item replacement must reset both main and info-pane scroll with stale selection state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "single selection resets info pane scroll",
         "model tests must cover info-pane scroll reset after single selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toggle selection resets info pane scroll",
         "model tests must cover info-pane scroll reset after toggle selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "range selection resets info pane scroll",
         "model tests must cover info-pane scroll reset after range selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "clear selection resets info pane scroll",
         "model tests must cover info-pane scroll reset after clearing selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "refresh resets info pane scroll",
         "controller tests must cover info-pane scroll reset after directory replacement");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Model.Path_Input_Valid := True;" & ASCII.LF
         & "      Model.Path_Input_Error := Null_Unbounded_String;",
         "model navigation and history movement must reset path validation state");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "Model.Command_Palette_Open := False;" & ASCII.LF
         & "      Model.Command_Palette_Query := Null_Unbounded_String;" & ASCII.LF
         & "      Model.Command_Palette_Selected := 0;" & ASCII.LF
         & "      Model.Command_Palette_Offset := 0;",
         "model navigation and history movement must clear command-palette state");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "function Selected_Items",
         "model must expose selected real items for filesystem operations");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "for Index in Model.Items.First_Index .. Model.Items.Last_Index loop",
         "selected-items API must return selected entries in deterministic loaded-item order");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "if Selection_Contains (Model, Natural (Index)) then" & ASCII.LF
         & "            Result.Append (Model.Items.Element (Index));",
         "selected-items API must exclude transient create-file selections from operation inputs");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "function Selection_Includes_Temporary",
         "model must expose whether a multi-selection includes a transient create-file item");
      Project_Tools.Files.Require_Contains
        (Model_Body,
         "if Index = Temporary_Item_Index then",
         "temporary selection detection must inspect the deterministic multi-selection set");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filtered-out selection moves to first visible item",
         "model tests must cover selection reconciliation after filtering");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-types.adb",
         "Character'Pos (Text (Index)) = 16#C3#",
         "shared case folding must recognize UTF-8 Latin-1 uppercase lead bytes");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-types.adb",
         "and then Character'Pos (Text (Index)) in 16#C2# .. 16#DF#",
         "shared case folding must preserve valid lowercase UTF-8 units");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter matches UTF-8 Latin-1 item names case-insensitively",
         "model tests must cover UTF-8 Latin-1 case-insensitive filtering");
      Project_Tools.Files.Require_Contains
        (Tests,
         "selection becomes empty when no items are visible",
         "model tests must cover empty filtered selection state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter reconciliation drops invisible multi-selected items",
         "model tests must cover multi-selection reconciliation after filtering");
      Project_Tools.Files.Require_Contains
        (Tests,
         "left from first wraps to last",
         "model tests must cover backward selection wraparound");
      Project_Tools.Files.Require_Contains
        (Tests,
         "right from last wraps to first",
         "model tests must cover forward selection wraparound");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toggle adds a second deterministic selection",
         "model tests must cover deterministic selection toggles");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toggle removes selected item",
         "model tests must cover selection toggle removal");
      Project_Tools.Files.Require_Contains
        (Tests,
         "primary selection falls back to remaining selected item",
         "model tests must cover primary selection fallback after toggle removal");
      Project_Tools.Files.Require_Contains
        (Tests,
         "range selection selects every visible item",
         "model tests must cover visible range selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "reverse range selection selects every visible item",
         "model tests must cover reverse visible range selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "reverse range selection makes target primary",
         "model tests must cover reverse range primary selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shift-click selects a deterministic visible range",
         "controller/model tests must cover shift-click range selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "focused input suppresses arrow selection",
         "controller/model tests must cover text focus suppressing selection movement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "same-path navigation clears multi-selection state",
         "model tests must cover same-path navigation cleanup");
      Project_Tools.Files.Require_Contains
        (Tests,
         "navigation clears multi-selection state",
         "model tests must cover navigation selection cleanup");
      Project_Tools.Files.Require_Contains
        (Tests,
         "back closes command palette",
         "model tests must cover back-history overlay cleanup");
      Project_Tools.Files.Require_Contains
        (Tests,
         "forward closes command palette",
         "model tests must cover forward-history overlay cleanup");
      Project_Tools.Files.Require_Contains
        (Tests,
         "new navigation after back clears forward history",
         "model tests must cover forward-history clearing on new navigation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "back clears temporary create state",
         "model tests must cover back navigation clearing temporary create state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rename policy is explicit single-item rename",
         "model tests must cover the explicit rename policy");
      Project_Tools.Files.Require_Contains
        (Tests,
         "temporary item is the visible item while pending",
         "model tests must cover temporary create item projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "selected items API returns all selected items",
         "model tests must cover deterministic selected-items API output");
      Project_Tools.Files.Require_Contains
        (Tests,
         "selected items use item order",
         "model tests must cover selected-items loaded-order stability");
      Project_Tools.Files.Require_Contains
        (Tests,
         "selected items excludes the transient create-file item",
         "model tests must cover transient create-file exclusion from selected operation inputs");
      Project_Tools.Files.Require_Contains
        (Tests,
         "model identifies temporary item inside mixed selection",
         "model tests must cover temporary detection inside multi-selection");
   end Check_Model_State_Contract;

   procedure Check_Crate_Structure is
      Main_Manifest  : constant String := Root & "/alire.toml";
      Top_Tests_Manifest : constant String := Root & "/tests/alire.toml";
      Tests_Manifest : constant String := Root & "/tests/tests/alire.toml";
      Tools_Manifest : constant String := Root & "/tools/alire.toml";
      Main_Project   : constant String := Root & "/files.gpr";
      Top_Tests_Project : constant String := Root & "/tests/tests.gpr";
      Tests_Project  : constant String := Root & "/tests/tests/tests.gpr";
      Tools_Project  : constant String := Root & "/tools/files_check_all.gpr";
      Main_Ignore    : constant String := Root & "/.gitignore";
      Top_Tests_Ignore : constant String := Root & "/tests/.gitignore";
      Tests_Ignore   : constant String := Root & "/tests/tests/.gitignore";
      Tools_Ignore   : constant String := Root & "/tools/.gitignore";
   begin
      Project_Tools.Files.Require_Files
        ([To_Unbounded_String (Main_Project),
          To_Unbounded_String (Top_Tests_Manifest),
          To_Unbounded_String (Top_Tests_Project),
          To_Unbounded_String (Tests_Project),
          To_Unbounded_String (Tools_Manifest),
          To_Unbounded_String (Tools_Project),
          To_Unbounded_String (Root & "/tools/src/check_all.adb"),
          To_Unbounded_String (Root & "/tools/src/cldr_to_catalog.adb"),
          To_Unbounded_String (Main_Ignore),
          To_Unbounded_String (Top_Tests_Ignore),
          To_Unbounded_String (Tests_Ignore),
          To_Unbounded_String (Tools_Ignore)],
         "files checker tooling must be implemented as an Ada Alire helper crate");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "name = ""files""",
         "files must be the main Alire crate");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "executables = [""files""]",
         "files crate must build the files executable");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "project_tools = ""*""",
         "files must depend on the project_tools crate");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "project_tools = { path = ""../project_tools"" }",
         "files must pin project_tools to the local relative crate");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "i18n = ""*""",
         "files must depend on the i18n crate");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "i18n = { path = ""../i18n"" }",
         "files must pin i18n to the local relative crate");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "textrender = ""*""",
         "files must depend on the textrender crate");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "textrender = { path = ""../textrender"" }",
         "files must pin textrender to the local relative crate");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "df_vulkan = ",
         "files must depend on df_vulkan for rendering");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "openglada_glfw = ",
         "files must depend on openglada_glfw for windowing");
      Project_Tools.Files.Require_Contains
        (Main_Project,
         "for Source_Dirs use (""src/"", ""config/"", ""src/platform/windows"");",
         "files project must include Windows platform source directories");
      Project_Tools.Files.Require_Contains
        (Main_Project,
         "for Source_Dirs use (""src/"", ""config/"", ""src/platform/macos"");",
         "files project must include macOS platform source directories");
      Project_Tools.Files.Require_Contains
        (Main_Project,
         "for Source_Dirs use (""src/"", ""config/"", ""src/platform/unsupported"");",
         "files project must include unsupported-platform fallback sources");
      Project_Tools.Files.Require_Contains
        (Main_Project,
         "for Main use (""files-main.adb"");",
         "files project must build the Ada main program");
      Project_Tools.Files.Require_Contains
        (Main_Project,
         "for Executable (""files-main.adb"") use ""files"";",
         "files project must produce the expected files executable");
      Project_Tools.Files.Require_Contains
        (Main_Project,
         """-gnat2022""",
         "files project must compile as Ada 2022");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Manifest,
         "name = ""tests""",
         "top-level tests path must be an Alire sub-crate");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Manifest,
         "executables = [""tests""]",
         "top-level tests crate must build the tests executable");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Manifest,
         "files = ""*""",
         "top-level tests crate must depend on the parent files crate");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Manifest,
         "files = { path = "".."" }",
         "top-level tests crate must pin files to the local parent crate");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Manifest,
         "project_tools = ""*""",
         "top-level tests crate must depend on the project_tools crate");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Manifest,
         "project_tools = { path = ""../../project_tools"" }",
         "top-level tests crate must pin project_tools to the local relative crate");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Manifest,
         "aunit = ",
         "top-level tests crate must depend on AUnit");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Project,
         "for Source_Dirs use (""tests/src/"", ""config/"");",
         "top-level tests project must reuse test and generated configuration sources");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Project,
         "for Main use (""tests.adb"");",
         "top-level tests project must build the Ada test runner");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Project,
         "for Executable (""tests.adb"") use ""tests"";",
         "top-level tests project must produce the expected tests executable");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Project,
         """-gnat2022""",
         "top-level tests project must compile as Ada 2022");
      Project_Tools.Files.Require_Contains
        (Root & "/tools/src/check_all.adb",
         "Run (""top-level tests build"", Root & ""/tests"", Alr, [1 => new String'(""build"")]);",
         "full validation must build the top-level tests sub-crate");
      Project_Tools.Files.Require_Contains
        (Root & "/tools/src/check_all.adb",
         "Run (""top-level AUnit tests"", Root & ""/tests"", ""./bin/tests"", []);",
         "full validation must run the top-level tests sub-crate");
      Project_Tools.Files.Require_Contains
        (Tests_Manifest,
         "name = ""tests""",
         "tests must be an Alire sub-crate");
      Project_Tools.Files.Require_Contains
        (Tests_Manifest,
         "executables = [""tests""]",
         "tests crate must build the tests executable");
      Project_Tools.Files.Require_Contains
        (Tests_Manifest,
         "files = ""*""",
         "tests crate must depend on the parent files crate");
      Project_Tools.Files.Require_Contains
        (Tests_Manifest,
         "files = { path = ""../.."" }",
         "tests crate must pin files to the local parent crate");
      Project_Tools.Files.Require_Contains
        (Tests_Manifest,
         "project_tools = ""*""",
         "tests crate must depend on the project_tools crate");
      Project_Tools.Files.Require_Contains
        (Tests_Manifest,
         "project_tools = { path = ""../../../project_tools"" }",
         "tests crate must pin project_tools to the local relative crate");
      Project_Tools.Files.Require_Contains
        (Tests_Manifest,
         "aunit = ",
         "tests crate must depend on AUnit");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "files crate pins textrender to the local relative path",
         "first-implementation policy tests must cover the textrender local pin");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "files project keeps platform-specific source directories wired",
         "first-implementation policy tests must cover platform-specific source directories");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "files project builds the expected binary entry point",
         "first-implementation policy tests must cover the files binary entry point");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "nested tests project builds the expected AUnit runner",
         "first-implementation policy tests must cover the nested AUnit runner");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "nested tests project keeps Ada 2022 test sources wired",
         "first-implementation policy tests must cover nested tests source wiring");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "checker tooling project builds the expected Ada helper",
         "first-implementation policy tests must cover checker executable wiring");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "checker tooling project keeps Ada 2022 sources wired",
         "first-implementation policy tests must cover checker source wiring");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "main crate ignores generated build artifacts",
         "first-implementation policy tests must cover main generated-artifact ignores");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "top-level tests crate ignores generated build artifacts",
         "first-implementation policy tests must cover top-level tests generated-artifact ignores");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "nested tests crate ignores generated build artifacts",
         "first-implementation policy tests must cover nested tests generated-artifact ignores");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "checker tooling crate ignores generated build artifacts",
         "first-implementation policy tests must cover checker generated-artifact ignores");
      Project_Tools.Files.Require_Contains
        (Tests_Project,
         "for Source_Dirs use (""src/"", ""config/"");",
         "tests project must include test and generated configuration sources");
      Project_Tools.Files.Require_Contains
        (Tests_Project,
         "for Main use (""tests.adb"");",
         "tests project must build the Ada test runner");
      Project_Tools.Files.Require_Contains
        (Tests_Project,
         "for Executable (""tests.adb"") use ""tests"";",
         "tests project must produce the expected tests executable");
      Project_Tools.Files.Require_Contains
        (Tests_Project,
         """-gnat2022""",
         "tests project must compile as Ada 2022");
      Project_Tools.Files.Require_Contains
        (Tools_Manifest,
         "name = ""files_check_all""",
         "checker tooling must be a named Alire crate");
      Project_Tools.Files.Require_Contains
        (Tools_Manifest,
         "executables = [""check_all"", ""cldr_to_catalog""]",
         "checker tooling crate must build all Ada helper executables");
      Project_Tools.Files.Require_Contains
        (Tools_Manifest,
         "project_tools = ""*""",
         "checker tooling must depend on the project_tools crate");
      Project_Tools.Files.Require_Contains
        (Tools_Manifest,
         "project_tools = { path = ""../../project_tools"" }",
         "checker tooling must pin project_tools to the local relative crate");
      Project_Tools.Files.Require_Contains
        (Tools_Project,
         "for Main use (""check_all.adb"", ""cldr_to_catalog.adb"");",
         "checker tooling project must build Ada tool mains");
      Project_Tools.Files.Require_Contains
        (Tools_Project,
         "for Executable (""check_all.adb"") use ""check_all"";",
         "checker tooling project must produce the expected checker executable");
      Project_Tools.Files.Require_Contains
        (Tools_Project,
         "for Executable (""cldr_to_catalog.adb"") use ""cldr_to_catalog"";",
         "checker tooling project must produce the CLDR importer executable");
      Project_Tools.Files.Require_Contains
        (Tools_Project,
         """-gnat2022""",
         "checker tooling project must compile as Ada 2022");
      Project_Tools.Files.Require_Contains
        (Main_Ignore,
         "/obj/",
         "files crate must ignore generated object directories");
      Project_Tools.Files.Require_Contains
        (Main_Ignore,
         "/bin/",
         "files crate must ignore generated executable directories");
      Project_Tools.Files.Require_Contains
        (Main_Ignore,
         "/alire/",
         "files crate must ignore generated Alire state");
      Project_Tools.Files.Require_Contains
        (Main_Ignore,
         "/config/",
         "files crate must ignore generated Alire config");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Ignore,
         "/obj/",
         "top-level tests crate must ignore generated object directories");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Ignore,
         "/bin/",
         "top-level tests crate must ignore generated executable directories");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Ignore,
         "/alire/",
         "top-level tests crate must ignore generated Alire state");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Ignore,
         "/config/",
         "top-level tests crate must ignore generated Alire config");
      Project_Tools.Files.Require_Contains
        (Tests_Ignore,
         "/obj/",
         "tests crate must ignore generated object directories");
      Project_Tools.Files.Require_Contains
        (Tests_Ignore,
         "/bin/",
         "tests crate must ignore generated executable directories");
      Project_Tools.Files.Require_Contains
        (Tests_Ignore,
         "/alire/",
         "tests crate must ignore generated Alire state");
      Project_Tools.Files.Require_Contains
        (Tests_Ignore,
         "/config/",
         "tests crate must ignore generated Alire config");
      Project_Tools.Files.Require_Contains
        (Tools_Ignore,
         "/obj/",
         "checker tooling crate must ignore generated object directories");
      Project_Tools.Files.Require_Contains
        (Tools_Ignore,
         "/bin/",
         "checker tooling crate must ignore generated executable directories");
      Project_Tools.Files.Require_Contains
        (Tools_Ignore,
         "/alire/",
         "checker tooling crate must ignore generated Alire state");
      Project_Tools.Files.Require_Contains
        (Tools_Ignore,
         "/config/",
         "checker tooling crate must ignore generated Alire config");
   end Check_Crate_Structure;

   procedure Check_Startup_Path_Contract is
      Application_Spec : constant String := Root & "/src/files-application.ads";
      Application_Body : constant String := Root & "/src/files-application.adb";
      File_System_Body : constant String := Root & "/src/files-file_system.adb";
      Tests            : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Application_Spec,
         "function Default_Settings_Path",
         "startup settings path selection must keep default-path construction testable");
      Project_Tools.Files.Require_Contains
        (Application_Spec,
         "function Configured_Settings_Path",
         "startup settings path selection must keep environment selection testable");
      Project_Tools.Files.Require_Contains
        (Application_Spec,
         "FILES_SETTINGS overrides all defaults. XDG_CONFIG_HOME selects an XDG path",
         "startup settings path precedence must be documented in the public startup contract");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Files.Settings.Ensure_Default_File (Effective_Path)",
         "startup must create a missing default settings file before loading settings");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Files.Settings.Load_File (Effective_Path)",
         "startup must load settings through the settings parser");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Result.Settings_Path := To_Unbounded_String (Effective_Path);",
         "startup result must record the effective settings path");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "if Settings_Path = """" then Configured_Settings_Path (Home) else Settings_Path",
         "startup must use configured settings only when no explicit settings path is provided");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "function Safe_Environment_Value (Name : String) return String is",
         "startup environment lookup must be centralized and exception-safe");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Safe_Environment_Value (""FILES_SETTINGS"")",
         "startup settings path selection must honor FILES_SETTINGS");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Safe_Environment_Value (""XDG_CONFIG_HOME"")",
         "startup settings path selection must honor XDG_CONFIG_HOME");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Safe_Environment_Value (""USERPROFILE"")",
         "startup home-directory selection must safely honor USERPROFILE");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Safe_Environment_Value (""HOMEDRIVE"")",
         "startup home-directory selection must safely honor HOMEDRIVE");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Safe_Environment_Value (""HOMEPATH"")",
         "startup home-directory selection must safely honor HOMEPATH");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Safe_Environment_Value (""HOMESHARE"")",
         "startup home-directory selection must safely honor HOMESHARE");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Home_Drive & Home_Path",
         "startup home-directory selection must compose Windows drive and profile path");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "function Existing_Directory (Path : String) return Boolean is",
         "startup home-directory selection must validate environment directory candidates");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "and then Ada.Directories.Kind (Path) = Ada.Directories.Directory",
         "startup home-directory selection must reject non-directory environment paths");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "if Candidates.Is_Empty then",
         "startup path resolution must add the home directory when no paths are provided");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Candidates.Append (To_Unbounded_String (Home));",
         "startup path resolution must use the current user's home directory by default");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Path_Check : constant Files.File_System.Path_Result := Files.File_System.Normalize_Path (Input);",
         "startup path resolution must normalize every command-line path through the filesystem layer");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "if not Already_Has_Window (Directory_Path) then",
         "startup path resolution must collapse duplicate normalized directory windows");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Result.Errors.Append",
         "startup path resolution must report invalid paths as recoverable diagnostics");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "return" & ASCII.LF
         & "              (Status         => Path_Valid,",
         "filesystem path normalization must return valid directory results");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Directory_Path =>" & ASCII.LF
         & "                 To_Unbounded_String (Ada.Directories.Containing_Directory",
         "filesystem path normalization must convert file paths to their parent directory");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Error_Key      => To_Unbounded_String (""error.path.missing"")",
         "filesystem path normalization must report missing paths with a localized error key");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "when Ada.Directories.Special_File =>",
         "filesystem path normalization must handle special files explicitly");
      Project_Tools.Files.Require_Contains
        (File_System_Body,
         "Error_Key      => To_Unbounded_String (""error.path.inaccessible"")",
         "filesystem path normalization must report inaccessible paths with a localized error key");
      Project_Tools.Files.Require_Contains
        (Tests,
         "file maps to parent",
         "startup path tests must cover file arguments mapping to parent directories");
      Project_Tools.Files.Require_Contains
        (Tests,
         "current-directory path normalizes to absolute directory",
         "startup path tests must cover current-directory relative path normalization");
      Project_Tools.Files.Require_Contains
        (Tests,
         "distinct normalized paths produce one window each",
         "startup path tests must cover separate windows for distinct directories");
      Project_Tools.Files.Require_Contains
        (Tests,
         "startup opens a separate window for a distinct normalized directory",
         "startup path tests must cover distinct normalized directory paths");
      Project_Tools.Files.Require_Contains
        (Tests,
         "missing path is reported without a window",
         "startup path tests must cover invalid paths as diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "special path reports inaccessible",
         "startup path tests must cover special-file path normalization");
      Project_Tools.Files.Require_Contains
        (Tests,
         "special startup path opens no window",
         "startup path tests must cover special-file startup rejection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "special startup diagnostic records inaccessible error key",
         "startup path tests must cover special-file startup diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "no args resolves one path",
         "startup path tests must cover default home-directory selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "USERPROFILE is used when HOME is empty",
         "startup path tests must cover USERPROFILE home fallback");
      Project_Tools.Files.Require_Contains
        (Tests,
         "invalid HOME falls back to valid USERPROFILE",
         "startup path tests must cover invalid HOME fallback to USERPROFILE");
      Project_Tools.Files.Require_Contains
        (Tests,
         "HOMEDRIVE and HOMEPATH are used when USERPROFILE is invalid",
         "startup path tests must cover Windows drive/profile home fallback");
      Project_Tools.Files.Require_Contains
        (Tests,
         "HOMESHARE is used when drive profile is invalid",
         "startup path tests must cover Windows share home fallback");
      Project_Tools.Files.Require_Contains
        (Tests,
         "invalid home environment falls back to current directory",
         "startup path tests must cover invalid home environment fallback");
      Project_Tools.Files.Require_Contains
        (Tests,
         "no args opens current directory after invalid home environment",
         "startup path tests must cover no-argument startup after invalid home environment fallback");
      Project_Tools.Files.Require_Contains
        (Tests,
         "default settings path is under home config directory",
         "startup tests must cover default settings path construction");
      Project_Tools.Files.Require_Contains
        (Tests,
         "XDG_CONFIG_HOME selects the XDG settings path",
         "startup tests must cover XDG settings path selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "FILES_SETTINGS overrides the XDG settings path",
         "startup tests must cover explicit settings path environment override");
      Project_Tools.Files.Require_Contains
        (Tests,
         "startup result records loaded settings path",
         "startup tests must cover effective loaded settings path reporting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "startup result exposes loaded default view",
         "startup tests must cover loaded settings view-mode propagation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "startup result exposes loaded hidden-file setting",
         "startup tests must cover loaded hidden-file settings propagation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "hidden-file setting affects startup load",
         "startup tests must cover settings-driven directory loading");
      Project_Tools.Files.Require_Contains
        (Tests,
         "startup windows with Unicode and fallback filenames pass headless render smoke test",
         "startup tests must cover Unicode and fallback filename headless render smoke on resolved windows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "startup creates missing default settings file",
         "startup tests must cover missing default settings creation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "startup result exposes created default settings",
         "startup tests must cover created default settings propagation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "invalid settings do not block valid paths",
         "startup tests must cover valid window creation after settings parse failure");
      Project_Tools.Files.Require_Contains
        (Tests,
         "invalid settings leave startup result on default settings",
         "startup tests must cover default settings fallback after parse failure");
      Project_Tools.Files.Require_Contains
        (Tests,
         "invalid settings do not leak partially parsed hidden-file setting",
         "startup tests must cover atomic settings fallback after parse failure");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings diagnostic records the settings path",
         "startup tests must cover settings parse diagnostic path reporting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings directory diagnostic records the settings path",
         "startup tests must cover settings directory diagnostic path reporting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "window title is the normalized current directory path",
         "startup path tests must cover normalized window titles");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Files.Localization.Text (""startup.window.ready"") & "": "" & Ada.Directories.Full_Name (Dir)",
         "startup report settings tests must use localized window labels");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Files.Localization.Text (""startup.error"") & "": "" &",
         "startup report settings tests must use localized error labels");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Files.Localization.Text (""error.settings.invalid_boolean"")",
         "startup report settings tests must use localized settings diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Files.Localization.Text (""error.settings.not_file"")",
         "startup settings-directory report tests must use localized diagnostics");
      Require_Not_Contains
        (Tests,
         """Error: "" & Settings_Path",
         "startup report tests must not hard-code English error labels");
   end Check_Startup_Path_Contract;

   procedure Check_Application_CLI_Surface is
      Application_Spec : constant String := Root & "/src/files-application.ads";
      Application_Body : constant String := Root & "/src/files-application.adb";
      Tests            : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Application_Spec,
         "type Run_Mode is",
         "application CLI surface must expose a parsed run mode");
      Project_Tools.Files.Require_Contains
        (Application_Spec,
         "function Parse_Run_Configuration",
         "application CLI surface must keep argument parsing testable");
      Project_Tools.Files.Require_Contains
        (Application_Spec,
         "function Help_Text",
         "application CLI surface must expose localized help text");
      Project_Tools.Files.Require_Contains
        (Application_Spec,
         "function Version_Text",
         "application CLI surface must expose version text");
      Project_Tools.Files.Require_Contains
        (Application_Spec,
         "Run the application entry point using process command-line arguments.",
         "application CLI surface must document the command-line entry point");
      Project_Tools.Files.Require_Contains
        (Application_Spec,
         "Settings_Path : UString;",
         "application CLI surface must expose explicit settings path selection");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         """--runtime-smoke""",
         "files executable must expose the headless runtime smoke mode");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         """--live-smoke""",
         "files executable must expose the live-window runtime smoke mode");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         """--help""",
         "files executable must expose long help");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         """--version""",
         "files executable must expose version reporting");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         """-h""",
         "files executable must expose short help");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         """--settings""",
         "files executable must expose explicit settings file selection");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         """--settings=""",
         "files executable must expose settings equals-form selection");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "elsif Parse_Flags and then Value = ""--"" then",
         "CLI parsing must stop option parsing at the standard terminator");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Need_Settings_Path := True;",
         "CLI parsing must require the next argument for separated settings paths");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Result.Paths.Append (To_Unbounded_String (""--settings""));",
         "CLI parsing must preserve a missing settings-path flag as a startup path");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Result.Settings_Path := To_Unbounded_String (Value (Value'First + 11 .. Value'Last));",
         "CLI parsing must preserve inline settings-path values");
      Project_Tools.Files.Require_Contains
        (Tests,
         "split settings flag drives startup settings path",
         "CLI tests must cover separated settings path integration with startup resolution");
      Project_Tools.Files.Require_Contains
        (Tests,
         "split settings flag affects startup directory loading",
         "CLI tests must cover separated settings paths affecting startup directory loading");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Files.Localization.Text (""cli.help.usage"", Locale)",
         "CLI help usage text must be loaded through localization");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Files.Localization.Text (""cli.help.option.help"", Locale)",
         "CLI help option text must be loaded through localization");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Files.Localization.Text (""cli.help.option.version"", Locale)",
         "CLI version option text must be loaded through localization");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "return Files_Config.Crate_Name & "" "" & Files_Config.Crate_Version;",
         "version text must come from generated crate metadata");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Runtime_Smoke_Report (Result)",
         "headless smoke mode must route through the runtime smoke report");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Files.Rendering.Build_Snapshot (Window.Model, Result.Settings);",
         "runtime smoke report must build immutable snapshots from startup window models");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Files.Rendering.Build_Frame_Commands",
         "runtime smoke report must build backend-neutral frame commands");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Files.Rendering.Build_Text_Glyphs (Text_Renderer, Frame);",
         "runtime smoke report must exercise text glyph construction");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Glyphs.Status /= Files.Rendering.Text_Render_Success",
         "runtime smoke report must fail when glyph construction fails");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Glyphs.Glyphs.Is_Empty",
         "runtime smoke report must fail when text rendering emits no glyphs");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "runtime.smoke.missing_glyphs",
         "runtime smoke report must include missing-glyph fallback diagnostics");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "runtime.smoke.font",
         "runtime smoke report must include selected text font diagnostics");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Files.Application.Windows.Headless_Render_Quality_Report",
         "runtime smoke report must include headless render quality diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "runtime smoke report exposes headless render quality status",
         "runtime smoke tests must cover headless render quality diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "runtime smoke reports zero-glyph text batches as failures",
         "runtime smoke tests must cover zero-glyph text batch failures");
      Project_Tools.Files.Require_Contains
        (Tests,
         "main-section UTF-8 item names emit Unicode glyphs in every view mode",
         "text rendering tests must cover UTF-8 item names across all main view modes");
      Project_Tools.Files.Require_Contains
        (Tests,
         "main-section UTF-8 item name glyphs reach Vulkan submission",
         "text rendering tests must cover UTF-8 item glyph handoff to Vulkan submission");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering.adb",
         "Unit_Width := Files.UTF8.Display_Units (Content (Unit_Start .. Index - 1));",
         "text glyph rendering must advance by UTF-8 display cells");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering.adb",
         "if Unit_Width = 0 then Base_X",
         "text glyph rendering must place zero-width combining glyphs on the base cell");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering.adb",
         "(if Unit_Width = 0 then Base_X else Cell_X)",
         "text glyph rendering must anchor visible glyphs at their reserved display-cell origin");
      Require_Not_Contains
        (Root & "/src/files-rendering.adb",
         "Unit_Width - 1",
         "text glyph rendering must not half-shift wide Unicode filename glyphs");
      Project_Tools.Files.Require_Contains
        (Tests,
         "text renderer advances after CJK glyphs by wide display cells",
         "text rendering tests must cover wide-glyph advancement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "text renderer anchors CJK glyphs at the reserved wide-cell origin",
         "text rendering tests must cover wide-glyph placement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "text renderer places combining marks on the previous base cell",
         "text rendering tests must cover zero-width combining glyph placement");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering.adb",
         "Result.Atlas_Bytes := Saturating_Multiply (Renderer.Atlas_Width, Renderer.Atlas_Height);",
         "text renderer atlas byte metadata must avoid size multiplication overflow");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Files.Rendering.Vulkan.Build_Submission (Frame, Glyphs);",
         "runtime smoke report must exercise Vulkan submission batching");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Append_Line (Files.Localization.Text (""runtime.smoke.no_windows"", Locale));",
         "runtime smoke report must localize empty-startup diagnostics");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Run_Live_Window_Smoke (Result, Plan)",
         "live smoke mode must route through the live window smoke runner");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Resolve_Startup (Config.Paths, To_String (Config.Settings_Path))",
         "runtime startup must use the parsed explicit settings path");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Config.Mode = Help_Run",
         "help mode must return before startup path resolution");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Config.Mode = Version_Run",
         "version mode must return before startup path resolution");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Test_Run_Configuration_Parsing",
         "runtime CLI parsing must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "runtime smoke flag selects headless smoke mode",
         "runtime CLI tests must cover headless smoke flag parsing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings flag consumes dash-prefixed following path",
         "runtime CLI tests must cover dash-prefixed separated settings path parsing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings path consumption resumes flag parsing after the value",
         "runtime CLI tests must cover flag parsing after separated settings values");
      Project_Tools.Files.Require_Contains
        (Tests,
         "later run mode flag wins deterministically",
         "runtime CLI tests must cover deterministic repeated mode flags");
      Project_Tools.Files.Require_Contains
        (Tests,
         "version flag selects version mode",
         "runtime CLI tests must cover version flag parsing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "version text uses generated crate metadata",
         "runtime CLI tests must cover generated version text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "unknown option is treated as a path",
         "runtime CLI tests must cover unknown dash-prefixed paths");
      Project_Tools.Files.Require_Contains
        (Tests,
         "terminator keeps settings-looking path text",
         "runtime CLI tests must cover option terminator preserving path text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "terminator keeps bare settings flag as path text",
         "runtime CLI tests must cover option terminator preserving bare settings flags");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings flag can consume terminator as a path",
         "runtime CLI tests must cover separated settings values that look like option terminators");
      Project_Tools.Files.Require_Contains
        (Tests,
         "flag parsing resumes after terminator setting path",
         "runtime CLI tests must cover flag parsing after terminator-looking settings values");
      Project_Tools.Files.Require_Contains
        (Tests,
         "missing settings value is not dropped",
         "runtime CLI tests must cover incomplete separated settings flags");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty settings equals form leaves default settings path",
         "runtime CLI tests must cover empty inline settings paths");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Help_Text",
         "runtime CLI help text must remain covered by AUnit");
      Project_Tools.Files.Require_Contains
        (Root & "/share/files.catalog",
         "en.cli.help.option.version = ",
         "localized catalog must include version help text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "runtime smoke report uses localized empty-startup diagnostic",
         "runtime smoke tests must cover empty-startup diagnostics");
   end Check_Application_CLI_Surface;

   procedure Check_Executable_CLI_Help is
   begin
      Run_And_Require_Output
        (Label   => "files long help",
         Dir             => Root,
         Program         => "./bin/files",
         Args            => [1 => new String'("--help")],
         Output_Path     => "/tmp/files-check-help-long.txt",
         Required_First  => "Usage: files",
         Required_Second => "--settings PATH");
      Run_And_Require_Output
        (Label   => "files short help",
         Dir             => Root,
         Program         => "./bin/files",
         Args            => [1 => new String'("-h")],
         Output_Path     => "/tmp/files-check-help-short.txt",
         Required_First  => "Usage: files",
         Required_Second => "--help, -h");
      Run_And_Require_Output
        (Label   => "files version",
         Dir             => Root,
         Program         => "./bin/files",
         Args            => [1 => new String'("--version")],
         Output_Path     => "/tmp/files-check-version.txt",
         Required_First  => "files ",
         Required_Second => "0.1.0-dev");
   end Check_Executable_CLI_Help;

   procedure Check_Desktop_Runtime_Contract is
      Windows_Body : constant String := Root & "/src/files-application-windows.adb";
      Tests        : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "function Headless_Smoke_Test",
         "desktop runtime must expose a headless smoke validation path");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Files.Rendering.Build_Snapshot (Startup_Window.Model, Startup.Settings);",
         "headless smoke must construct immutable render snapshots from startup windows");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Files.Rendering.Build_Frame_Commands",
         "headless smoke must exercise backend-neutral frame command construction");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Frame.Rectangles.Is_Empty",
         "headless smoke must reject empty rendered frames");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Text_Status /= Files.Rendering.Text_Render_Success",
         "headless smoke must reject failed text renderer initialization");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Font_Path   => Files.Rendering.Font_Path_For_Frame (Frame)",
         "headless smoke must initialize text rendering with a frame-specific font");
      Require_Not_Contains
        (Windows_Body,
         "Glyphs.Missing_Glyph_Count /= 0",
         "headless smoke must not reject otherwise visible frames solely for missing-glyph fallback");
      Project_Tools.Files.Require_Contains
        (Tests,
         "startup windows with Unicode and fallback filenames pass headless render smoke test",
         "startup tests must cover headless smoke with degraded but visible filename glyphs");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Text_Font_Path  : Unbounded_String;",
         "live window runtime must remember the currently loaded text font");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Process_Text_Font_Path  : Unbounded_String;",
         "live window runtime must track textrender's process-global font path");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Current_Text_Key : constant Unbounded_String := Frame_Text_Key (Frame);",
         "live rendering must key font resolution by frame text content");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Frame_Font_Path := Runtime.Text_Content_Font_Path;",
         "live rendering must reuse cached frame font paths while text is unchanged");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Process_Text_Font_Path /= Frame_Font_Path",
         "live rendering must reload when another window changed the process-global text font");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Process_Text_Font_Path := Null_Unbounded_String;",
         "live rendering must clear process-global text font tracking when windows are released");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Set_Raw_Window_Hint (GLFW_Client_API, GLFW_No_API);",
         "desktop runtime must create Vulkan windows with GLFW_NO_API");
      Require_Not_Contains
        (Windows_Body,
         "Glfw.Windows.Context.Make_Current",
         "desktop Vulkan runtime must not make an OpenGL context current");
      Require_Not_Contains
        (Windows_Body,
         "Glfw.Windows.Context.Swap_Buffers",
         "desktop Vulkan runtime must not swap OpenGL buffers");
      Require_Not_Contains
        (Windows_Body,
         "Glfw.Windows.Context.Set_Swap_Interval",
         "desktop Vulkan runtime must not configure OpenGL swap interval");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "function Runtime_Capabilities return Desktop_Capabilities",
         "desktop runtime must expose observable capability metadata");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-application-windows.ads",
         "Native_Drop_Callbacks",
         "desktop runtime must advertise native file-drop callback support");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-application-windows.ads",
         "Native_Drop_Automation",
         "desktop runtime must advertise drop event-source automation");
      Project_Tools.Files.Require_Contains
        (Combined_Suite,
         "runtime capabilities expose drop event-source automation",
         "desktop runtime tests must cover drop event-source automation");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-application-windows.ads",
         "type Native_Drag_Automation_Profile is record",
         "desktop runtime must expose structured native drag automation metadata");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "function Native_Drag_Automation_Profile_Of_Current_Runtime",
         "desktop runtime must report native drag automation backend metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "drag automation profile exposes an Ada event-source backend",
         "desktop runtime tests must cover drop event-source backend metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "drag automation profile supports queued drop imports",
         "desktop runtime tests must cover queued drop-import metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "drop event source filters empty paths",
         "desktop runtime tests must cover drop event-source filtering");
      Project_Tools.Files.Require_Contains
        (Tests,
         "drop event source clears after drain",
         "desktop runtime tests must cover drop event-source draining");
      Project_Tools.Files.Require_Contains
        (Tests,
         "desktop capability report exposes drop event-source automation",
         "desktop capability policy tests must expose drop event-source automation status");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering-vulkan.ads",
         "Live framebuffer",
         "Vulkan readback API comments must distinguish live readback from headless comparison");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-application-windows.ads",
         "Directory_Watch_Polling",
         "desktop runtime must advertise directory watch polling support");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-application-windows.ads",
         "Native_File_Watching",
         "desktop runtime must advertise native file watching support");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "function Safe_Environment_Value (Name : String) return String",
         "desktop display detection must read environment variables through a guarded helper");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Display         : constant String := Safe_Environment_Value (""DISPLAY"");",
         "desktop display detection must guard DISPLAY access");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Wayland_Display : constant String := Safe_Environment_Value (""WAYLAND_DISPLAY"");",
         "desktop display detection must guard WAYLAND_DISPLAY access");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Comspec         : constant String := Safe_Environment_Value (""COMSPEC"");",
         "desktop display detection must guard COMSPEC access");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Live_Window_Smoke_Ready => Display and then Vulkan",
         "live smoke readiness must require both display and Vulkan support");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Headless_Rendering      => True",
         "runtime capabilities must advertise headless rendering support");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Event_Translation_Model => True",
         "runtime capabilities must advertise event translation support");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Scroll_Runtime_Model    => True",
         "runtime capabilities must advertise scroll runtime support");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "function Accumulate_Scroll_Offset",
         "desktop runtime must accumulate fractional GLFW scroll offsets");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Remainder := Total - Long_Float (Whole);",
         "desktop runtime must preserve fractional scroll remainder after whole-line emission");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "function Add_Pending_Scroll",
         "desktop runtime must saturate queued scroll line accumulation");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "function Scale_Coordinate",
         "desktop runtime must expose testable coordinate scaling");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Value <= 0.0 or else Source = 0 or else Target = 0",
         "desktop coordinate scaling must reject zero dimensions");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "if not Files.Commands.Is_Enabled (Command, Runtime.Model) then",
         "runtime settings command execution must not bypass disabled command diagnostics");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Files.Controller.Execute_Command" & ASCII.LF
         & "             (Command, Runtime.Model, Runtime.Settings, Modifiers);",
         "disabled runtime commands must be delegated back through the controller");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "function Live_Window_Smoke_Plan",
         "desktop runtime must expose a deterministic live-smoke plan");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Frame_Count      => 2",
         "live-smoke plan must render enough frames for framebuffer readback");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Input_Poll_Count => 1",
         "live-smoke plan must keep bounded input polling by default");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "elsif not Caps.Vulkan_Available then ""runtime.smoke.no_vulkan""",
         "live-smoke plan must report missing Vulkan with a localized key");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "function Evaluate_Live_Window_Smoke",
         "desktop runtime must evaluate live-smoke plans without opening windows");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Skipped_By_Plan    => True",
         "live-smoke evaluation must preserve skipped-by-plan state");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Error_Key          => Plan.Reason_Key",
         "live-smoke evaluation must report the plan reason key when skipped");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "if not Plan.Can_Run or else Startup.Windows.Is_Empty then",
         "live-smoke runner must avoid opening windows for skipped or empty plans");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Result.Error_Key := To_Unbounded_String (""runtime.smoke.no_windows"");",
         "live-smoke runner must report empty startup without creating windows");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "function Any_Runtime_Frame_Rendered",
         "live smoke must derive rendered-frame status from runtime window diagnostics");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Runtime.Last_Present_Status = Files.Rendering.Vulkan.Vulkan_Presented",
         "live smoke must require a successfully presented Vulkan frame");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Runtime.Last_Glyph_Count > 0",
         "live smoke must require visible text glyphs");
      Require_Not_Contains
        (Windows_Body,
         "Runtime.Last_Missing_Glyph_Count = 0",
         "live smoke must not reject otherwise visible frames solely for missing-glyph fallback");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Release_All (Runtime_Windows);",
         "live desktop runtime must release windows on success and failure paths");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Glfw.Shutdown;",
         "live desktop runtime must shut down GLFW after bounded live smoke runs");
      Project_Tools.Files.Require_Contains
        (Tests,
         "runtime smoke report uses localized window label",
         "desktop runtime tests must cover headless runtime smoke reporting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "runtime smoke report uses localized vertex-count label",
         "desktop runtime tests must cover smoke render command output");
      Project_Tools.Files.Require_Contains
        (Tests,
         "runtime capabilities advertise headless rendering",
         "desktop runtime tests must cover headless capability reporting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "runtime capabilities gate live window smoke on display and Vulkan",
         "desktop runtime tests must cover live-smoke readiness gating");
      Project_Tools.Files.Require_Contains
        (Tests,
         "runtime capabilities expose event translation model",
         "desktop runtime tests must cover event-translation capability reporting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "runtime capabilities expose focus model",
         "desktop runtime tests must cover focus-runtime capability reporting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "runtime capabilities expose resize model",
         "desktop runtime tests must cover resize-runtime capability reporting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "runtime capabilities expose scroll model",
         "desktop runtime tests must cover scroll-runtime capability metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "fractional scroll emits a whole line after accumulation",
         "desktop runtime tests must cover fractional scroll accumulation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "opposite fractional scroll can cancel without a line",
         "desktop runtime tests must cover mixed-sign fractional scroll accumulation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "scroll accumulation saturates large positive offsets",
         "desktop runtime tests must cover saturated scroll offset accumulation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "pending scroll addition saturates positive overflow",
         "desktop runtime tests must cover pending scroll positive saturation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "pending scroll addition saturates negative overflow",
         "desktop runtime tests must cover pending scroll negative saturation");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "function Text_Input_Bytes",
         "desktop runtime must expose deterministic text-input byte encoding");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "or else (Code >= 16#D800# and then Code <= 16#DFFF#)",
         "desktop runtime text-input encoding must reject surrogate code points");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Byte (16#F0# + Code / 16#40000#)",
         "desktop runtime text-input encoding must support four-byte UTF-8");
      Project_Tools.Files.Require_Contains
        (Tests,
         "desktop text input encodes two-byte UTF-8",
         "desktop runtime tests must cover two-byte UTF-8 text input");
      Project_Tools.Files.Require_Contains
        (Tests,
         "desktop text input encodes four-byte UTF-8",
         "desktop runtime tests must cover four-byte UTF-8 text input");
      Project_Tools.Files.Require_Contains
        (Tests,
         "desktop text input ignores surrogate code points",
         "desktop runtime tests must cover invalid Unicode text input");
      Project_Tools.Files.Require_Contains
        (Tests,
         "runtime coordinate scaling maps proportional positions",
         "desktop runtime tests must cover coordinate scaling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "runtime coordinate scaling rejects zero target dimensions",
         "desktop runtime tests must cover invalid target dimension scaling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "control+s reports settings save command execution for runtime persistence",
         "desktop runtime tests must cover settings save path handoff");
      Project_Tools.Files.Require_Contains
        (Tests,
         "live smoke plan records two frames for readback validation",
         "desktop runtime tests must cover live-smoke readback frame count");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-application-windows.ads",
         "Frames_Attempted   : Natural := 0;",
         "live-smoke result must expose attempted frame accounting");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-application-windows.ads",
         "Frames_Presented   : Natural := 0;",
         "live-smoke result must expose presented frame accounting");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Result.Frames_Attempted := Result.Frames_Attempted + 1;",
         "live-smoke runner must count attempted frames");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Result.Frames_Presented := Result.Frames_Presented + 1;",
         "live-smoke runner must count presented frames");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-application.adb",
         "runtime.smoke.frames_attempted",
         "live-smoke CLI must print attempted frame count");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-application.adb",
         "runtime.smoke.frames_presented",
         "live-smoke CLI must print presented frame count");
      Project_Tools.Files.Require_Contains
        (Tests,
         "live smoke preflight reports zero attempted frames",
         "desktop runtime tests must cover preflight frame counters");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty live smoke startup reports zero attempted frames",
         "desktop runtime tests must cover empty live-smoke frame counters");
      Project_Tools.Files.Require_Contains
        (Tests,
         "skipped live smoke startup reports zero attempted frames",
         "desktop runtime tests must cover skipped live-smoke frame counters");
      Project_Tools.Files.Require_Contains
        (Tests,
         "live smoke plan records requested width",
         "desktop runtime tests must cover live-smoke requested width");
      Project_Tools.Files.Require_Contains
        (Tests,
         "live smoke plan records requested height",
         "desktop runtime tests must cover live-smoke requested height");
      Project_Tools.Files.Require_Contains
        (Tests,
         "live smoke plan records deterministic input poll count",
         "desktop runtime tests must cover bounded live-smoke input polling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "live smoke plan readiness matches runtime capabilities",
         "desktop runtime tests must cover live-smoke readiness calculation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "live smoke plan exposes localized reason key",
         "desktop runtime tests must cover live-smoke localized reason keys");
      Project_Tools.Files.Require_Contains
        (Tests,
         "headless live smoke evaluation does not create a window",
         "desktop runtime tests must cover non-invasive live-smoke evaluation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "live smoke result records whether the plan skipped execution",
         "desktop runtime tests must cover live-smoke skipped-result metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "live smoke result exposes status key",
         "desktop runtime tests must cover live-smoke result status keys");
      Project_Tools.Files.Require_Contains
        (Tests,
         "live smoke runner reports empty startup",
         "desktop runtime tests must cover empty live-smoke startup handling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "live smoke runner skips when plan cannot run",
         "desktop runtime tests must cover skipped live-smoke plans");
      Project_Tools.Files.Require_Contains
        (Tests,
         "live smoke runner does not attempt skipped plan",
         "desktop runtime tests must cover non-attempted skipped live-smoke plans");
   end Check_Desktop_Runtime_Contract;

   procedure Check_Rendering_Architecture is
      Rendering_Body : constant String := Root & "/src/files-rendering.adb";
      Rendering_Spec : constant String := Root & "/src/files-rendering.ads";
      Fonts_Body     : constant String := Root & "/src/files-fonts.adb";
      Fonts_Spec     : constant String := Root & "/src/files-fonts.ads";
      Application_Body : constant String := Root & "/src/files-application.adb";
      Windows_Body   : constant String := Root & "/src/files-application-windows.adb";
      Vulkan_Body    : constant String := Root & "/src/files-rendering-vulkan.adb";
      Vulkan_Spec    : constant String := Root & "/src/files-rendering-vulkan.ads";
      Tests          : constant String := Combined_Suite;

      procedure Check_Rendering_Unit
        (Path  : String;
         Label : String) is
      begin
         Require_Not_Contains
           (Path,
            "with Ada.Directories;",
            Label & " must not import Ada.Directories for filesystem access");
         Require_Not_Contains
           (Path,
            "Ada.Directories.",
            Label & " must not perform filesystem access");
         Require_Not_Contains
           (Path,
            "Files.Operations.",
            Label & " must not execute operations");
         Require_Not_Contains
           (Path,
            "with Files.Operations;",
            Label & " must not import operations");
         Require_Not_Contains
           (Path,
            "Files.Controller.",
            Label & " must not route controller actions");
         Require_Not_Contains
           (Path,
            "with Files.Controller;",
            Label & " must not import the controller");
         Require_Not_Contains
           (Path,
            "Files.Application.",
            Label & " must not call application startup logic");
         Require_Not_Contains
           (Path,
            "with Files.Application;",
            Label & " must not import application startup logic");
         Require_Not_Contains
           (Path,
            "Files.Commands.Execute",
            Label & " must not dispatch commands");
         Require_Not_Contains
           (Path,
            "Files.Commands.Execute_If_Enabled",
            Label & " must not dispatch commands");
         Require_Not_Contains
           (Path,
            "Files.Commands.Execute (",
            Label & " must not execute command handlers");
         Require_Not_Contains
           (Path,
            "Files.Commands.Find_By_Shortcut",
            Label & " must not translate input shortcuts");
         Require_Not_Contains
           (Path,
            "with GNAT.OS_Lib;",
            Label & " must not import OS process bindings");
         Require_Not_Contains
           (Path,
            "GNAT.OS_Lib.",
            Label & " must not call OS process bindings");
         Require_Not_Contains
           (Path,
            "GNAT.Expect.",
            Label & " must not call process interaction bindings");
         Require_Not_Contains
           (Path,
            "Create_Process",
            Label & " must not create external processes");
         Require_Not_Contains
           (Path,
            "Spawn",
            Label & " must not spawn external processes");
         Require_Not_Contains
           (Path,
            "Files.Settings.Add_Extension_Mapping",
            Label & " must not mutate settings extension mappings");
         Require_Not_Contains
           (Path,
            "Files.Settings.Add_Icon_Mapping",
            Label & " must not mutate settings icon mappings");
         Require_Not_Contains
           (Path,
            "Files.Settings.Add_Open_Action",
            Label & " must not mutate settings open-action mappings");
         Require_Not_Contains
           (Path,
            "Files.Settings.Apply_Draft",
            Label & " must not apply settings drafts");
         Require_Not_Contains
           (Path,
            "Files.Settings.Save_Draft",
            Label & " must not save settings drafts");
         Require_Not_Contains
           (Path,
            "Files.Settings.Ensure_Default_File",
            Label & " must not create settings files");
         Require_Not_Contains
           (Path,
            "Files.Settings.Save_Text",
            Label & " must not write settings text");
         Require_Not_Contains
           (Path,
            "Files.Settings.Load_File",
            Label & " must not load settings files");
         Require_Not_Contains
           (Path,
            "Files.File_System.Create_Empty_File",
            Label & " must not invoke filesystem mutations");
         Require_Not_Contains
           (Path,
            "Files.File_System.Load_Directory",
            Label & " must not load directories");
         Require_Not_Contains
           (Path,
            "Files.File_System.Normalize_Path",
            Label & " must not validate or normalize paths");
         Require_Not_Contains
           (Path,
            "Files.File_System.Resolve_Startup",
            Label & " must not resolve startup paths");
         Require_Not_Contains
           (Path,
            "Files.File_System.Rename_Item",
            Label & " must not invoke filesystem mutations");
         Require_Not_Contains
           (Path,
            "Files.File_System.Move_To_Trash",
            Label & " must not invoke filesystem mutations");
         Require_Not_Contains
           (Path,
            "Files.Model.Set_",
            Label & " must not mutate model state");
         Require_Not_Contains
           (Path,
            "Files.Model.Add_",
            Label & " must not mutate model state");
         Require_Not_Contains
           (Path,
            "Files.Model.Begin_",
            Label & " must not mutate model state");
         Require_Not_Contains
           (Path,
            "Files.Model.Cancel_",
            Label & " must not mutate model state");
         Require_Not_Contains
           (Path,
            "Files.Model.Clear_",
            Label & " must not mutate model state");
         Require_Not_Contains
           (Path,
            "Files.Model.Close_",
            Label & " must not mutate model state");
         Require_Not_Contains
           (Path,
            "Files.Model.Focus_",
            Label & " must not mutate focus state");
         Require_Not_Contains
           (Path,
            "Files.Model.Go_",
            Label & " must not mutate path history");
         Require_Not_Contains
           (Path,
            "Files.Model.Navigate_",
            Label & " must not mutate path history");
         Require_Not_Contains
           (Path,
            "Files.Model.Open_",
            Label & " must not mutate model state");
         Require_Not_Contains
           (Path,
            "Files.Model.Remove_",
            Label & " must not mutate model state");
         Require_Not_Contains
           (Path,
            "Files.Model.Replace_",
            Label & " must not mutate model state");
         Require_Not_Contains
           (Path,
            "Files.Model.Resume_",
            Label & " must not mutate rename state");
         Require_Not_Contains
           (Path,
            "Files.Model.Scroll_",
            Label & " must not mutate scroll state");
         Require_Not_Contains
           (Path,
            "Files.Model.Select_",
            Label & " must not mutate selection state");
         Require_Not_Contains
           (Path,
            "Files.Model.Move_Selection",
            Label & " must not mutate selection state");
         Require_Not_Contains
           (Path,
            "Files.Model.Toggle_",
            Label & " must not mutate model state");
      end Check_Rendering_Unit;
   begin
      Check_Rendering_Unit (Rendering_Spec, "rendering spec");
      Check_Rendering_Unit (Rendering_Body, "rendering body");
      Check_Rendering_Unit (Vulkan_Spec, "Vulkan rendering spec");
      Check_Rendering_Unit (Vulkan_Body, "Vulkan rendering body");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "Thumbnail_Pixels : Files.Types.Byte_Vectors.Vector;",
         "render snapshots must carry cached thumbnail pixels immutably");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Thumbnail_Pixels    => Item.Thumbnail_Pixels",
         "snapshot construction must copy cached thumbnail pixels from the model");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "if Use_Thumbnail then Item.Thumbnail_Pixels else Files.Types.Byte_Vectors.Empty_Vector",
         "frame command construction must pass cached thumbnail pixels only when thumbnails are enabled");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "function Rasterize_Thumbnail return Boolean",
         "Vulkan icon atlas construction must rasterize cached thumbnail pixels");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Icon.Thumbnail_Pixels.Element (Offset + 1)",
         "Vulkan thumbnail rasterization must consume thumbnail pixel data");
      Project_Tools.Files.Require_Contains
        (Fonts_Spec,
         "function Default_Font_Path return String;",
         "font discovery spec must expose default font path lookup");
      Project_Tools.Files.Require_Contains
        (Fonts_Spec,
         "available font file best suited for broad filename text",
         "font discovery spec must not claim only TrueType font files are supported");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "function Is_Ordinary_File",
         "font discovery must centralize candidate file validation");
      Require_Not_Contains
        (Fonts_Body,
         "or else Has_Suffix (Lower, "".ttc"")",
         "font discovery must not select TTC collections that the text renderer cannot initialize");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "Ada.Directories.Exists (Path)",
         "font discovery must probe candidate font files outside the renderer");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "Ada.Directories.Kind (Path) = Ada.Directories.Ordinary_File",
         "font discovery must reject non-file font candidates");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "Safe_Environment_Value (""FILES_FONT_PATH"")",
         "font discovery must safely honor FILES_FONT_PATH overrides");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "function Is_Loadable_Font",
         "font discovery must centralize supported font validation");
      Require_Not_Contains
        (Fonts_Body,
         "Textrender.Reset",
         "font discovery must not reset process-global text renderer state");
      Require_Not_Contains
        (Fonts_Body,
         "Textrender.Load_Font",
         "font discovery must not load fonts through the live text renderer");
      Require_Not_Contains
        (Fonts_Body,
         "Textrender.Get_Glyph",
         "font discovery must not probe glyphs through the live text renderer");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "if Is_Loadable_Font (Override_Path) then",
         "font discovery must validate FILES_FONT_PATH as a loadable font");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "and then not Is_Known_Unsupported_Renderer_Font (To_String (Path))",
         "font discovery must filter fixed candidates through renderer-supported font extensions");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "function Is_Known_Unsupported_Renderer_Font",
         "font discovery must blacklist font files known to fail renderer batching");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "droidsansfallbackfull.ttf",
         "font discovery must reject Droid fallback when it fails renderer batching");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "notocoloremoji.ttf",
         "font discovery must reject color emoji fonts that do not produce filename glyph geometry");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "unifont.ttf",
         "font discovery must reject Unifont when it fails renderer initialization");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "NotoSansCJK-Regular.ttc",
         "font discovery must probe common Noto CJK filename fonts");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "procedure Scan_Font_Directory",
         "font discovery must scan common system font directories for Unicode filename coverage");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "Max_Discovered_Fonts",
         "font discovery directory scanning must remain bounded");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "procedure Sort_Paths",
         "font discovery must sort recursively discovered paths for deterministic fallback selection");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "Scan_Font_Directory (Discovered, To_String (Root), 0);",
         "font discovery must keep scanned paths separate from fixed priority candidates");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "Is_Font_File (Full)",
         "font discovery directory scanning must filter supported font file extensions");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "PingFang.ttc",
         "font discovery must probe common macOS Unicode filename fonts");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "C:\Windows\Fonts\segoeui.ttf",
         "font discovery must probe common Windows Unicode filename fonts");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "function Glyph_Coverage_Score",
         "font discovery must score candidate fonts by direct glyph coverage");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "Textrender.Fonts.Lookup_Glyph",
         "font discovery must reject missing-glyph fallback as filename coverage");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "not Glyph.Is_Empty",
         "font discovery must score only fonts with drawable glyph outlines");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "16#0627#",
         "font discovery must score Arabic filename glyph coverage");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "16#0905#",
         "font discovery must score Devanagari filename glyph coverage");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "16#3042#",
         "font discovery must score Japanese filename glyph coverage");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "16#AC00#",
         "font discovery must score Korean filename glyph coverage");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "Text_Score = Integer'First or else Static_Score < 0",
         "font discovery must skip invalid candidates instead of comparing them as weak fallbacks");
      Project_Tools.Files.Require_Contains
        (Fonts_Spec,
         "function Font_Path_For_Text",
         "font discovery spec must expose text-specific font path lookup");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "function Text_Coverage_Score",
         "font discovery must score candidate fonts against actual frame text");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "VL-Gothic-Regular.ttf",
         "font discovery must prefer the monospace VL Gothic candidate when available");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "DejaVuSansMono.ttf",
         "font discovery must prefer a stable monospace default UI font when available");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "procedure Consider_Font",
         "font discovery must compare configured and discovered fonts through one coverage path");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "elsif Is_Loadable_Font (Override_Path) then" & ASCII.LF
         & "         Consider_Font (Override_Path);",
         "text-specific font discovery must not let FILES_FONT_PATH bypass Unicode filename coverage discovery");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "Files.UTF8.Is_Required_Zero_Width_Codepoint (Codepoint)",
         "font discovery must use shared required zero-width glyph classification");
      Require_Not_Contains
        (Fonts_Body,
         "function Is_Required_Zero_Width_Codepoint",
         "font discovery must not keep a local required zero-width glyph classifier");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "Files.UTF8.Decode_Next_Display_Codepoint",
         "font discovery must decode actual filename text before glyph coverage checks");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "Missing := Missing + 1;",
         "font discovery must count missing visible filename glyphs");
      Project_Tools.Files.Require_Contains
        (Fonts_Body,
         "return Score - Integer (Missing) * 1_000;",
         "font discovery must penalize incomplete Unicode filename coverage");
      Project_Tools.Files.Require_Contains
        (Tests,
         "font discovery selected Unicode filename font covers every visible filename glyph",
         "font discovery tests must require complete Unicode filename glyph coverage");
      Project_Tools.Files.Require_Contains
        (Tests,
         "default text font prefers stable monospace UI glyphs",
         "font discovery tests must guard against proportional default UI text fonts");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "return Files.Fonts.Default_Font_Path;",
         "rendering default font lookup must delegate filesystem probing to Files.Fonts");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "function Font_Path_For_Frame",
         "rendering spec must expose frame-specific font selection");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "return Files.Fonts.Font_Path_For_Text (To_String (Text));",
         "rendering font selection must use actual frame text");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "function Pixel_Snapped",
         "text rendering must snap glyph rectangles to whole pixels before Vulkan submission");
      Project_Tools.Files.Require_Contains
        (Tests,
         "text renderer snaps glyph rectangles to whole pixels",
         "rendering tests must cover whole-pixel glyph rectangle emission");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Frame_Font_Path : constant String := Files.Rendering.Font_Path_For_Frame (Frame);",
         "runtime smoke must compute a frame-specific font path");
      Project_Tools.Files.Require_Contains
        (Application_Body,
         "Font_Path   => Frame_Font_Path",
         "runtime smoke must initialize text rendering with the frame-specific font");
      Require_Not_Contains
        (Windows_Body,
         "Glyphs.Missing_Glyph_Count > 0",
         "live rendering must not reload fonts during every frame with missing glyphs");
      Require_Not_Contains
        (Rendering_Body,
         "/usr/share/fonts",
         "rendering body must not hard-code system font paths");
      Project_Tools.Files.Require_Contains
        (Tests,
         "rendering default font delegates to startup font discovery",
         "rendering tests must cover default font discovery delegation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "FILES_FONT_PATH selects a loadable font file override",
         "rendering tests must cover valid configured font path overrides");
      Project_Tools.Files.Require_Contains
        (Tests,
         "FILES_FONT_PATH rejects ordinary non-font file overrides",
         "rendering tests must reject invalid configured font path overrides");
      Project_Tools.Files.Require_Contains
        (Tests,
         "FILES_FONT_PATH rejects directory overrides",
         "rendering tests must cover rejected directory font overrides");
      Project_Tools.Files.Require_Contains
        (Tests,
         "default text font directly covers non-ASCII filename glyphs",
         "rendering tests must cover direct non-ASCII filename glyph coverage");
      Project_Tools.Files.Require_Contains
        (Tests,
         "font discovery can select a font for main-section Unicode filename text",
         "rendering tests must cover text-specific font selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "weak FILES_FONT_PATH does not pin main-section Unicode filename rendering",
         "rendering tests must cover weak font override fallback for Unicode filenames");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame text selects a concrete font path for main-section Unicode item names",
         "rendering tests must cover frame-specific Unicode font selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "FILES_FONT_PATH ignores missing font overrides",
         "rendering tests must cover rejected missing font overrides");
      Project_Tools.Files.Require_Contains
        (Tests,
         "main-section non-Latin item names emit visible Unicode glyphs in every view mode",
         "rendering tests must cover non-Latin filename glyphs in the main view");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame omits image icon asset outer border",
         "rendering tests must reject image icon outer borders");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame omits Ada icon asset outer border",
         "rendering tests must reject Ada icon outer borders");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame omits unknown icon asset outer border",
         "rendering tests must reject unknown icon outer borders");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "type View_Snapshot is record",
         "rendering spec must expose immutable view snapshot records");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "function Build_Snapshot",
         "rendering spec must expose snapshot construction");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "Model : Files.Model.Window_Model",
         "snapshot construction must consume the window model explicitly");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "function Build_Frame_Commands",
         "rendering spec must expose backend-neutral frame command construction");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "Snapshot    : View_Snapshot",
         "frame command construction must consume view snapshots");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "Selected_Info                  : Info_Snapshot_Vectors.Vector;",
         "view snapshots must carry info-pane selected-item metadata");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "type Info_Pane_Layout is record",
         "rendering spec must expose info-pane layout and scrollbar metrics");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "function Calculate_Info_Pane_Layout",
         "rendering spec must expose pure info-pane layout calculation");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "function Info_Section_Row_Count",
         "info-pane rendering must measure rows for wrapped selected-file metadata");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Content_H     : constant Natural :=",
         "info-pane layout must compute overflow from selected-item metadata sections");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Wrapped_Line_Count (Info_Field_Display_Value (Info, Field), Text_W, Line_Height)",
         "info-pane content height must scale by wrapped metadata value rows");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Saturating_Multiply (Value / Denominator, Numerator)",
         "rendering proportional layout must avoid raw scaled-product overflow");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Item_Rect.Text_X - Files.UI.Input_Field_Padding",
         "focused rename caret rendering must not underflow narrow item text origins");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Saturating_Add (Item_Rect.Text_Width, Caret_Inset)",
         "focused rename caret rendering must keep caret field width overflow-safe");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Files.UTF8.Display_Units_Before (Raw, Snapshot.Text_Cursor_Position)",
         "focused text caret rendering must convert UTF-8 byte cursor offsets to display columns");
      Require_Not_Contains
        (Rendering_Body,
         "Add_Border (X, Y, Draw_Size, Draw_Size, Border_Color);",
         "main-section icon assets must not draw an extra outer square border");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Icon_Size : constant Natural :=" & ASCII.LF
         & "              (if Button_W >= Files.UI.Toolbar_Button_Width",
         "toolbar icon rendering must keep a fixed icon box when toolbar buttons have fixed width");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "procedure Add_Toolbar_Asset_Icon",
         "toolbar icon rendering must use icon assets for non-drive toolbar icons");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Icon_Id    => To_Unbounded_String (Icon_Name)",
         "toolbar icon rendering must emit icon commands instead of text glyphs");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "procedure Add_Toolbar_Drive_Icon",
         "drive chooser toolbar icon must use a purpose-built hamburger shape");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "if Command = Files.Commands.Select_Drive_Command then" & ASCII.LF
         & "               Add_Toolbar_Drive_Icon",
         "drive chooser toolbar icon must not use a generic font glyph");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Add_Bar (0);" & ASCII.LF
         & "         Add_Bar (1);" & ASCII.LF
         & "         Add_Bar (2);",
         "drive chooser toolbar icon must render three hamburger bars");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Bar_W     : constant Natural := Natural'Max (1, (Size * 2) / 3);",
         "drive chooser toolbar icon must use centered standard hamburger bars");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Root_Selector_Padding : constant Natural := 8;",
         "root selector menu must define explicit padding");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Saturating_Add (Line_Height, Saturating_Multiply (Files.UI.Input_Field_Padding, 2))",
         "root selector row icons must match toolbar icon size");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Scale    : constant Float :=",
         "text rendering must keep toolbar glyph scaling explicitly gated");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Metrics.W * Scale",
         "text rendering must scale only commands marked for icon boxes");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Draw_X := Float (Text.X) + (Float (Text.Width) - Scaled_W) / 2.0;",
         "toolbar glyph rendering must center scaled glyphs inside their icon box");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Draw_Y := Float (Text.Y) + (Float (Text.Height) - Scaled_H) / 2.0;",
         "toolbar glyph rendering must vertically center scaled glyphs inside their icon box");
      Require_Not_Contains
        (Rendering_Body,
         "procedure Add_Pixel_Icon",
         "toolbar icon rendering must not use enlarged 7x7 pixel glyphs");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter caret renders after UTF-8 characters, not bytes",
         "rendering tests must cover UTF-8-aware caret x position");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter caret counts malformed UTF-8 byte as replacement cell",
         "rendering tests must cover malformed UTF-8 replacement-cell caret x position");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame renders toolbar icons as centered icon assets",
         "rendering tests must cover centered toolbar icon assets");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame renders visible toolbar icon geometry",
         "rendering tests must cover visible toolbar icon geometry");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame renders toolbar icon diagonals as triangles",
         "rendering tests must cover non-blocky toolbar diagonal geometry");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "procedure Add_Triangle",
         "toolbar rendering must have a triangle primitive for diagonal icons");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering-vulkan.adb",
         "Triangle_Vertex_Count",
         "Vulkan submission must account for triangle icon primitives");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Details_Column_Padding : constant Natural := 6;",
         "details view must keep horizontal cell padding");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Item_Content_Padding : constant Natural := 4;",
         "main-view item content must keep padding inside hover and selection blocks");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Command_Palette_Padding : constant Natural := 8;",
         "command palette must keep content padding inside the panel");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Command_Result_Row_Padding : constant Natural := 4;",
         "command palette result rows must keep vertical padding");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Command_Palette_Scrollbar_Gap : constant Natural := 8;",
         "command palette content must leave horizontal padding before the scrollbar");
      Require_Not_Contains
        (Rendering_Body,
         "Item_State_Inset",
         "main-view hover and selection blocks must include the item padding area");
      Project_Tools.Files.Require_Contains
        (Tests,
         "details name column has cell padding",
         "rendering tests must cover details column padding");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame renders hover fill around padded visible item",
         "rendering tests must cover hover fill including item padding");
      Project_Tools.Files.Require_Contains
        (Tests,
         "small-icons content has vertical padding inside hover box",
         "rendering tests must cover vertical item hover-box padding");
      Project_Tools.Files.Require_Contains
        (Tests,
         "large-icons item name has padding below the icon",
         "rendering tests must cover large-icon label padding");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame renders opaque command-palette panel",
         "rendering tests must cover opaque command-palette panel rendering");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette results follow padded search input with a gap",
         "rendering tests must cover command-palette panel padding");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette result row includes vertical padding",
         "rendering tests must cover command-palette result row padding");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame keeps command-palette text out of scrollbar gutter",
         "rendering tests must cover command-palette scrollbar gutter padding");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame renders command-palette rows opaque",
         "rendering tests must reject transparent command-palette rows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame hides file item text behind command palette",
         "rendering tests must reject file item text leaking through the command palette");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Drawing_Command_Palette : Boolean := False;",
         "normal text rendering must distinguish command-palette text from occluded background text");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "and then not Drawing_Command_Palette",
         "normal text rendering must suppress background text under the command palette");
      Project_Tools.Files.Require_Contains
        (Tests,
         "details frame redraws column separators after alternating row fills",
         "rendering tests must cover details column separators over alternating rows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "details frame stops column separators at last visible row",
         "rendering tests must cover details column separator height");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame renders drive chooser toolbar hamburger top bar",
         "rendering tests must cover the drive chooser hamburger top bar");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame renders drive chooser toolbar hamburger middle bar",
         "rendering tests must cover the drive chooser hamburger middle bar");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame renders drive chooser toolbar hamburger bottom bar",
         "rendering tests must cover the drive chooser hamburger bottom bar");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame does not render drive chooser as a square glyph",
         "rendering tests must reject the old drive chooser square glyph");
      Project_Tools.Files.Require_Contains
        (Tests,
         "large-icons item name is centered beneath the icon",
         "rendering tests must cover large-icon centered item names");
      Project_Tools.Files.Require_Contains
        (Tests,
         "text renderer supports explicit box-scaled glyphs",
         "rendering tests must cover explicit glyph scaling");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering-vulkan.adb",
         "Icon_Atlas_Tile_Size : constant Positive := 64;",
         "Vulkan icon atlas must render icons at high enough resolution for toolbar use");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering-vulkan.adb",
         "Texture : Interfaces.C.C_float := 0.0;",
         "Vulkan GPU vertices must carry the selected texture source");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering-vulkan.adb",
         "location => 4",
         "Vulkan pipeline must expose texture source as a vertex attribute");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering-vulkan.adb",
         "Texture_Source'Pos (Source.Texture)",
         "Vulkan vertex upload must pass the texture source to the shader");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering-vulkan.adb",
         "if Icon_Id = ""folder"" then",
         "Vulkan icon atlas must keep folder assets in the directory color");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan folder icon atlas uses directory blue base color",
         "rendering tests must cover Vulkan folder icon atlas color");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan skips toolbar icon atlas quads so vector toolbar icons stay visible",
         "rendering tests must ensure Vulkan does not draw dark toolbar atlas icons over vector icons");
      Project_Tools.Files.Require_Contains
        (Tests,
         "renderer exposes bundled toolbar home icon asset text",
         "rendering tests must cover bundled toolbar icon assets");
      Project_Tools.Files.Require_Contains
        (Tests,
         "toolbar trash icon asset uses a bin shape instead of an x shape",
         "rendering tests must reject x-shaped move-to-trash toolbar icons");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Saturating_Add (Row_Text_X, Row_Text_W - Shortcut_Width)",
         "command-palette shortcut placement must keep right-aligned text coordinates overflow-safe");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Files.UTF8.Display_Units (To_String (Command.Shortcut_Text))",
         "command-palette shortcut width must use UTF-8 display cells instead of byte length");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame sizes command-palette UTF-8 shortcut text by display cells",
         "rendering tests must cover UTF-8 command-palette shortcut width");
      Project_Tools.Files.Require_Contains
        (Tests,
         "narrow rename frame clips rectangle width",
         "rendering tests must cover narrow focused rename caret geometry");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Scrollbar_Visible => Visible",
         "info-pane layout must expose scrollbar visibility for overflowing metadata");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Info_Pane.Scrollbar_Track_Height",
         "info-pane scrollbar rendering must use the explicit track height");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-events.adb",
         "Within (Y, Info_Pane.Scrollbar_Y, Info_Pane.Scrollbar_Track_Height)",
         "info-pane scrollbar hit testing must use the explicit track height");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info pane exposes explicit scrollbar track height",
         "event tests must cover explicit info-pane scrollbar track height");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info scrollbar ignores clicks below track height",
         "event tests must cover info-pane scrollbar track hit limits");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "View_H > 0" & ASCII.LF
         & "        and then Bar_W > 0" & ASCII.LF
         & "        and then Content_Total_H > View_H",
         "main-view layout must not expose a scrollbar when the scrollbar width is zero");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "Scrollbar_Track_Height : Natural := 0;",
         "main-view layout must expose explicit scrollbar track height");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Scrollbar_Track_Height => (if Visible then View_H else 0)",
         "main-view scrollbar layout must use the padded content height as the track");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Main_View.Scrollbar_Track_Height",
         "main-view scrollbar rendering must use the explicit padded track height");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-events.adb",
         "Within (Y, Main_View.Scrollbar_Y, Main_View.Scrollbar_Track_Height)",
         "main-view scrollbar hit testing must use the explicit padded track height");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "and then Layout.Info_Pane_Width > 0" & ASCII.LF
         & "        and then Bar_W > 0" & ASCII.LF
         & "        and then Layout.Main_Height > 0",
         "info-pane layout must not expose a scrollbar when the scrollbar width is zero");
      Project_Tools.Files.Require_Contains
        (Tests,
         "zero-width main view does not expose scrollbar",
         "rendering tests must cover zero-width main-view scrollbar visibility");
      Project_Tools.Files.Require_Contains
        (Tests,
         "zero-width info pane does not expose scrollbar",
         "rendering tests must cover zero-width info-pane scrollbar visibility");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Height > Command_H then Natural'Min (Line_Height, Height - Command_H) else 0",
         "command-palette layout must keep the vertical offset inside short windows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "short command palette stays within the window height",
         "rendering tests must cover short command-palette vertical clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "tiny command palette stays within the window height",
         "rendering tests must cover tiny command-palette vertical clamping");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "if Selected_Index = 0 and then not Palette_Results.Is_Empty then" & ASCII.LF
         & "               Selected_Index := 1;",
         "snapshot construction must clamp missing command-palette selections to the first result");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "elsif Selected_Index > Natural (Palette_Results.Length) then" & ASCII.LF
         & "               Selected_Index := (if Palette_Results.Is_Empty then 0 else 1);",
         "snapshot construction must clamp stale command-palette selections without mutating the model");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "if Palette_Results.Is_Empty then" & ASCII.LF
         & "               Result_Offset := 0;",
         "snapshot construction must clear command-palette result offsets for empty result sets");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "elsif Result_Offset >= Natural (Palette_Results.Length) then" & ASCII.LF
         & "               Result_Offset := Natural (Palette_Results.Length) - 1;",
         "snapshot construction must clamp stale command-palette result offsets without mutating the model");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Selected   => Index = Selected_Index",
         "snapshot construction must mark the effective selected command-palette result");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Snapshot.Settings_Default_View := To_Unbounded_String (View_Mode_Text (Settings.Default_View));",
         "snapshot construction must project localized settings default-view values");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Snapshot.Settings_Default_View_Token := To_Unbounded_String (View_Mode_Token (Settings.Default_View));",
         "snapshot construction must preserve raw settings default-view tokens");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Snapshot.Settings_Hidden_Files_Token := To_Unbounded_String (Boolean_Token (Settings.Show_Hidden_Files));",
         "snapshot construction must preserve raw hidden-file boolean tokens");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Snapshot.Settings_Sort_Field_Token := To_Unbounded_String (Sort_Field_Token (Settings.Sort_Field_Value));",
         "snapshot construction must preserve raw sort-field tokens");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Snapshot.Settings_Open_Actions :=" & ASCII.LF
         & "        To_Unbounded_String (Natural_Text (Natural (Settings.Open_Actions.Length)));",
         "snapshot construction must count saved open actions when no draft overrides them");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Snapshot.Settings_Open_Actions :=" & ASCII.LF
         & "                 To_Unbounded_String" & ASCII.LF
         & "                   (Natural_Text (Paired_Row_Count (Draft.Open_Action_Keys, Draft.Open_Action_Commands)));",
         "snapshot construction must count paired draft open actions while editing settings");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "function Paired_Row_Count",
         "snapshot construction must share paired mapping row semantics");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Draft : constant Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);",
         "snapshot construction must capture the visible settings draft once per snapshot");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "if Length (Draft.Default_View_Mode) > 0 then",
         "snapshot construction must test draft presence from the captured draft value");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Snapshot.Settings_Draft_Valid := Draft.Valid;",
         "snapshot construction must expose settings draft validation state");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Snapshot.Settings_Draft_Error := Draft.Error_Key;",
         "snapshot construction must expose settings draft diagnostic keys");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Snapshot.Settings_Field_Help :=",
         "snapshot construction must expose localized help for the active settings field");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Snapshot.Settings_Control_Options :=",
         "snapshot construction must expose localized option text for the active settings field");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Snapshot.Settings_Can_Save := Files.Commands.Is_Enabled (Files.Commands.Save_Settings_Command, Model);",
         "snapshot construction must expose settings save command enablement");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Snapshot.Theme_Name := Theme.Name;",
         "snapshot construction must expose the selected render theme name");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Snapshot.Theme_Focus_Ring := Theme.Focus_Ring;",
         "snapshot construction must expose theme focus-ring color");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Visible_Rows : constant Natural := Complete_Visible_Row_Count (Layout.Results_Height, Layout.Row_Height);",
         "command-palette result layout must use only complete visible result rows");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Offset       : constant Natural := Natural'Min (Snapshot.Command_Palette_Result_Offset, Max_Offset);",
         "command-palette result layout must clamp stale offsets to the last visible page");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "exit when Remaining < Layout.Row_Height;",
         "command-palette result layout must not emit partial final rows");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Info_Field_Value (Info, 2)",
         "info-pane rendering must use localized fallback text for missing sizes");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Details_Row_Padding : constant Natural := 4;",
         "details rows must have internal padding");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Details_Row_Gap : constant Natural := 4;",
         "details rows must leave separation between rows");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "return Null_Unbounded_String;",
         "details view must render missing file sizes as blank text");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Scaled_Number & "" "" & Files.Localization.Text (Unit_Key, Locale)",
         "details view must render file sizes with localized scaled units");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Files.Localization.System_Number_Locale",
         "details view must use the detected numeric locale for size formatting");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Info_Metadata_Text (Info.Creation_Available, Info.Creation_Time)",
         "info-pane rendering must localize missing creation timestamps");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Length (Info.Permissions) = 0",
         "info-pane rendering must use localized fallback text for missing permissions");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Files.Localization.Text (To_String (Info.Error_Key))",
         "info-pane rendering must localize metadata error keys");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "if Info.Metadata_Error then",
         "info-pane accessibility descriptions must include metadata-error diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info pane accessibility describes metadata error keys",
         "rendering tests must cover metadata-error accessibility descriptions");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "Command_Enabled                : Command_Enablement_Array",
         "view snapshots must carry command enablement for toolbar and palette rendering");
      Project_Tools.Files.Require_Contains
        (Vulkan_Spec,
         "type Runtime_Validation_Plan is record",
         "Vulkan rendering must expose an explicit runtime validation plan");
      Project_Tools.Files.Require_Contains
        (Vulkan_Spec,
         "type Runtime_Validation_Suite_Result is record",
         "Vulkan rendering must expose aggregate runtime validation results");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Validate_Resize_Request (Renderer, Plan.Width, Plan.Height)",
         "Vulkan runtime validation suite must route resize validation through the resize validator");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Status := Present (Renderer, Batch);",
         "Vulkan runtime validation suite must exercise the presentation path for bounded frames");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Result.Frames_Attempted := Result.Frames_Attempted + 1;",
         "Vulkan runtime validation suite must count attempted bounded frames");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Renderer.Long_Running_Validated := Result.Frames_Attempted = Natural (Plan.Frame_Count);",
         "Vulkan runtime validation suite must only claim long-running validation after all frames run");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Renderer.Multi_Window_Validated := Plan.Window_Count >= 2;",
         "Vulkan runtime validation suite must only claim multi-window validation for multi-window plans");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Validate_Surface_Loss (Renderer)",
         "Vulkan runtime validation suite must route surface-loss handling through the surface validator");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Validate_Device_Loss (Renderer)",
         "Vulkan runtime validation suite must route device-loss handling through the device validator");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Long_Running_Validated => Renderer.Long_Running_Validated",
         "Vulkan diagnostics must report long-running validation state from renderer state");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Multi_Window_Validated => Renderer.Multi_Window_Validated",
         "Vulkan diagnostics must report multi-window validation state from renderer state");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Renderer.Last_Vertex_Count := Natural (Batch.Vertices.Length);",
         "Vulkan presentation must record the submitted vertex count before backend checks");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Renderer.Last_Texture_Count := Batch.Texture_Count;",
         "Vulkan presentation must record submitted texture binding count");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Renderer.Last_Used_Mixed_Textures := Batch.Uses_Separate_Text_And_Icon_Textures;",
         "Vulkan presentation must record mixed text and icon texture usage");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "function Compare_Gpu_Screenshot",
         "Vulkan rendering must expose deterministic GPU screenshot comparison support");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Vk.IMAGE_USAGE_COLOR_ATTACHMENT_BIT or Vk.IMAGE_USAGE_TRANSFER_SRC_BIT",
         "Vulkan swapchain images must support framebuffer readback transfers");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Vk.Cmd_Copy_Image_To_Buffer",
         "Vulkan command buffers must copy rendered swapchain images to readback buffers");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "if Renderer.Readback_Enabled then" & ASCII.LF
         & "               Capture_Completed_Readback (Renderer);" & ASCII.LF
         & "            end if;",
         "Vulkan presentation must hash framebuffer readback only when diagnostics are enabled");
      Project_Tools.Files.Require_Contains
        (Windows_Body,
         "Files.Rendering.Vulkan.Set_Readback_Enabled (Runtime.Vulkan, True);",
         "live smoke must explicitly enable framebuffer readback diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan framebuffer readback diagnostics are disabled by default",
         "Vulkan tests must guard readback diagnostics against default-on regressions");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Framebuffer_Readback_Ready => Renderer.Readback_Ready",
         "Vulkan diagnostics must expose completed framebuffer readback status");
      Project_Tools.Files.Require_Contains
        (Tests,
         "GPU screenshot comparison detects changed vertex colors",
         "Vulkan tests must cover screenshot comparison mismatches");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Renderer.Command_Buffers (Positive (Image_Index + 1))",
         "Vulkan presentation must convert zero-based swapchain image indexes after adding one");
      Require_Not_Contains
        (Vulkan_Body,
         "Renderer.Command_Buffers (Positive (Image_Index) + 1)",
         "Vulkan presentation must not convert zero image indexes to Positive before adding one");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "return Scaled_Down (Value, Factor, Denominator);",
         "Vulkan proportional layout arithmetic must preserve scale when raw multiplication would overflow");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Renderer.Presented_Frames := Renderer.Presented_Frames + 1;",
         "Vulkan presentation must count successfully presented frames");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Renderer.Skipped_Frames := Renderer.Skipped_Frames + 1;",
         "Vulkan presentation must count skipped or recreate-needed frames");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "Renderer.Failed_Frames := Renderer.Failed_Frames + 1;",
         "Vulkan presentation must count failed frame submissions");
      Project_Tools.Files.Require_Contains
        (Vulkan_Body,
         "height    => -Framebuffer_Height,",
         "Vulkan viewport must flip Y so top-left UI coordinates render upright");
      Project_Tools.Files.Require_Contains
        (Tests,
         "snapshot construction does not mutate stale palette selection",
         "rendering tests must prove snapshot construction leaves model palette state unchanged");
      Project_Tools.Files.Require_Contains
        (Tests,
         "snapshot offset clamp does not mutate the model",
         "rendering tests must prove palette offset clamping leaves model state unchanged");
      Project_Tools.Files.Require_Contains
        (Tests,
         "snapshot clamps stale palette selection",
         "rendering tests must cover stale command-palette selection clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "snapshot marks effective selected palette result",
         "rendering tests must cover effective command-palette selection marks");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty palette snapshot clears stale selection",
         "rendering tests must cover empty command-palette selection clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty palette snapshot does not mutate stale model selection",
         "rendering tests must cover immutable empty command-palette selection clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty palette snapshot has no result rows",
         "rendering tests must cover empty command-palette result snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "snapshot captures palette result offset",
         "rendering tests must cover command-palette result offset snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "snapshot construction does not mutate palette result offset",
         "rendering tests must cover immutable command-palette offset snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "snapshot clamps stale palette result offset",
         "rendering tests must cover stale command-palette offset clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "stale palette offset still emits a full visible page",
         "rendering tests must cover command-palette layout with stale offsets");
      Project_Tools.Files.Require_Contains
        (Tests,
         "stale palette offset clamps to last page start",
         "rendering tests must cover command-palette layout stale-offset page starts");
      Project_Tools.Files.Require_Contains
        (Tests,
         "stale palette offset keeps final result visible",
         "rendering tests must cover final command-palette result visibility after offset clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings snapshot captures actual default view setting",
         "rendering tests must cover localized settings default-view snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings snapshot keeps raw default view token",
         "rendering tests must cover raw default-view token snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings snapshot keeps raw hidden-file token",
         "rendering tests must cover raw hidden-file token snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings snapshot keeps raw sort-field token",
         "rendering tests must cover raw sort-field token snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings snapshot counts open actions",
         "rendering tests must cover saved settings open-action counts");
      Project_Tools.Files.Require_Contains
        (Tests,
         "editable settings snapshot counts draft filetype mappings",
         "rendering tests must cover editable draft filetype counts");
      Project_Tools.Files.Require_Contains
        (Tests,
         "editable settings snapshot counts draft icon mappings",
         "rendering tests must cover editable draft icon counts");
      Project_Tools.Files.Require_Contains
        (Tests,
         "editable settings snapshot counts draft open actions",
         "rendering tests must cover editable draft open-action counts");
      Project_Tools.Files.Require_Contains
        (Tests,
         "editable settings snapshot ignores orphan filetype rows",
         "rendering tests must cover malformed draft filetype counts");
      Project_Tools.Files.Require_Contains
        (Tests,
         "editable settings snapshot ignores orphan icon rows",
         "rendering tests must cover malformed draft icon counts");
      Project_Tools.Files.Require_Contains
        (Tests,
         "editable settings snapshot ignores orphan open-action rows",
         "rendering tests must cover malformed draft open-action counts");
      Project_Tools.Files.Require_Contains
        (Tests,
         "draft snapshot count does not mutate saved filetype mappings",
         "rendering tests must prove draft filetype counts do not mutate saved settings");
      Project_Tools.Files.Require_Contains
        (Tests,
         "draft snapshot count does not mutate saved open actions",
         "rendering tests must prove draft open-action counts do not mutate saved settings");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings option controls highlight active raw token while rendering localized text",
         "rendering tests must cover raw-token matching for localized settings options");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings snapshot exposes selected control options",
         "rendering tests must cover selected settings control options");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings snapshot exposes save availability",
         "rendering tests must cover settings command enablement in snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "snapshot captures invalid settings draft",
         "rendering tests must cover invalid draft state snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "snapshot captures settings draft diagnostic key",
         "rendering tests must cover settings draft diagnostic snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings edit clears stale draft diagnostic key",
         "rendering tests must cover cleared settings draft diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "snapshot exposes high-contrast theme name",
         "rendering tests must cover high-contrast theme snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "snapshot exposes high-contrast focus ring color",
         "rendering tests must cover high-contrast focus-ring snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "snapshot includes temporary item info",
         "rendering tests must cover temporary create-file info snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "snapshot captures main view scroll lines",
         "rendering tests must cover main-view scroll state snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "main view layout clamps excessive scroll lines",
         "rendering tests must cover clamped main-view scroll layout");
      Project_Tools.Files.Require_Contains
        (Tests,
         "main view layout clamp does not mutate snapshot scroll request",
         "rendering tests must prove main-view scroll clamping leaves snapshots unchanged");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame includes main-view scrollbar thumb",
         "rendering tests must cover rendered main-view scrollbar geometry");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Add_Rect (Grip_X, Saturating_Add (Mid_Y, 2), Grip_W, 1, Muted_Text_Color);",
         "scrollbar grip rendering must avoid lower-grip coordinate overflow");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame includes overflow-safe scrollbar grip",
         "rendering tests must cover rendered overflow-safe scrollbar grip path");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty directory renders localized empty-state text",
         "rendering tests must cover localized empty-directory state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty directory renders framed empty-state panel",
         "rendering tests must cover empty-directory panel geometry");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty directory renders empty-state icon mark",
         "rendering tests must cover empty-directory icon mark geometry");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filtered-empty view renders localized empty-state text",
         "rendering tests must cover localized empty-filter state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filtered-empty view renders framed empty-state panel",
         "rendering tests must cover empty-filter panel geometry");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty filter input renders localized placeholder text",
         "rendering tests must cover the localized filter placeholder");
      Project_Tools.Files.Require_Contains
        (Tests,
         "filter placeholder uses a real ellipsis",
         "rendering tests must reject three-dot filter placeholder text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info pane frame includes localized name row",
         "rendering tests must cover info-pane name rows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info pane frame includes localized missing creation row",
         "rendering tests must cover missing creation metadata fallback");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info pane localizes metadata error keys",
         "rendering tests must cover localized metadata error rows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot captures filesystem-backed filetype extra metadata",
         "rendering tests must cover filesystem-backed metadata projection into item snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info pane captures loaded text line metadata",
         "rendering tests must cover text metadata projection into info snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info pane layout clamps excessive scroll lines",
         "rendering tests must cover clamped info-pane scroll layout");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info pane layout clamp does not mutate snapshot scroll request",
         "rendering tests must prove info-pane scroll clamping leaves snapshots unchanged");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info pane layout clamp does not mutate model scroll request",
         "rendering tests must prove info-pane scroll clamping leaves model state unchanged");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes UTF-8 text metadata",
         "rendering tests must cover localized UTF-8 metadata projection");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering.adb",
         "function Fitted_Text_For",
         "rendering fitted text must centralize UTF-8 display-unit truncation");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering.adb",
         "Ellipsis_Text : constant String :=",
         "rendering fitted text must use a real ellipsis character");
      Require_Not_Contains
        (Root & "/src/files-rendering.adb",
         "Prefix & ""...""",
         "rendering fitted text must not append three ASCII dots");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering.adb",
         "Was_Truncated : constant Boolean := Fit and then To_String (Fitted) /= Raw;",
         "rendering fitted text must detect truncation by content, not byte length");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering.adb",
         "Files.UTF8.Prefix_By_Units",
         "rendering fitted text must clamp truncation through the shared UTF-8 helper");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.ads",
         "function Display_Units",
         "shared UTF-8 helper must expose display-cell measurement");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.ads",
         "function Prefix_By_Units",
         "shared UTF-8 helper must expose display-cell prefix clamping");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.ads",
         "function Display_Units_Before",
         "shared UTF-8 helper must expose cursor display-cell counting");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.ads",
         "function Byte_Offset_For_Display_Column",
         "shared UTF-8 helper must expose display-column byte mapping");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.adb",
         "function Codepoint_Display_Units",
         "shared UTF-8 helper must centralize codepoint display-cell width");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.adb",
         "function Is_Wide_Codepoint",
         "shared UTF-8 helper must recognize wide item-name glyphs");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.adb",
         "function Is_Combining_Codepoint",
         "shared UTF-8 helper must recognize zero-width combining marks");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.adb",
         "Codepoint in 16#FE00# .. 16#FE0F#",
         "shared UTF-8 helper must recognize zero-width variation selectors");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.adb",
         "Codepoint in 16#E0100# .. 16#E01EF#",
         "shared UTF-8 helper must recognize supplementary variation selectors");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.adb",
         "function Next_Unit_Boundary",
         "shared UTF-8 helper must keep raw UTF-8 unit stepping separate from visual boundaries");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.ads",
         "procedure Decode_Next_Codepoint",
         "shared UTF-8 helper must expose codepoint decoding");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.ads",
         "procedure Decode_Next_Display_Codepoint",
         "shared UTF-8 helper must expose tolerant display codepoint decoding");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-utf8.ads",
         "function Is_Required_Zero_Width_Codepoint",
         "shared UTF-8 helper must expose required zero-width glyph classification");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering.adb",
         "Files.UTF8.Decode_Next_Display_Codepoint",
         "text glyph rendering must use the shared UTF-8 display decoder");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "Missing_Glyph_Count : Natural := 0;",
         "text render results must expose missing-glyph fallback accounting");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "if Status /= Textrender.Success then",
         "text glyph rendering must count missing-glyph fallback usage");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Files.UTF8.Is_Required_Zero_Width_Codepoint (Decoded_Codepoint)",
         "text glyph rendering must use shared required zero-width glyph classification");
      Require_Not_Contains
        (Rendering_Body,
         "function Is_Required_Zero_Width_Codepoint",
         "text glyph rendering must not keep a local required zero-width glyph classifier");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Codepoint := Textrender.Codepoint (Character'Pos ('?'));",
         "text glyph rendering must emit a visible marker for missing filename glyphs");
      Project_Tools.Files.Require_Contains
        (Tests,
         "missing filename glyph emits a visible replacement marker",
         "rendering tests must cover visible fallback glyphs for unsupported filename text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "variation-selector filename text does not emit visible fallback marker",
         "rendering tests must reject visible fallback markers for zero-width filename text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "main-section UTF-8 item name renders without missing-glyph fallback",
         "rendering tests must reject missing-glyph fallback for UTF-8 item names");
      Project_Tools.Files.Require_Contains
        (Tests,
         "directory-loaded UTF-8 item names render without missing-glyph fallback",
         "rendering tests must reject missing-glyph fallback for filesystem-loaded UTF-8 item names");
      Project_Tools.Files.Require_Contains
        (Tests,
         "directory load preserves decomposed UTF-8 item name",
         "filesystem rendering tests must preserve decomposed UTF-8 item names");
      Project_Tools.Files.Require_Contains
        (Tests,
         "directory-loaded CJK UTF-8 item name emits Unicode glyph codepoint",
         "filesystem rendering tests must cover non-Latin directory-loaded item names");
      Project_Tools.Files.Require_Contains
        (Tests,
         "directory-loaded decomposed UTF-8 item name emits accent glyph",
         "filesystem rendering tests must cover decomposed accent glyph emission");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper marks combining accents as required zero-width glyphs",
         "shared UTF-8 tests must cover required zero-width combining marks");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper does not require variation selector glyphs",
         "shared UTF-8 tests must keep variation selectors optional");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Frame_Font_Path := To_Unbounded_String (Files.Rendering.Font_Path_For_Frame (Frame));",
         "filesystem-loaded UTF-8 rendering tests must use frame-specific font selection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "main-section frame commands preserve composed UTF-8 item names before rasterization",
         "filesystem-loaded UTF-8 rendering tests must preserve composed frame-command text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "main-section frame commands preserve decomposed UTF-8 item names before rasterization",
         "filesystem-loaded UTF-8 rendering tests must preserve decomposed frame-command text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "main-section frame commands preserve CJK item names before rasterization",
         "filesystem-loaded UTF-8 rendering tests must preserve CJK frame-command text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "UTF-8 directory-loaded main view font covers composed filename glyphs",
         "filesystem-loaded UTF-8 rendering tests must verify composed glyph coverage");
      Project_Tools.Files.Require_Contains
        (Tests,
         "UTF-8 directory-loaded main view font covers decomposed accent glyphs",
         "filesystem-loaded UTF-8 rendering tests must verify decomposed accent glyph coverage");
      Project_Tools.Files.Require_Contains
        (Tests,
         "UTF-8 directory-loaded main view font covers every CJK filename glyph",
         "filesystem-loaded UTF-8 rendering tests must verify complete non-Latin glyph coverage");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering.adb",
         "if Files.UTF8.Is_Required_Zero_Width_Codepoint (Decoded_Codepoint) then",
         "text glyph rendering must report missing required zero-width marks without visible fallback");
      Project_Tools.Files.Require_Contains
        (Tests,
         "main-section Unicode item names render without missing-glyph fallback in every view mode",
         "rendering tests must reject missing-glyph fallback in every main view mode");
      Require_Not_Contains
        (Root & "/src/files-rendering.adb",
         "procedure Decode_Next_Codepoint" & ASCII.LF
         & "           (Content   : String;",
         "text glyph rendering must not keep a local UTF-8 decoder");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering.adb",
         "Files.UTF8.Display_Units_Before (Raw, Snapshot.Text_Cursor_Position)",
         "rendering caret placement must use the shared UTF-8 cursor display helper");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper counts multibyte and malformed units as display cells",
         "rendering tests must cover shared UTF-8 display-cell measurement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper treats combining marks as zero-width cells",
         "rendering tests must cover zero-width UTF-8 display-cell measurement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper treats variation selectors as zero-width cells",
         "rendering tests must cover variation-selector display-cell measurement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper treats supplementary variation selectors as zero-width cells",
         "rendering tests must cover supplementary variation-selector display-cell measurement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper treats CJK item-name glyphs as double-width cells",
         "rendering tests must cover wide UTF-8 display-cell measurement");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper preserves whole multibyte prefixes",
         "rendering tests must cover shared UTF-8 prefix clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper moves previous boundary over trailing combining marks",
         "rendering tests must cover previous visual boundary over combining marks");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper moves next boundary over trailing combining marks",
         "rendering tests must cover next visual boundary over combining marks");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper preserves trailing combining marks within display capacity",
         "rendering tests must cover combining-mark prefix preservation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper preserves trailing variation selectors within display capacity",
         "rendering tests must cover variation-selector prefix preservation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper does not fit a double-width glyph into one cell",
         "rendering tests must cover wide UTF-8 prefix clamping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper maps display columns after trailing combining marks",
         "rendering tests must cover display-column mapping after combining marks");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper decodes multibyte codepoints",
         "rendering tests must cover shared UTF-8 codepoint decoding");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 helper decodes malformed bytes as replacement codepoints",
         "rendering tests must cover shared UTF-8 malformed codepoint decoding");
      Project_Tools.Files.Require_Contains
        (Tests,
         "shared UTF-8 display decoder preserves legacy non-ASCII filename bytes",
         "rendering tests must cover tolerant legacy filename byte decoding");
      Project_Tools.Files.Require_Contains
        (Tests,
         "main-section legacy non-ASCII item name emits Latin-1 fallback glyph",
         "rendering tests must cover legacy non-ASCII filename glyph rendering");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame fitting treats one UTF-8 character as one display cell",
         "rendering tests must cover single-cell UTF-8 fitted text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame fitting preserves combining item-name marks before ellipsis",
         "rendering tests must cover combining-mark fitted text truncation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame UTF-8 fitting does not split a multibyte name character",
         "rendering tests must cover UTF-8-safe fitted text truncation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame CJK fitting keeps whole wide item-name glyphs in narrow cells",
         "rendering tests must cover wide UTF-8 fitted text truncation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame keeps a useful prefix before the ellipsis",
         "rendering tests must cover exact-width ellipsis fitting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "overlay fitting uses full ellipsis capacity",
         "rendering tests must cover overlay fitted text ellipsis capacity");
      Project_Tools.Files.Require_Contains
        (Tests,
         "overlay UTF-8 fitting keeps full multibyte character before ellipsis",
         "rendering tests must cover UTF-8-safe overlay text truncation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "overlay fitting treats one UTF-8 character as one display cell",
         "rendering tests must cover single-cell UTF-8 overlay fitted text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes settings add accessibility node",
         "rendering tests must cover settings add accessibility output");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes settings remove accessibility node",
         "rendering tests must cover settings remove accessibility output");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes binary text metadata",
         "rendering tests must cover localized binary metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes Markdown metadata",
         "rendering tests must cover localized Markdown metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes XLSX metadata",
         "rendering tests must cover localized Office metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes Ada source metadata",
         "rendering tests must cover localized Ada source metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes JSON source metadata",
         "rendering tests must cover localized JSON source metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes XML source metadata",
         "rendering tests must cover localized XML source metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes directory count metadata",
         "rendering tests must cover localized directory count metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes executable format metadata",
         "rendering tests must cover localized executable format metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes image dimension metadata",
         "rendering tests must cover localized image dimension metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes symlink target metadata",
         "rendering tests must cover localized symlink target metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes PDF page metadata",
         "rendering tests must cover localized PDF page metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes archive format metadata",
         "rendering tests must cover localized archive format metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes archive entry metadata",
         "rendering tests must cover localized archive entry metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes document package metadata",
         "rendering tests must cover localized document package metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes audio media metadata",
         "rendering tests must cover localized audio media metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "item snapshot localizes video media metadata",
         "rendering tests must cover localized video media metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info pane captures extension metadata fallback",
         "rendering tests must cover extension fallback metadata projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info pane captures executable snapshot metadata without reading file contents",
         "rendering tests must cover executable metadata projection from snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info snapshot includes all selected items",
         "rendering tests must cover multi-selection info snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info pane spaces selected sections by every rendered row",
         "rendering tests must cover vertical section spacing for selected files");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info pane wraps long data rows without abbreviation",
         "rendering tests must cover wrapped info-pane data rows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info pane continues wrapped data on the next row",
         "rendering tests must cover multi-row info-pane data values");
      Project_Tools.Files.Require_Contains
        (Tests,
         "overflow info pane exposes scrollbar",
         "rendering tests must cover overflowing info-pane scrollbar visibility");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame includes info pane scrollbar thumb",
         "rendering tests must cover rendered info-pane scrollbar geometry");
      Project_Tools.Files.Require_Contains
        (Tests,
         "info pane layout converts scroll lines to pixels",
         "rendering tests must cover info-pane scroll line projection");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Frame := Files.Rendering.Build_Frame_Commands (Snapshot",
         "rendering tests must build frame commands from immutable snapshots");
      Project_Tools.Files.Require_Contains
        (Tests,
         "partial palette result area emits no clipped row",
         "rendering tests must reject clipped command-palette result rows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "palette layout only includes complete visible rows",
         "rendering tests must cover complete command-palette result rows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty details frame includes header band",
         "rendering tests must cover empty details header band geometry");
      Project_Tools.Files.Require_Contains
        (Tests,
         "empty details frame includes modified column separator",
         "rendering tests must cover empty details column separators");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Command.Height = Empty_Header_H",
         "rendering tests must ensure empty details separators stop at the header");
      Project_Tools.Files.Require_Contains
        (Tests,
         "details rows advance by padded row height",
         "rendering tests must cover padded details row spacing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "details row height leaves a separator gap",
         "rendering tests must cover details row gap geometry");
      Project_Tools.Files.Require_Contains
        (Tests,
         "details frame renders folder icon asset",
         "rendering tests must cover folder asset icons in details view");
      Project_Tools.Files.Require_Contains
        (Tests,
         "details frame does not render folder as a plain square",
         "rendering tests must reject plain-square folder icons in details view");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Add_Icon (Item, X, Y, Size);",
         "details view icons must use the shared asset-aware icon renderer");
      Project_Tools.Files.Require_Contains
        (Tests,
         "partially scrolled details icon does not shrink",
         "rendering tests must reject shrinking icons on partially scrolled rows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "next complete details row keeps stable icon size while scrolling",
         "rendering tests must cover stable icon size during main-view scrolling");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Hidden_Px = 0 and then Rows_H >= Saturating_Add (Visible_Row, Row_Step)",
         "details layout must only render complete rows so icons do not shrink while scrolling");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Hidden_Px = 0 and then Content_H >= Saturating_Add (Visible_Row, Cell_H)",
         "grid layout must only render complete cells so icons do not shrink while scrolling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "details frame leaves missing size blank",
         "rendering tests must cover blank missing details sizes");
      Project_Tools.Files.Require_Contains
        (Tests,
         "details size includes byte unit",
         "rendering tests must cover details size units");
      Project_Tools.Files.Require_Contains
        (Tests,
         "details modified timestamp is not abbreviated",
         "rendering tests must cover full details modified timestamps");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root selector clips long root lists to visible rows",
         "rendering tests must cover clipped root-selector rows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "partial root selector row is clipped",
         "rendering tests must cover partial root-selector row clipping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root selector marks selected clipped row",
         "rendering tests must cover selected partial root-selector rows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "zero-height root selector clamps stale selected index without overflow",
         "rendering tests must cover zero-height root-selector stale-index handling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "narrow details row stays within main width",
         "rendering tests must cover narrow details layout bounds");
      Project_Tools.Files.Require_Contains
        (Tests,
         "partial details main height is represented",
         "rendering tests must cover partial details viewport heights");
      Project_Tools.Files.Require_Contains
        (Tests,
         "partial details row does not draw metadata columns under bottom bar",
         "rendering tests must cover clipped details metadata columns");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "if Snapshot.View_Mode = Files.Types.Details and then Item_Rect.Height > 0 then",
         "details metadata columns must not render for clipped-out rows");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame commands preserve layout metrics",
         "rendering tests must cover frame layout metric propagation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan validation suite records resize validation",
         "rendering tests must cover Vulkan runtime suite resize validation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan validation suite records device-loss handling",
         "rendering tests must cover Vulkan runtime suite device-loss handling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan validation suite records surface-loss handling",
         "rendering tests must cover Vulkan runtime suite surface-loss handling");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan validation suite records multi-window policy",
         "rendering tests must cover Vulkan runtime suite multi-window policy");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan validation suite records bounded frame validation",
         "rendering tests must cover Vulkan runtime suite bounded-frame validation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan diagnostics report bounded frame validation",
         "rendering tests must cover Vulkan diagnostics after bounded-frame validation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan diagnostics report multi-window validation",
         "rendering tests must cover Vulkan diagnostics after multi-window validation");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan present records skipped frame count",
         "rendering tests must cover Vulkan skipped-frame accounting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan present does not record skipped frames as presented",
         "rendering tests must cover Vulkan presented-frame accounting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan present skip does not record a failure",
         "rendering tests must cover Vulkan failure-frame accounting");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan present records last submitted vertex count",
         "rendering tests must cover Vulkan submitted batch diagnostics");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering-vulkan.adb",
         "Natural (Result.Vertices.Length) > Max_Batch_Vertices - 6",
         "Vulkan submission batching must cap quad emission before GPU upload limits");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering-vulkan.adb",
         "Source_Icon_Index : Natural := 0;",
         "Vulkan icon atlas coordinates must follow source icon tile order");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering-vulkan.adb",
         "Float (Source_Icon_Index + 1) / Float (Icon_Count)",
         "Vulkan icon atlas coordinates must not derive from emitted quad counts");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering-vulkan.adb",
         "mag_Filter               => Vk.FILTER_NEAREST",
         "Vulkan atlas samplers must use nearest magnification for crisp UI rendering");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-rendering-vulkan.adb",
         "min_Filter               => Vk.FILTER_NEAREST",
         "Vulkan atlas samplers must use nearest minification for crisp UI rendering");
      Require_Not_Contains
        (Root & "/src/files-rendering-vulkan.adb",
         "mag_Filter               => Vk.FILTER_LINEAR",
         "Vulkan atlas samplers must not blur UI atlases with linear magnification");
      Require_Not_Contains
        (Root & "/src/files-rendering-vulkan.adb",
         "min_Filter               => Vk.FILTER_LINEAR",
         "Vulkan atlas samplers must not blur UI atlases with linear minification");
      Project_Tools.Files.Require_Contains
        (Tests,
         "oversized rectangle batch caps vertices before GPU upload",
         "rendering tests must cover Vulkan batch vertex capping");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan batch appends tooltip overlay text after normal content",
         "rendering tests must cover tooltip overlay draw order");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan skipped source icon batch advances source atlas tile coordinates",
         "rendering tests must cover skipped source icon atlas coordinates");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan diagnostics aggregate skipped frames",
         "rendering tests must cover skipped-frame diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "vulkan diagnostics record mixed text and icon texture use",
         "rendering tests must cover mixed text/icon texture diagnostics");
   end Check_Rendering_Architecture;

   procedure Check_Icon_Accessibility_Contract is
      Rendering_Body : constant String := Root & "/src/files-rendering.adb";
      Rendering_Spec : constant String := Root & "/src/files-rendering.ads";
      Tests          : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "function Default_Accessibility_Profile return Accessibility_Profile;",
         "renderer spec must expose default accessibility profile metadata");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "function High_Contrast_Accessibility_Profile return Accessibility_Profile;",
         "renderer spec must expose high-contrast accessibility profile metadata");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "function Accessibility_Integration_Profile_Of_Current_UI",
         "renderer spec must expose accessibility integration metadata");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "function Icon_Theme_Profile_For",
         "renderer spec must expose settings-selected icon theme metadata");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "function Parse_Icon_Asset",
         "renderer spec must expose icon asset parsing for tests and tooling");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "Tooltips      : Tooltip_Command_Vectors.Vector;",
         "frame command snapshots must expose tooltip commands");
      Project_Tools.Files.Require_Contains
        (Rendering_Spec,
         "Accessibility : Accessibility_Node_Vectors.Vector;",
         "frame command snapshots must expose accessibility nodes");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Screen_Reader_Role_Metadata => True",
         "accessibility profiles must advertise screen-reader role metadata");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-accessibility.ads",
         "function Export_Tree",
         "accessibility integration must expose a bridge tree export");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "return Files.Accessibility.Integration_Profile;",
         "rendering integration profile must delegate to the accessibility bridge");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Theme_Name          => To_Unbounded_String (""files-basic"")",
         "icon theme metadata must expose the bundled default theme");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Theme_Name          => To_Unbounded_String (""files-high-contrast"")",
         "icon theme metadata must expose the bundled high-contrast theme");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Asset_Directory     => To_Unbounded_String (""share/files/icons/high-contrast"")",
         "high-contrast icon metadata must use the high-contrast asset directory");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Asset_Format        => To_Unbounded_String (""files-icon-v1"")",
         "icon theme metadata must record the checked asset format");
      Require_Not_Contains
        (Rendering_Body,
         "function Toolbar_Header",
         "toolbar icons must not keep unused rectangle-asset header helpers");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Corner_Role : constant String := (if Theme_Name = ""files-high-contrast"" then ""border"" else ""muted"");",
         "high-contrast bundled icon text must switch icon corner role");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Saw_Header := Line = ""files-icon-v1"";",
         "icon asset parser must validate the files-icon-v1 header");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "if not Saw_Grid then",
         "icon asset parser must reject rectangles before grid declaration");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "if Rect.Grid_W = 0 or else Rect.Grid_H = 0 or else not Fits_Grid (Rect) then",
         "icon asset parser must reject empty or out-of-grid rectangles");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Result.Valid :=",
         "icon asset parser must explicitly publish parse validity");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "function Icon_Asset_Directory return String is",
         "frame command construction must choose an icon asset directory");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "return ""share/files/icons/high-contrast"";",
         "frame command construction must route high-contrast icons to high-contrast assets");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "function Icon_Theme_Name return String is",
         "frame command construction must preserve the selected icon theme name");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "if Is_Bundled_Icon (Icon_Name) then",
         "frame command construction must resolve bundled icon identifiers");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Theme_Name => To_Unbounded_String (Icon_Theme_Name)",
         "icon commands must carry the selected icon theme name");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "To_Unbounded_String (Icon_Asset_Directory & ""/"" & Resolved_Name & "".icon"")",
         "icon commands must carry the concrete bundled icon asset path");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Result.Tooltips.Append",
         "frame command construction must emit tooltip commands");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Text_Len    : constant Natural := Files.UTF8.Display_Units (Text_Raw);",
         "hover tooltip sizing must use UTF-8 display cells instead of byte length");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Raw_Text_W  : constant Natural := Saturating_Multiply (Text_Len, Cell_W);",
         "hover tooltip sizing must not force a wide minimum panel width");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "if not Has_Hover or else Text_Len = 0 or else Text_W = 0 then",
         "hover tooltip rendering must skip empty panels when no text cells fit");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame sizes UTF-8 hover tooltip by display cells",
         "rendering tests must cover UTF-8 display-cell hover tooltip sizing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame does not size UTF-8 hover tooltip by bytes",
         "rendering tests must reject byte-count hover tooltip sizing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame sizes short hover tooltip by content width",
         "rendering tests must cover content-width short hover tooltips");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame does not force a wide minimum hover tooltip width",
         "rendering tests must reject artificial minimum hover tooltip widths");
      Project_Tools.Files.Require_Contains
        (Tests,
         "narrow frame omits empty hover tooltip panel when no text cells fit",
         "rendering tests must cover narrow hover tooltip suppression");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Result.Accessibility.Append",
         "frame command construction must emit accessibility nodes");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "function Path_Input_Accessible_Description return UString is",
         "path input accessibility description must include validation diagnostics");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "& Localized (To_String (Snapshot.Path_Input_Error_Key));",
         "path input accessibility description must localize validation errors");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "function Main_View_Accessible_Description return UString is",
         "main-view accessibility description must expose current view state");
      Project_Tools.Files.Require_Contains
        (Rendering_Body,
         "Localized (""accessibility.main_view"")," & ASCII.LF
         & "         Main_View_Accessible_Description);",
         "main-view accessibility node must include state description");
      Project_Tools.Files.Require_Contains
        (Tests,
         "default accessibility profile supports keyboard navigation",
         "AUnit tests must cover default accessibility metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "high-contrast accessibility profile advertises high contrast",
         "AUnit tests must cover high-contrast accessibility metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "accessibility integration profile exposes render node tree",
         "AUnit tests must cover accessibility integration metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "accessibility bridge exports a tree",
         "AUnit tests must cover accessibility bridge tree export");
      Project_Tools.Files.Require_Contains
        (Tests,
         "accessibility bridge counts focused nodes",
         "AUnit tests must cover accessibility bridge focus metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "icon profile exposes theme name",
         "AUnit tests must cover default icon theme metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "settings-selected icon profile exposes high-contrast theme",
         "AUnit tests must cover settings-selected icon theme metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "icon asset parser accepts files-icon-v1 text",
         "AUnit tests must cover valid icon asset parsing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "icon asset parser rejects rectangles before grid declaration",
         "AUnit tests must cover invalid icon asset ordering");
      Project_Tools.Files.Require_Contains
        (Tests,
         "icon asset parser rejects rectangles outside the grid",
         "AUnit tests must cover invalid icon asset geometry");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes configured high-contrast markdown icon asset command",
         "AUnit tests must cover high-contrast icon frame commands");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes accessible window node",
         "AUnit tests must cover accessibility frame nodes");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes localized toolbar tooltip text",
         "AUnit tests must cover tooltip frame commands");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes localized bottom-bar tooltip text",
         "AUnit tests must cover bottom-bar tooltip frame commands");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes localized root-selector tooltip text",
         "AUnit tests must cover root-selector tooltip frame commands");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes settings reset tooltip",
         "AUnit tests must cover settings reset tooltip frame commands");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes settings save tooltip",
         "AUnit tests must cover settings save tooltip frame commands");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame renders localized hover tooltip text",
         "AUnit tests must cover visible hover tooltip text");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame renders hover tooltip panel",
         "AUnit tests must cover visible hover tooltip panel");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes focused path input node",
         "AUnit tests must cover path input accessibility nodes");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes path input validation error to accessibility",
         "AUnit tests must cover path input validation accessibility diagnostics");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes main-view count state to accessibility",
         "AUnit tests must cover main-view accessibility state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes filter input state to accessibility",
         "AUnit tests must cover filter-input accessibility state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes selected item metadata to accessibility",
         "AUnit tests must cover selected-item accessibility metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes root selector node",
         "AUnit tests must cover root selector accessibility nodes");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes selected root path to accessibility",
         "AUnit tests must cover selected-root accessibility state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes bottom status node",
         "AUnit tests must cover bottom status accessibility nodes");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes info-pane toggle state to accessibility",
         "AUnit tests must cover info-pane toggle accessibility state");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes settings reset accessibility node",
         "AUnit tests must cover settings reset accessibility nodes");
      Project_Tools.Files.Require_Contains
        (Tests,
         "frame exposes settings save accessibility node",
         "AUnit tests must cover settings save accessibility nodes");
   end Check_Icon_Accessibility_Contract;

   procedure Check_Icon_Assets is
      procedure Fail_Icon
        (Path    : String;
         Message : String) is
      begin
         Put_Line (Standard_Error, Path & ": " & Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Fail_Icon;

      function Try_Parse_Natural
        (Text  : String;
         Value : out Natural)
         return Boolean
      is
         Clean : constant String := Ada.Strings.Fixed.Trim (Text, Ada.Strings.Both);
      begin
         Value := 0;
         if Clean = "" then
            return False;
         end if;

         for Position in Clean'Range loop
            if Clean (Position) not in '0' .. '9'
              or else Value > (Natural'Last - Character'Pos (Clean (Position)) + Character'Pos ('0')) / 10
            then
               return False;
            end if;
            Value := Value * 10 + Character'Pos (Clean (Position)) - Character'Pos ('0');
         end loop;

         return True;
      end Try_Parse_Natural;

      function Field
        (Text  : String;
         Index : Positive)
         return String
      is
         Start : Positive := Text'First;
         Count : Positive := 1;
      begin
         if Text = "" then
            return "";
         end if;

         for Position in Text'Range loop
            if Text (Position) = ',' then
               if Count = Index then
                  return Text (Start .. Position - 1);
               end if;
               Count := Count + 1;
               Start := Position + 1;
            end if;
         end loop;

         if Count = Index then
            return Text (Start .. Text'Last);
         else
            return "";
         end if;
      end Field;

      function Value_After_Prefix
        (Text   : String;
         Prefix : String)
         return String is
      begin
         if Text'Length <= Prefix'Length then
            return "";
         else
            return Text (Text'First + Prefix'Length .. Text'Last);
         end if;
      end Value_After_Prefix;

      function Valid_Icon_Role (Role : String) return Boolean is
         Clean : constant String := Ada.Strings.Fixed.Trim (Role, Ada.Strings.Both);
      begin
         return Clean = "base"
           or else Clean = "accent"
           or else Clean = "border"
           or else Clean = "muted";
      end Valid_Icon_Role;

      procedure Require_Valid_Icon_Asset
        (Path          : String;
         Expected_Name : String)
      is
         Content    : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
         Saw_Header : Boolean := False;
         Saw_Name   : Boolean := False;
         Saw_Grid   : Boolean := False;
         Grid       : Natural := 0;
         Rectangles : Natural := 0;

         procedure Check_Rectangle (Text : String) is
            X : Natural;
            Y : Natural;
            W : Natural;
            H : Natural;
         begin
            if not Saw_Grid then
               Fail_Icon (Path, "rectangle appears before grid declaration");
            elsif Field (Text, 6) /= "" then
               Fail_Icon (Path, "rectangle has too many fields");
            elsif not Try_Parse_Natural (Field (Text, 1), X)
              or else not Try_Parse_Natural (Field (Text, 2), Y)
              or else not Try_Parse_Natural (Field (Text, 3), W)
              or else not Try_Parse_Natural (Field (Text, 4), H)
            then
               Fail_Icon (Path, "rectangle has nonnumeric fields");
            elsif W = 0 or else H = 0 then
               Fail_Icon (Path, "rectangle must have positive dimensions");
            elsif X >= Grid or else Y >= Grid or else W > Grid - X or else H > Grid - Y then
               Fail_Icon (Path, "rectangle exceeds declared grid");
            elsif not Valid_Icon_Role (Field (Text, 5)) then
               Fail_Icon (Path, "rectangle uses an unknown role");
            end if;

            Rectangles := Rectangles + 1;
         end Check_Rectangle;

         procedure Check_Line (Raw : String) is
            Line : constant String := Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
         begin
            if Line = "" then
               return;
            elsif not Saw_Header then
               if Line /= "files-icon-v1" then
                  Fail_Icon (Path, "missing files-icon-v1 header");
               end if;
               Saw_Header := True;
            elsif Starts_With (Line, "name=") then
               if Saw_Name then
                  Fail_Icon (Path, "duplicate name declaration");
               elsif Value_After_Prefix (Line, "name=") /= Expected_Name then
                  Fail_Icon (Path, "name does not match bundled asset id");
               end if;
               Saw_Name := True;
            elsif Starts_With (Line, "grid=") then
               if Saw_Grid then
                  Fail_Icon (Path, "duplicate grid declaration");
               elsif not Try_Parse_Natural (Value_After_Prefix (Line, "grid="), Grid) or else Grid = 0 then
                  Fail_Icon (Path, "grid must be a positive natural number");
               end if;
               Saw_Grid := True;
            elsif Starts_With (Line, "rect=") then
               Check_Rectangle (Value_After_Prefix (Line, "rect="));
            else
               Fail_Icon (Path, "unknown icon asset directive");
            end if;
         end Check_Line;
      begin
         if Content /= "" then
            declare
               Line_Start : Positive := Content'First;
            begin
               for Index in Content'Range loop
                  if Content (Index) = ASCII.LF then
                     Check_Line (Content (Line_Start .. Index - 1));
                     Line_Start := Index + 1;
                  end if;
               end loop;

               if Line_Start <= Content'Last then
                  Check_Line (Content (Line_Start .. Content'Last));
               end if;
            end;
         end if;

         if not Saw_Header then
            Fail_Icon (Path, "missing files-icon-v1 header");
         elsif not Saw_Name then
            Fail_Icon (Path, "missing icon name declaration");
         elsif not Saw_Grid then
            Fail_Icon (Path, "missing icon grid declaration");
         elsif Rectangles = 0 then
            Fail_Icon (Path, "icon asset must contain at least one rectangle");
         end if;
      end Require_Valid_Icon_Asset;
   begin
      Project_Tools.Files.Require_Files
        ([To_Unbounded_String (Root & "/share/files/icons/folder.icon"),
          To_Unbounded_String (Root & "/share/files/icons/text.icon"),
          To_Unbounded_String (Root & "/share/files/icons/image.icon"),
          To_Unbounded_String (Root & "/share/files/icons/executable.icon"),
          To_Unbounded_String (Root & "/share/files/icons/link.icon"),
          To_Unbounded_String (Root & "/share/files/icons/unknown.icon"),
          To_Unbounded_String (Root & "/share/files/icons/ada.icon"),
          To_Unbounded_String (Root & "/share/files/icons/markdown.icon"),
          To_Unbounded_String (Root & "/share/files/icons/high-contrast/folder.icon"),
          To_Unbounded_String (Root & "/share/files/icons/high-contrast/text.icon"),
          To_Unbounded_String (Root & "/share/files/icons/high-contrast/image.icon"),
          To_Unbounded_String (Root & "/share/files/icons/high-contrast/executable.icon"),
          To_Unbounded_String (Root & "/share/files/icons/high-contrast/link.icon"),
          To_Unbounded_String (Root & "/share/files/icons/high-contrast/unknown.icon"),
          To_Unbounded_String (Root & "/share/files/icons/high-contrast/ada.icon"),
          To_Unbounded_String (Root & "/share/files/icons/high-contrast/markdown.icon")],
         "files icon assets must be present");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/folder.icon", "folder");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/text.icon", "text");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/image.icon", "image");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/executable.icon", "executable");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/link.icon", "link");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/unknown.icon", "unknown");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/ada.icon", "ada");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/markdown.icon", "markdown");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/high-contrast/folder.icon", "folder");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/high-contrast/text.icon", "text");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/high-contrast/image.icon", "image");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/high-contrast/executable.icon", "executable");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/high-contrast/link.icon", "link");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/high-contrast/unknown.icon", "unknown");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/high-contrast/ada.icon", "ada");
      Require_Valid_Icon_Asset (Root & "/share/files/icons/high-contrast/markdown.icon", "markdown");
   end Check_Icon_Assets;

   procedure Check_Platform_Bodies is
      Tests : constant String := Combined_Suite;
   begin
      Project_Tools.Files.Require_Files
        ([To_Unbounded_String (Root & "/src/platform/windows/files-platform-windows.adb"),
          To_Unbounded_String (Root & "/src/platform/windows/files-platform-windows-trash.adb"),
          To_Unbounded_String (Root & "/src/platform/windows/files-platform-windows-volumes.adb"),
          To_Unbounded_String (Root & "/src/platform/macos/files-platform-macos.adb"),
          To_Unbounded_String (Root & "/src/platform/macos/files-platform-macos-trash.adb"),
          To_Unbounded_String (Root & "/src/platform/macos/files-platform-macos-volumes.adb"),
          To_Unbounded_String (Root & "/src/platform/unsupported/files-platform-windows.adb"),
          To_Unbounded_String (Root & "/src/platform/unsupported/files-platform-windows-trash.adb"),
          To_Unbounded_String (Root & "/src/platform/unsupported/files-platform-windows-volumes.adb"),
          To_Unbounded_String (Root & "/src/platform/unsupported/files-platform-macos.adb"),
          To_Unbounded_String (Root & "/src/platform/unsupported/files-platform-macos-trash.adb"),
          To_Unbounded_String (Root & "/src/platform/unsupported/files-platform-macos-volumes.adb")],
         "files platform-specific and unsupported fallback bodies must be present");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-platform.ads",
         "function Current_API_Profile return Files.File_System.Native_Platform_API_Profile;",
         "platform namespace must expose the current host native API profile");
      Project_Tools.Files.Require_Contains
        (Root & "/src/files-platform.adb",
         "return Files.File_System.Native_Platform_API_Profile_For (Files.File_System.Native_Adapter_Linux);",
         "current platform profile must delegate to the host adapter profile");
      Project_Tools.Files.Require_Contains
        (Root & "/files.gpr",
         "src/platform/windows",
         "files.gpr must select Windows platform bodies for Windows targets");
      Project_Tools.Files.Require_Contains
        (Root & "/files.gpr",
         "src/platform/macos",
         "files.gpr must select macOS platform bodies for macOS targets");
      Project_Tools.Files.Require_Contains
        (Root & "/files.gpr",
         "src/platform/unsupported",
         "files.gpr must select unsupported fallback bodies for other targets");
      Project_Tools.Files.Require_Contains
        (Root & "/src/platform/windows/files-platform-windows-trash.adb",
         "External_Name => ""SHFileOperationW""",
         "Windows trash body must bind to the native recycle-bin API");
      Project_Tools.Files.Require_Contains
        (Root & "/src/platform/windows/files-platform-windows-volumes.adb",
         "External_Name => ""GetVolumeInformationW""",
         "Windows volume body must bind to the native volume-label API");
      Project_Tools.Files.Require_Contains
        (Root & "/src/platform/windows/files-platform-windows-volumes.adb",
         "External_Name => ""GetDiskFreeSpaceExW""",
         "Windows volume body must bind to the native volume-capacity API");
      Project_Tools.Files.Require_Contains
        (Root & "/src/platform/macos/files-platform-macos-trash.adb",
         "External_Name => ""FSPathMoveObjectToTrashSync""",
         "macOS trash body must bind to the native trash API");
      Project_Tools.Files.Require_Contains
        (Root & "/src/platform/macos/files-platform-macos-trash.adb",
         "Pointer : in out Interfaces.C.Strings.chars_ptr",
         "macOS trash body must centralize guarded C-string cleanup");
      Project_Tools.Files.Require_Contains
        (Root & "/src/platform/macos/files-platform-macos-trash.adb",
         "Interfaces.C.Strings.Free (Pointer);" & ASCII.LF
         & "         exception" & ASCII.LF
         & "            when others =>" & ASCII.LF
         & "               null;",
         "macOS trash C-string cleanup must not raise while reporting native failures");
      Project_Tools.Files.Require_Contains
        (Root & "/src/platform/macos/files-platform-macos-volumes.adb",
         "External_Name => ""statfs""",
         "macOS volume body must bind to statfs");
      Project_Tools.Files.Require_Contains
        (Root & "/src/platform/unsupported/files-platform-windows-trash.adb",
         "Native_API_Not_Target",
         "unsupported Windows trash fallback must report not-target status");
      Project_Tools.Files.Require_Contains
        (Root & "/src/platform/unsupported/files-platform-macos-trash.adb",
         "Native_API_Not_Target",
         "unsupported macOS trash fallback must report not-target status");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Linux native profile identifies adapter",
         "platform tests must cover Linux native adapter identity");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Linux native profile marks current target",
         "platform tests must cover current-target native adapter metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Linux native profile follows volume capability binding status",
         "platform tests must cover Linux volume binding status");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Linux native profile records volume binding unit",
         "platform tests must cover Linux volume binding unit metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "platform current API profile follows the host adapter",
         "platform tests must cover current API profile adapter routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "platform current API profile follows host volume status",
         "platform tests must cover current API profile volume routing");
      Project_Tools.Files.Require_Contains
        (Tests,
         "platform current API profile exposes host binding unit",
         "platform tests must cover current API profile binding unit metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Windows native profile is not active on this target",
         "platform tests must cover Windows non-target native status");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Windows native profile records trash binding unit",
         "platform tests must cover Windows trash binding unit metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "Windows native profile records volume APIs",
         "platform tests must cover Windows native volume API metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "macOS native profile is not active on this target",
         "platform tests must cover macOS non-target native status");
      Project_Tools.Files.Require_Contains
        (Tests,
         "macOS native profile records required framework",
         "platform tests must cover macOS framework metadata");
      Project_Tools.Files.Require_Contains
        (Tests,
         "root volume capabilities name adapter",
         "platform tests must cover root volume adapter naming");
   end Check_Platform_Bodies;

   procedure Check_Packaging_Metadata is
      Stage : constant String := "/tmp/files_check_all_install_stage";

      procedure Require_Manifest_Entry
        (Path    : String;
         Message : String) is
         Manifest : constant String := Root & "/share/files/package.manifest";
         Content  : constant String := To_String (Project_Tools.Text.Read_Text_File (Manifest));
         Found    : Boolean := False;

         procedure Check_Line (Raw : String) is
         begin
            if Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both) = Path then
               Found := True;
            end if;
         end Check_Line;
      begin
         if Content /= "" then
            declare
               Line_Start : Positive := Content'First;
            begin
               for Index in Content'Range loop
                  if Content (Index) = ASCII.LF then
                     Check_Line (Content (Line_Start .. Index - 1));
                     Line_Start := Index + 1;
                  end if;
               end loop;

               if Line_Start <= Content'Last then
                  Check_Line (Content (Line_Start .. Content'Last));
               end if;
            end;
         end if;

         if not Found then
            Put_Line (Standard_Error, Message);
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         end if;
      end Require_Manifest_Entry;

      procedure Require_Share_Files_In_Manifest (Path : String) is
         Search    : Ada.Directories.Search_Type;
         Dir_Entry : Ada.Directories.Directory_Entry_Type;
         Started   : Boolean := False;
      begin
         if not Project_Tools.Files.Directory_Exists (Path) then
            return;
         end if;

         Ada.Directories.Start_Search
           (Search,
            Directory => Path,
            Pattern   => "*",
            Filter    =>
              [Ada.Directories.Ordinary_File => True,
              Ada.Directories.Directory     => True,
              Ada.Directories.Special_File  => False]);
         Started := True;

         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
            declare
               Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
               Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
            begin
               if Name = "." or else Name = ".." then
                  null;
               elsif Ada.Directories.Kind (Dir_Entry) = Ada.Directories.Directory then
                  Require_Share_Files_In_Manifest (Full);
               elsif Starts_With (Full, Root & "/") then
                  declare
                     Relative : constant String :=
                       Full (Full'First + Root'Length + 1 .. Full'Last);
                  begin
                     Require_Manifest_Entry
                       (Relative,
                        "files package manifest must include share resource: " & Relative);
                  end;
               end if;
            end;
         end loop;

         Ada.Directories.End_Search (Search);
         Started := False;
      exception
         when others =>
            if Started then
               Ada.Directories.End_Search (Search);
            end if;
            raise;
      end Require_Share_Files_In_Manifest;

      procedure Check_Manifest_Entries is
         package Manifest_Path_Sets is new Ada.Containers.Indefinite_Hashed_Sets
           (Element_Type        => String,
            Hash                => Ada.Strings.Hash,
            Equivalent_Elements => "=");

         Manifest : constant String := Root & "/share/files/package.manifest";
         Content  : constant String := To_String (Project_Tools.Text.Read_Text_File (Manifest));
         Seen     : Manifest_Path_Sets.Set;

         procedure Check_Line (Raw : String) is
            Manifest_Path : constant String := Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
         begin
            if Manifest_Path = "" or else Starts_With (Manifest_Path, "#") then
               return;
            elsif Starts_With (Manifest_Path, "/") or else Contains (Manifest_Path, "..") then
               Put_Line
                 (Standard_Error,
                  Manifest & ": unsafe packaged resource path: " & Manifest_Path);
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            elsif Seen.Contains (Manifest_Path) then
               Put_Line
                 (Standard_Error,
                  Manifest & ": duplicate packaged resource path: " & Manifest_Path);
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;

            Seen.Insert (Manifest_Path);

            if Manifest_Path = "bin/files" then
               return;
            elsif not Project_Tools.Files.File_Exists (Root & "/" & Manifest_Path) then
               Put_Line
                 (Standard_Error,
                  Manifest & ": missing packaged resource: " & Manifest_Path);
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end Check_Line;
      begin
         if Content = "" then
            return;
         end if;

         declare
            Line_Start : Positive := Content'First;
         begin
            for Index in Content'Range loop
               if Content (Index) = ASCII.LF then
                  Check_Line (Content (Line_Start .. Index - 1));
                  Line_Start := Index + 1;
               end if;
            end loop;

            if Line_Start <= Content'Last then
               Check_Line (Content (Line_Start .. Content'Last));
            end if;
         end;
      end Check_Manifest_Entries;

      procedure Copy_Share_Tree
        (From_Path : String;
         To_Path   : String)
      is
         Search    : Ada.Directories.Search_Type;
         Dir_Entry : Ada.Directories.Directory_Entry_Type;
         Started   : Boolean := False;
      begin
         if not Project_Tools.Files.Directory_Exists (From_Path) then
            return;
         end if;

         Ada.Directories.Create_Path (To_Path);
         Ada.Directories.Start_Search
           (Search,
            Directory => From_Path,
            Pattern   => "*",
            Filter    =>
              [Ada.Directories.Ordinary_File => True,
              Ada.Directories.Directory     => True,
              Ada.Directories.Special_File  => False]);
         Started := True;

         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
            declare
               Name        : constant String := Ada.Directories.Simple_Name (Dir_Entry);
               Source_Path : constant String := Ada.Directories.Full_Name (Dir_Entry);
               Target_Path : constant String := To_Path & "/" & Name;
            begin
               if Name = "." or else Name = ".." then
                  null;
               elsif Ada.Directories.Kind (Dir_Entry) = Ada.Directories.Directory then
                  Copy_Share_Tree (Source_Path, Target_Path);
               else
                  Ada.Directories.Copy_File (Source_Path, Target_Path);
               end if;
            end;
         end loop;

         Ada.Directories.End_Search (Search);
         Started := False;
      exception
         when others =>
            if Started then
               Ada.Directories.End_Search (Search);
            end if;
            raise;
      end Copy_Share_Tree;

      procedure Check_Staged_Manifest_Entries is
         Manifest : constant String := Root & "/share/files/package.manifest";
         Content  : constant String := To_String (Project_Tools.Text.Read_Text_File (Manifest));

         procedure Check_Line (Raw : String) is
            Manifest_Path : constant String := Ada.Strings.Fixed.Trim (Raw, Ada.Strings.Both);
         begin
            if Manifest_Path = ""
              or else Starts_With (Manifest_Path, "#")
              or else Manifest_Path = "bin/files"
            then
               return;
            elsif Starts_With (Manifest_Path, "share/")
              and then not Project_Tools.Files.File_Exists (Stage & "/" & Manifest_Path)
            then
               Put_Line
                 (Standard_Error,
                  "staged install is missing manifest resource: " & Manifest_Path);
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end Check_Line;
      begin
         if Content = "" then
            return;
         end if;

         declare
            Line_Start : Positive := Content'First;
         begin
            for Index in Content'Range loop
               if Content (Index) = ASCII.LF then
                  Check_Line (Content (Line_Start .. Index - 1));
                  Line_Start := Index + 1;
               end if;
            end loop;

            if Line_Start <= Content'Last then
               Check_Line (Content (Line_Start .. Content'Last));
            end if;
         end;
      end Check_Staged_Manifest_Entries;
   begin
      Project_Tools.Files.Require_Files
        ([To_Unbounded_String (Root & "/share/applications/files.desktop"),
          To_Unbounded_String (Root & "/share/icons/hicolor/scalable/apps/files.svg"),
          To_Unbounded_String (Root & "/share/metainfo/dk.bracke.files.metainfo.xml"),
          To_Unbounded_String (Root & "/share/doc/files/quick-start.md"),
          To_Unbounded_String (Root & "/share/doc/files/settings-format.md"),
          To_Unbounded_String (Root & "/share/doc/files/platform-support.md"),
          To_Unbounded_String (Root & "/share/doc/files/release-notes.md"),
          To_Unbounded_String (Root & "/share/files/package.manifest")],
         "files desktop packaging metadata must be present");
      Project_Tools.Files.Require_Contains
        (Root & "/files.gpr",
         "for Artifacts (""."") use (""share"");",
         "files install artifacts must include the share resource tree");
      Project_Tools.Files.Require_Contains
        (Root & "/share/applications/files.desktop",
         "Type=Application",
         "files desktop entry must declare an application entry type");
      Project_Tools.Files.Require_Contains
        (Root & "/share/doc/files/quick-start.md",
         "`Control+A` selects every visible item.",
         "quick-start guide must document the select-all shortcut");
      Project_Tools.Files.Require_Contains
        (Root & "/share/doc/files/platform-support.md",
         "Ada drop event-source",
         "platform support documentation must record drop event-source support");
      Project_Tools.Files.Require_Contains
        (Root & "/share/doc/files/platform-support.md",
         "Ada accessibility bridge",
         "platform support documentation must record accessibility bridge support");
      Project_Tools.Files.Require_Contains
        (Root & "/share/applications/files.desktop",
         "MimeType=inode/directory;",
         "files desktop entry must register directory opening");
      Project_Tools.Files.Require_Contains
        (Root & "/share/applications/files.desktop",
         "Name=Files",
         "files desktop entry must keep the packaged application name");
      Project_Tools.Files.Require_Contains
        (Root & "/share/applications/files.desktop",
         "Comment=Browse and open local files",
         "files desktop entry must keep the packaged application summary");
      Project_Tools.Files.Require_Contains
        (Root & "/share/applications/files.desktop",
         "Exec=files %F",
         "files desktop entry must pass file paths to the executable");
      Project_Tools.Files.Require_Contains
        (Root & "/share/applications/files.desktop",
         "Icon=files",
         "files desktop entry must use the installed application icon");
      Project_Tools.Files.Require_Contains
        (Root & "/share/applications/files.desktop",
         "Terminal=false",
         "files desktop entry must not launch in a terminal");
      Project_Tools.Files.Require_Contains
        (Root & "/share/applications/files.desktop",
         "Categories=System;FileManager;",
         "files desktop entry must expose file-manager categories");
      Project_Tools.Files.Require_Contains
        (Root & "/share/applications/files.desktop",
         "Keywords=file;folder;directory;manager;explorer;",
         "files desktop entry must expose launcher search keywords");
      Project_Tools.Files.Require_Contains
        (Root & "/share/applications/files.desktop",
         "StartupNotify=true",
         "files desktop entry must request startup notification");
      Project_Tools.Files.Require_Contains
        (Root & "/share/icons/hicolor/scalable/apps/files.svg",
         "<svg xmlns=""http://www.w3.org/2000/svg"" viewBox=""0 0 64 64"">",
         "files application icon must be a scalable SVG with the expected viewbox");
      Project_Tools.Files.Require_Contains
        (Root & "/share/icons/hicolor/scalable/apps/files.svg",
         "fill=""#2d7dd2""",
         "files application icon must retain the blue folder body");
      Project_Tools.Files.Require_Contains
        (Root & "/share/icons/hicolor/scalable/apps/files.svg",
         "fill=""#62b7f0""",
         "files application icon must retain the blue folder tab accent");
      Project_Tools.Files.Require_Contains
        (Root & "/share/icons/hicolor/scalable/apps/files.svg",
         "stroke=""#b9e2ff""",
         "files application icon must retain visible blue folder highlight strokes");
      Project_Tools.Files.Require_Contains
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<?xml version=""1.0"" encoding=""UTF-8""?>",
         "files AppStream metadata must declare UTF-8 XML");
      Project_Tools.Files.Require_Contains
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<component type=""desktop-application"">",
         "files AppStream metadata must declare a desktop application component");
      Project_Tools.Files.Require_Contains
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<launchable type=""desktop-id"">files.desktop</launchable>",
         "files AppStream metadata must reference the desktop entry");
      Project_Tools.Files.Require_Contains
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<id>dk.bracke.files</id>",
         "files AppStream metadata must keep the stable application id");
      Project_Tools.Files.Require_Contains
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<metadata_license>MIT</metadata_license>",
         "files AppStream metadata must declare the metadata license");
      Project_Tools.Files.Require_Contains
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<project_license>MIT OR Apache-2.0 WITH LLVM-exception</project_license>",
         "files AppStream metadata must declare the project license");
      Project_Tools.Files.Require_Contains
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<name>Files</name>",
         "files AppStream metadata must match the desktop application name");
      Project_Tools.Files.Require_Contains
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<summary>Browse and open local files</summary>",
         "files AppStream metadata must match the desktop application summary");
      Project_Tools.Files.Require_Contains
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<p>Files is an Ada desktop file explorer for local directories.</p>",
         "files AppStream metadata must describe the packaged application");
      Project_Tools.Files.Require_Contains
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<category>System</category>",
         "files AppStream metadata must expose the System category");
      Project_Tools.Files.Require_Contains
        (Root & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<category>FileManager</category>",
         "files AppStream metadata must expose the FileManager category");
      Require_Manifest_Entry
        ("bin/files",
         "files package manifest must include the executable");
      Require_Manifest_Entry
        ("share/applications/files.desktop",
         "files package manifest must include the desktop entry");
      Require_Manifest_Entry
        ("share/icons/hicolor/scalable/apps/files.svg",
         "files package manifest must include the application icon");
      Require_Manifest_Entry
        ("share/metainfo/dk.bracke.files.metainfo.xml",
         "files package manifest must include AppStream metadata");
      Require_Manifest_Entry
        ("share/doc/files/quick-start.md",
         "files package manifest must include quick-start documentation");
      Require_Manifest_Entry
        ("share/doc/files/settings-format.md",
         "files package manifest must include settings format documentation");
      Require_Manifest_Entry
        ("share/doc/files/platform-support.md",
         "files package manifest must include platform support documentation");
      Require_Manifest_Entry
        ("share/doc/files/release-notes.md",
         "files package manifest must include release notes");
      Require_Manifest_Entry
        ("share/files/package.manifest",
         "files package manifest must include the release manifest");
      Require_Manifest_Entry
        ("share/files.catalog",
         "files package manifest must include the localization catalog");
      Require_Manifest_Entry
        ("share/files/icons/folder.icon",
         "files package manifest must include bundled folder icon");
      Require_Manifest_Entry
        ("share/files/icons/text.icon",
         "files package manifest must include bundled text icon");
      Require_Manifest_Entry
        ("share/files/icons/image.icon",
         "files package manifest must include bundled image icon");
      Require_Manifest_Entry
        ("share/files/icons/executable.icon",
         "files package manifest must include bundled executable icon");
      Require_Manifest_Entry
        ("share/files/icons/link.icon",
         "files package manifest must include bundled link icon");
      Require_Manifest_Entry
        ("share/files/icons/unknown.icon",
         "files package manifest must include bundled unknown icon");
      Require_Manifest_Entry
        ("share/files/icons/ada.icon",
         "files package manifest must include bundled Ada icon");
      Require_Manifest_Entry
        ("share/files/icons/markdown.icon",
         "files package manifest must include bundled Markdown icon");
      Require_Manifest_Entry
        ("share/files/icons/high-contrast/folder.icon",
         "files package manifest must include high-contrast folder icon");
      Require_Manifest_Entry
        ("share/files/icons/high-contrast/text.icon",
         "files package manifest must include high-contrast text icon");
      Require_Manifest_Entry
        ("share/files/icons/high-contrast/image.icon",
         "files package manifest must include high-contrast image icon");
      Require_Manifest_Entry
        ("share/files/icons/high-contrast/executable.icon",
         "files package manifest must include high-contrast executable icon");
      Require_Manifest_Entry
        ("share/files/icons/high-contrast/link.icon",
         "files package manifest must include high-contrast link icon");
      Require_Manifest_Entry
        ("share/files/icons/high-contrast/unknown.icon",
         "files package manifest must include high-contrast unknown icon");
      Require_Manifest_Entry
        ("share/files/icons/high-contrast/ada.icon",
         "files package manifest must include high-contrast Ada icon");
      Require_Manifest_Entry
        ("share/files/icons/high-contrast/markdown.icon",
         "files package manifest must include high-contrast Markdown icon");
      Require_Share_Files_In_Manifest (Root & "/share");
      Check_Manifest_Entries;

      Project_Tools.Files.Delete_Tree (Stage);
      Copy_Share_Tree (Root & "/share", Stage & "/share");
      Check_Staged_Manifest_Entries;
      Project_Tools.Files.Require_Files
        ([To_Unbounded_String (Stage & "/share/applications/files.desktop"),
          To_Unbounded_String (Stage & "/share/icons/hicolor/scalable/apps/files.svg"),
          To_Unbounded_String (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml"),
          To_Unbounded_String (Stage & "/share/doc/files/quick-start.md"),
          To_Unbounded_String (Stage & "/share/doc/files/settings-format.md"),
          To_Unbounded_String (Stage & "/share/doc/files/platform-support.md"),
          To_Unbounded_String (Stage & "/share/doc/files/release-notes.md"),
          To_Unbounded_String (Stage & "/share/files/package.manifest"),
          To_Unbounded_String (Stage & "/share/files.catalog"),
          To_Unbounded_String (Stage & "/share/files/icons/folder.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/text.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/image.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/executable.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/link.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/unknown.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/ada.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/markdown.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/high-contrast/folder.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/high-contrast/text.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/high-contrast/image.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/high-contrast/executable.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/high-contrast/link.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/high-contrast/unknown.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/high-contrast/ada.icon"),
          To_Unbounded_String (Stage & "/share/files/icons/high-contrast/markdown.icon")],
         "files staged install must preserve desktop metadata and runtime resource paths");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "Type=Application",
         "files staged desktop entry must preserve application entry type");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "Exec=files %F",
         "files staged desktop entry must preserve path-opening executable contract");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "Name=Files",
         "files staged desktop entry must preserve the application name");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "Comment=Browse and open local files",
         "files staged desktop entry must preserve the application summary");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "Icon=files",
         "files staged desktop entry must preserve the application icon id");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "Terminal=false",
         "files staged desktop entry must preserve non-terminal launch behavior");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "MimeType=inode/directory;",
         "files staged desktop entry must preserve directory MIME registration");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "Categories=System;FileManager;",
         "files staged desktop entry must preserve file-manager categories");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "Keywords=file;folder;directory;manager;explorer;",
         "files staged desktop entry must preserve launcher search keywords");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/applications/files.desktop",
         "StartupNotify=true",
         "files staged desktop entry must preserve startup notification metadata");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/icons/hicolor/scalable/apps/files.svg",
         "<svg xmlns=""http://www.w3.org/2000/svg"" viewBox=""0 0 64 64"">",
         "files staged application icon must preserve SVG identity");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/icons/hicolor/scalable/apps/files.svg",
         "fill=""#2d7dd2""",
         "files staged application icon must preserve the folder body");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/icons/hicolor/scalable/apps/files.svg",
         "fill=""#62b7f0""",
         "files staged application icon must preserve the blue folder tab accent");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/icons/hicolor/scalable/apps/files.svg",
         "stroke=""#b9e2ff""",
         "files staged application icon must preserve blue folder highlight strokes");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<?xml version=""1.0"" encoding=""UTF-8""?>",
         "files staged AppStream metadata must preserve UTF-8 XML declaration");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<component type=""desktop-application"">",
         "files staged AppStream metadata must preserve desktop application component type");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<id>dk.bracke.files</id>",
         "files staged AppStream metadata must preserve the stable application id");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<metadata_license>MIT</metadata_license>",
         "files staged AppStream metadata must preserve the metadata license");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<project_license>MIT OR Apache-2.0 WITH LLVM-exception</project_license>",
         "files staged AppStream metadata must preserve the project license");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<name>Files</name>",
         "files staged AppStream metadata must preserve the application name");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<summary>Browse and open local files</summary>",
         "files staged AppStream metadata must preserve the application summary");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<p>Files is an Ada desktop file explorer for local directories.</p>",
         "files staged AppStream metadata must preserve the application description");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<launchable type=""desktop-id"">files.desktop</launchable>",
         "files staged AppStream metadata must preserve desktop launchability");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<category>System</category>",
         "files staged AppStream metadata must preserve system category metadata");
      Project_Tools.Files.Require_Contains
        (Stage & "/share/metainfo/dk.bracke.files.metainfo.xml",
         "<category>FileManager</category>",
         "files staged AppStream metadata must preserve file-manager category metadata");
      Project_Tools.Files.Delete_Tree (Stage);
   end Check_Packaging_Metadata;

begin
   if not Project_Tools.Files.File_Exists (Root & "/files.gpr") then
      Put_Line (Standard_Error, "check_all must be run from the files project root or tools directory");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Require_Command ("alr");

   Project_Tools.Files.Write_Text_File (Combined_Suite, Suite_Sources);

   Check_Line_Lengths;
   Check_Consecutive_Empty_Lines;
   Check_Whitespace;
   Check_GNATdoc_Comments;
   Check_Ada_Keyword_Identifiers;
   Check_AUnit_Test_Registration;
   Check_Ada_Only_Tooling;
   Check_Localization_Usage;
   Check_Filetype_Detection_Order;
   Check_Directory_Loading_Contract;
   Check_Command_Registry_Contract;
   Check_Command_Palette_Search_Contract;
   Check_Root_Selector_Contract;
   Check_Event_Translation_Contract;
   Check_Event_Hit_Test_Contract;
   Check_UI_Command_Hit_Test_Contract;
   Check_Controller_Command_Routing_Contract;
   Check_Model_State_Contract;
   Check_Crate_Structure;
   Check_Startup_Path_Contract;
   Check_Application_CLI_Surface;
   Check_Feature_Scope_Policy;
   Check_Open_Action_Shell_Safety;
   Check_Open_Action_Settings_Validation;
   Check_Open_Action_Placeholder_Contract;
   Check_Open_Action_Lookup_Contract;
   Check_Operations_Open_Action_Contract;
   Check_Settings_Serialization_Contract;
   Check_Settings_Editor_Contract;
   Check_Filesystem_Mutation_Safety;
   Check_Rendering_Architecture;
   Check_Icon_Accessibility_Contract;
   Check_Icon_Assets;
   Check_Platform_Bodies;
   Check_Packaging_Metadata;
   Check_CLDR_Importer;
   Run ("files build", Root, Alr, [1 => new String'("build")]);
   Check_Executable_CLI_Help;
   Check_Desktop_Runtime_Contract;
   Run ("top-level tests build", Root & "/tests", Alr, [1 => new String'("build")]);
   Run ("top-level AUnit tests", Root & "/tests", "./bin/tests", []);
   Run ("tests build", Root & "/tests/tests", Alr, [1 => new String'("build")]);
   Run ("AUnit tests", Root & "/tests/tests", "./bin/tests", []);

   Put_Line ("files project checks passed");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
exception
   when Program_Error =>
      null;
   when E : others =>
      Put_Line
        (Standard_Error,
         "files project checks failed: " & Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Check_All;
