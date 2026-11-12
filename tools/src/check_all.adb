with Ada.Command_Line;
with Ada.Characters.Handling;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Containers.Indefinite_Vectors;
with Ada.Directories;
with Ada.Exceptions;
with Ada.Strings.Fixed;
with Ada.Strings.Hash;
with Ada.Strings.Maps;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with GNAT.OS_Lib;

with Project_Tools.Ada_Source;
with Project_Tools.AUnit_Checks;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Text;
with Project_Tools.Tree_Checks;
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
   function Temp_Path (Name : String) return String is
      Image : constant String := Integer'Image
        (GNAT.OS_Lib.Pid_To_Integer (GNAT.OS_Lib.Current_Process_Id));
   begin
      return Project_Tools.Files.Temp_Dir & "/files-check-all-"
        & Image (Image'First + 1 .. Image'Last) & "-" & Name;
   end Temp_Path;
   --  The AUnit suite was split from one files_suite.adb into per-section
   --  bodies; contract checks search this combined snapshot so an assertion
   --  may live in any section. Written once at startup (see main body).
   Combined_Suite : constant String := Temp_Path ("combined-suite.txt");
   Alr  : constant String := Project_Tools.Processes.Locate_Command ("alr");

   procedure Cleanup_Temps is
   begin
      Project_Tools.Files.Delete_File_If_Present (Combined_Suite);
      Project_Tools.Files.Delete_File_If_Present (Temp_Path ("cldr.out"));
      Project_Tools.Files.Delete_File_If_Present (Temp_Path ("help-long.txt"));
      Project_Tools.Files.Delete_File_If_Present (Temp_Path ("help-short.txt"));
      Project_Tools.Files.Delete_File_If_Present (Temp_Path ("version.txt"));
      Project_Tools.Files.Delete_Tree (Temp_Path ("install-stage"));
   exception
      when others => null;
   end Cleanup_Temps;

   function Is_Text_Project_File (Name : String) return Boolean is
   begin
      return Name = ".gitignore"
        or else Ends_With (Name, ".adb")
        or else Ends_With (Name, ".ads")
        or else Ends_With (Name, ".gpr")
        or else Ends_With (Name, ".c")
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

   procedure Require_Alire_GNAT_15 is
      Output : Unbounded_String;
      Status : Integer;
   begin
      Status :=
        Project_Tools.Processes.Run_Status
          (Label   => "GNAT 15 version check",
           Dir     => Root,
           Program => Alr,
           Args    =>
             GNAT.OS_Lib.Argument_List'[1 => new String'("exec"),
              2 => new String'("--"),
              3 => new String'("gnatls"),
              4 => new String'("--version")],
           Output  => Output,
           Quiet   => True);

      if Status /= 0 then
         Put_Line
           (Standard_Error,
            "could not run `alr exec -- gnatls --version`");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      elsif Ada.Strings.Fixed.Index (To_String (Output), "GNATLS 15.") = 0 then
         Put_Line
           (Standard_Error,
            "wrong Ada compiler: files validation must use Alire GNAT 15; got: "
            & To_String (Output));
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
   end Require_Alire_GNAT_15;

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
   --  Every suite body, subunits included: a test moved into its own
   --  files_suite-<suite>-test_<name>.adb must still count.
   function Suite_Sources return String is
      Dir    : constant String := Root & "/tests/tests/src";
      Result : Unbounded_String;
      Search : Ada.Directories.Search_Type;
      Found  : Ada.Directories.Directory_Entry_Type;
   begin
      Ada.Directories.Start_Search
        (Search, Dir, "files_suite*.adb", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Found);
         Append (Result, Project_Tools.Text.Read_Text_File (Ada.Directories.Full_Name (Found)));
         Append (Result, ASCII.LF);
      end loop;
      Ada.Directories.End_Search (Search);
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
         Output_Path     => Temp_Path ("cldr.out"),
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
      Check_Line_Lengths_In_File (Root & "/files.gpr");
      Check_Line_Lengths_In_File (Root & "/tests/tests.gpr");
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
      Check_Consecutive_Empty_Lines_In_File (Root & "/files.gpr");
      Check_Consecutive_Empty_Lines_In_File (Root & "/tests/tests.gpr");
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
      Check_Whitespace_In_File (Root & "/files.gpr");
      Check_Whitespace_In_File (Root & "/tests/tests.gpr");
      Check_Whitespace_In_File (Root & "/tools/alire.toml");
      Check_Whitespace_In_File (Root & "/tools/files_check_all.gpr");
   end Check_Whitespace;

   procedure Check_GNATdoc_In_File (Path : String) is
   begin
      Project_Tools.Ada_Source.Require_Public_GNATdoc_Tags (Path);
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

   --  Every test package is in the suite, and every Test_* routine a suite
   --  body declares is registered there: a declared, stubbed and written
   --  test that nobody registers compiles cleanly and never runs.
   --  Require that the suite registers Routine. Only the registration is
   --  checked -- what the routine asserts is not -- so Message says what the
   --  routine is the test of, for a failure to name, and claims nothing more.
   --  Keyed to the routine's name, not to the text of an assertion message
   --  inside it: rewording a message does not break the guard, and a routine
   --  that is dropped or no longer registered does.
   --  (Check_AUnit_Test_Registration separately requires every declared
   --  routine to be registered.)
   --
   --  @param Routine Test procedure name, as registered with 'Access.
   --  @param Message What the routine tests, as a noun phrase.
   --  Text with its Ada comments removed (a "--" outside a string literal
   --  to the end of its line), so a registration that is only mentioned in a
   --  comment, or commented out, does not count as one. With Blank_Strings
   --  the contents of string literals are spaces too, their quotes kept.
   function Code_Of (Text : String; Blank_Strings : Boolean := False) return String is
      Result    : String (Text'Range);
      Last      : Natural := Text'First - 1;
      In_String : Boolean := False;
      Index     : Positive := Text'First;
   begin
      while Index <= Text'Last loop
         --  A character literal ('"', '-') is copied whole: its quote is not a
         --  string's, its dash not a comment's.
         if not In_String
           and then Text (Index) = '''
           and then Index + 2 <= Text'Last
           and then Text (Index + 2) = '''
         then
            Result (Last + 1 .. Last + 3) := Text (Index .. Index + 2);
            Last := Last + 3;
            Index := Index + 3;
            goto Next;
         end if;
         if Text (Index) = ASCII.LF then
            In_String := False;
         elsif Text (Index) = '"' then
            In_String := not In_String;
         elsif not In_String
           and then Text (Index) = '-'
           and then Index < Text'Last
           and then Text (Index + 1) = '-'
           --  A character literal '-' followed by '-' is not a comment.
           and then not (Index > Text'First and then Text (Index - 1) = ''')
         then
            while Index <= Text'Last and then Text (Index) /= ASCII.LF loop
               Index := Index + 1;
            end loop;
            exit when Index > Text'Last;
         end if;
         Last := Last + 1;
         --  A string's contents blanked, its quotes kept: text in a message
         --  neither satisfies nor trips a check of code.
         Result (Last) :=
           (if Blank_Strings and then In_String and then Text (Index) /= '"' then ' ' else Text (Index));
         Index := Index + 1;
         <<Next>>
      end loop;
      return Result (Text'First .. Last);
   end Code_Of;

   --  Whether a pattern spells a string literal: one that does is looked
   --  for in code with its strings kept, every other one with them blanked.
   function Quotes (Pattern : String) return Boolean is
     (Ada.Strings.Fixed.Index (Pattern, """") > 0);

   --  Require the sources in src/ whose names start with Prefix (".ads" and
   --  ".adb": a unit, its children and subunits) to name nothing from
   --  Package_Name but Allowed: qualified (Files.Folder_Size.Cancel) or not
   --  (Folder_Size.Cancel, legal in a child of Files), comments ignored, and
   --  never through a use clause or a renaming of the package, which would
   --  let a name go unqualified. An allow-list: a new name is caught without
   --  being listed.
   procedure Require_Only_Names_From
     (Prefix       : String;
      Package_Name : String;
      Allowed      : String_List;
      Message      : String;
      Short_Too    : Boolean := True)
   is
      Short  : constant String :=
        Package_Name (Ada.Strings.Fixed.Index (Package_Name, ".", Ada.Strings.Backward) + 1 .. Package_Name'Last);
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;

      function Identifier_Char (C : Character) return Boolean is
        (C in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_');

      procedure Refuse (Path, What : String) is
      begin
         Put_Line (Standard_Error, Path & ": " & Message & " (" & What & ")");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Refuse;

      procedure Check (Path : String) is
         Code : constant String :=
           Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => True);
         From : Positive := Code'First;
         At_Name : Natural;
      begin
         --  In full, or by the short name a child of the parent may use
         --  ("use Process_Jobs;", "package PJ renames Process_Jobs;").
         if Ada.Strings.Fixed.Index (Code, "use " & Package_Name) > 0
           or else Ada.Strings.Fixed.Index (Code, "renames " & Package_Name) > 0
           or else (Short_Too and then
                    (for some Tail of String_List'[To_Unbounded_String (";"), To_Unbounded_String (",")] =>
                      Ada.Strings.Fixed.Index (Code, "use " & Short & To_String (Tail)) > 0
                      or else Ada.Strings.Fixed.Index (Code, "renames " & Short & To_String (Tail)) > 0))
         then
            Refuse (Path, "uses or renames " & Package_Name);
         end if;
         loop
            At_Name := Ada.Strings.Fixed.Index (Code (From .. Code'Last), Short & ".");
            exit when At_Name = 0;
            declare
               First : constant Positive := At_Name + Short'Length + 1;
               Last  : Natural := First - 1;
               Parent : constant String := Package_Name (Package_Name'First .. Package_Name'Last - Short'Length);
               --  Standing alone: not the tail of a longer identifier or of
               --  another package's name.
               function Alone (Position : Positive) return Boolean is
                 (Position = Code'First
                  or else (not Identifier_Char (Code (Position - 1)) and then Code (Position - 1) /= '.'));
               --  Package_Name in full (Files.Folder_Size.), or the short
               --  name alone (Folder_Size.).
               Relevant : constant Boolean :=
                 (Short_Too and then Alone (At_Name))
                 or else (At_Name - Code'First >= Parent'Length
                          and then Code (At_Name - Parent'Length .. At_Name - 1) = Parent
                          and then Alone (At_Name - Parent'Length));
            begin
               while Last < Code'Last and then Identifier_Char (Code (Last + 1)) loop
                  Last := Last + 1;
               end loop;
               if Relevant
                 and then Last >= First
                 and then not (for some Name of Allowed => To_String (Name) = Code (First .. Last))
               then
                  Refuse (Path, Package_Name & "." & Code (First .. Last));
               end if;
               From := Natural'Max (Last, At_Name) + 1;
            end;
         end loop;
      end Check;
   begin
      Ada.Directories.Start_Search
        (Search, Root & "/src", Prefix & "*", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Item);
         begin
            if Ends_With (Name, ".ads") or else Ends_With (Name, ".adb") then
               Check (Ada.Directories.Full_Name (Item));
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   end Require_Only_Names_From;

   procedure Require_Registered_Routine (Routine : String; Message : String) is
      Code : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Combined_Suite)));
   begin
      if Ada.Strings.Fixed.Index (Code, "(T, " & Routine & "'Access") = 0 then
         Put_Line (Standard_Error, Routine & ", " & Message & ", must stay registered");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
   end Require_Registered_Routine;

   procedure Check_AUnit_Test_Registration is
      Search : Ada.Directories.Search_Type;
      Found  : Ada.Directories.Directory_Entry_Type;
   begin
      Project_Tools.AUnit_Checks.Require_Registered_Test_Packages
        (Test_Dir         => Root & "/tests/tests/src",
         Spec_Pattern     => "files_suite-*.ads",
         Suite_Path       => Root & "/tests/tests/src/files_suite.adb",
         Suite_Add_Prefix => "Result.Add_Test (",
         Suite_Add_Suffix => ".Suite)",
         Section_Marker   => "function Suite");
      Ada.Directories.Start_Search
        (Search, Root & "/tests/tests/src", "files_suite-*.adb",
         [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Found);
         declare
            Path    : constant String := Ada.Directories.Full_Name (Found);
            Content : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
            Prefix  : constant String := ASCII.LF & "   procedure Test_";
            From    : Natural := Content'First;
         begin
            if Ada.Strings.Fixed.Index (Content, "procedure Register_Tests") > 0 then
               loop
                  declare
                     At_Decl : constant Natural := Ada.Strings.Fixed.Index (Content (From .. Content'Last), Prefix);
                  begin
                     exit when At_Decl = 0;
                     declare
                        Name_First : constant Positive := At_Decl + Prefix'Length - 5;
                        Name_Last  : Natural := Name_First;
                     begin
                        while Name_Last < Content'Last
                          and then Content (Name_Last + 1) in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_'
                        loop
                           Name_Last := Name_Last + 1;
                        end loop;
                        if Ada.Strings.Fixed.Index (Content, Content (Name_First .. Name_Last) & "'Access") = 0 then
                           Put_Line
                             (Standard_Error,
                              Path & ": " & Content (Name_First .. Name_Last) & " is declared but never registered");
                           Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
                           raise Program_Error;
                        end if;
                        From := Name_Last + 1;
                     end;
                  end;
               end loop;
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   end Check_AUnit_Test_Registration;

   function Has_Non_Ada_Tooling_Extension (Name : String) return Boolean is
      Lower_Name : constant String := Ada.Characters.Handling.To_Lower (Name);
   begin
      --  Python artifacts (.py/.pyc/__pycache__) are detected separately by
      --  Project_Tools.Tree_Checks.Check_No_Generated_Python; this scan covers
      --  the remaining non-Ada shell/script tooling extensions.
      return
        Ends_With (Lower_Name, ".sh")
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
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path, Form => "shared=no");
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
            --  The Python scan covers the source trees, not the root itself.
            if Ends_With (Ada.Characters.Handling.To_Lower (Name), ".py") then
               Put_Line (Standard_Error, Full & ": non-Ada helper tooling is not allowed");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
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
   end Check_Ada_Only_Tooling_At_Project_Root;

   procedure Check_Ada_Only_Tooling is
      Python_Errors : Natural := 0;

      procedure Scan_Python (Path : String) is
      begin
         if Project_Tools.Files.Directory_Exists (Path) then
            Project_Tools.Tree_Checks.Check_No_Generated_Python (Python_Errors, Path);
         end if;
      end Scan_Python;
   begin
      Check_Ada_Only_Tooling_At_Project_Root;
      Check_Ada_Only_Tooling_In_Tree (Root & "/config");
      Check_Ada_Only_Tooling_In_Tree (Root & "/scripts");
      Check_Ada_Only_Tooling_In_Tree (Root & "/src");
      Check_Ada_Only_Tooling_In_Tree (Root & "/tests");
      Check_Ada_Only_Tooling_In_Tree (Root & "/tools");
      Check_Ada_Only_Tooling_In_Tree (Root & "/share");
      Check_Ada_Only_Tooling_In_Tree (Root & "/.github");
      Check_Ada_Only_Tooling_In_Tree (Root & "/.claude");
      Check_Ada_Only_Tooling_In_Tree (Root & "/.config");

      --  Delegate Python-artifact detection to the shared tree check across the
      --  same source trees the inline scan covers.
      Scan_Python (Root & "/config");
      Scan_Python (Root & "/scripts");
      Scan_Python (Root & "/src");
      Scan_Python (Root & "/tests");
      Scan_Python (Root & "/tools");
      Scan_Python (Root & "/share");
      Scan_Python (Root & "/.github");
      Scan_Python (Root & "/.claude");
      Scan_Python (Root & "/.config");

      if Python_Errors > 0 then
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
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

      --  An absolute filesystem path is not prose. Font files force the point:
      --  "/System/Library/Fonts/Apple Color Emoji.ttc" is a name Apple chose,
      --  spaces and capitals and all, and there is nothing in it to translate.
      if Literal'Length > 1 and then Literal (Literal'First) = '/' then
         return False;
      end if;

      --  Shell verbs assembled into the terminal command line. They carry no
      --  metacharacter of their own -- "cd /d " is cmd's change-directory form,
      --  "cd " every POSIX shell's -- but they are shell syntax, not localizable
      --  user text.
      if Literal = "cd /d "
        or else Literal = "cd "
      then
         return False;
      end if;

      if Literal = "untitled "
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

   function Is_Ada_Identifier_Char (Char : Character) return Boolean is
     (Char in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_');

   --  The length of a developer-diagnostic pragma header ("pragma
   --  Compile_Time_Error" and friends) beginning at Content (From), or 0 when
   --  none does. Their string arguments are compile-time messages for
   --  developers, never localizable user text, so the scanner skips the whole
   --  statement. GNAT style enforces the casing, so an exact-case match suffices.
   function Diagnostic_Pragma_Length (Content : String; From : Positive) return Natural is
      function Header_At (Keyword : String) return Boolean is
         Full : constant String := "pragma " & Keyword;
         Stop : constant Natural := From + Full'Length;
      begin
         if From > Content'First and then Is_Ada_Identifier_Char (Content (From - 1)) then
            return False;
         elsif Stop - 1 > Content'Last then
            return False;
         elsif Content (From .. Stop - 1) /= Full then
            return False;
         end if;

         return Stop > Content'Last or else not Is_Ada_Identifier_Char (Content (Stop));
      end Header_At;
   begin
      if Header_At ("Compile_Time_Error") then
         return String'("pragma Compile_Time_Error")'Length;
      elsif Header_At ("Compile_Time_Warning") then
         return String'("pragma Compile_Time_Warning")'Length;
      elsif Header_At ("Assert") then
         return String'("pragma Assert")'Length;
      end if;

      return 0;
   end Diagnostic_Pragma_Length;

   procedure Check_No_User_Text_Literals (Path : String) is
      Content       : constant String := To_String (Project_Tools.Text.Read_Text_File (Path));
      Index         : Natural := Content'First;
      Line          : Natural := 1;

      --  Advance Index past the developer-diagnostic pragma statement that begins
      --  at Index, tracking parenthesis depth so a ';' inside its message string
      --  does not end it early, and counting newlines for accurate line numbers.
      procedure Skip_Diagnostic_Pragma is
         Depth : Integer := 0;
      begin
         while Index <= Content'Last loop
            if Content (Index) = ASCII.LF then
               Line := Line + 1;
               Index := Index + 1;
            elsif Content (Index) = '"' then
               Index := Index + 1;
               while Index <= Content'Last loop
                  if Content (Index) = '"' then
                     if Index < Content'Last and then Content (Index + 1) = '"' then
                        Index := Index + 2;
                     else
                        Index := Index + 1;
                        exit;
                     end if;
                  else
                     if Content (Index) = ASCII.LF then
                        Line := Line + 1;
                     end if;
                     Index := Index + 1;
                  end if;
               end loop;
            elsif Content (Index) = '(' then
               Depth := Depth + 1;
               Index := Index + 1;
            elsif Content (Index) = ')' then
               Depth := Depth - 1;
               Index := Index + 1;
            elsif Content (Index) = ';' and then Depth = 0 then
               Index := Index + 1;
               exit;
            else
               Index := Index + 1;
            end if;
         end loop;
      end Skip_Diagnostic_Pragma;
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
         elsif Diagnostic_Pragma_Length (Content, Index) > 0 then
            Skip_Diagnostic_Pragma;
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
         "en.root.detail = ",
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
         "en.info.extra.directory.count = ",
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

   --  Which host this is, is asked of Hostkit.Host.Current: the build's OS
   --  string spelled the same question a second way, and the code around each
   --  spelling drifted (a separator rule here, a path rule there).
   procedure Check_Host_Questions is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
   begin
      Ada.Directories.Start_Search
        (Search, Root & "/src", "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Path : constant String := Ada.Directories.Full_Name (Item);
            Code : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
         begin
            if Ada.Strings.Fixed.Index (Code, "Alire_Host_OS") > 0 then
               Ada.Directories.End_Search (Search);
               Put_Line (Standard_Error, Path & ": asks the build's OS string; use Hostkit.Host.Current");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   end Check_Host_Questions;

   --  Thumbnails are made on the refresh tasks and on the UI thread at once,
   --  and images are decoded there and on the Quick Look decoder's task. A
   --  variable at the package level is shared by them, unguarded: one held
   --  the path being written and was overwritten mid-write. State belongs in
   --  the subprogram, or in a protected object.
   procedure Check_Shared_Package_State is
      package Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type => String, Hash => Ada.Strings.Hash, Equivalent_Elements => "=");
      Checked : Name_Sets.Set;

      procedure Check (Path : String) is
         Code  : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
         Start : Positive := Code'First;
      begin
         --  A subprogram's subunit declares only its own locals (its with
         --  clauses, if any, come before the separate).
         if Ada.Strings.Fixed.Index (Code, "separate (") > 0
           and then Ada.Strings.Fixed.Index (Code, "package body") = 0
         then
            return;
         end if;
         for Index in Code'Range loop
            if Code (Index) = ASCII.LF or else Index = Code'Last then
               declare
                  Line  : constant String := Code (Start .. (if Code (Index) = ASCII.LF then Index - 1 else Index));
                  Colon : constant Natural := Ada.Strings.Fixed.Index (Line, ":");
               begin
                  --  An object declared at the package's own level: three
                  --  spaces, a name, a colon, and no constant, exception or
                  --  renaming.
                  if Line'Length > 4
                    and then Line (Line'First .. Line'First + 2) = "   "
                    and then Line (Line'First + 3) in 'A' .. 'Z'
                    and then Colon > 0
                    and then (for all C of Line (Line'First + 3 .. Colon - 1) =>
                                C in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | ' ' | ',')
                    and then Ada.Strings.Fixed.Index (Line, "constant") = 0
                    and then Ada.Strings.Fixed.Index (Line, "exception") = 0
                    and then Ada.Strings.Fixed.Index (Line, "renames") = 0
                    and then Ada.Strings.Fixed.Index (Line, ":=") /= Colon
                  then
                     Put_Line
                       (Standard_Error,
                        Path & ": a package-level variable is shared by every task that runs this code: "
                        & Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both));
                     Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
                     raise Program_Error;
                  end if;
               end;
               Start := Index + 1;
            end if;
         end loop;
      end Check;

      procedure Check_All (Pattern : String) is
         Search : Ada.Directories.Search_Type;
         Item   : Ada.Directories.Directory_Entry_Type;
         Found  : Boolean := False;
      begin
         Ada.Directories.Start_Search
           (Search, Root & "/src", Pattern, [Ada.Directories.Ordinary_File => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            Found := True;
            Check (Ada.Directories.Full_Name (Item));
            Checked.Include (Ada.Directories.Simple_Name (Item));
         end loop;
         Ada.Directories.End_Search (Search);
         if not Found then
            Put_Line (Standard_Error, "src/" & Pattern & ": no source matches; update Check_Shared_Package_State");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         end if;
      end Check_All;
   begin
      Check_All ("files-file_system-thumbnails.ad?");
      Check_All ("files-images*.ad?");
      Check_All ("files-preview_decoder.ad?");
      --  The worker tasks of Files.Background_Slots, and the readers the
      --  info pane's worker runs.
      Check_All ("files-background_slots.ad?");
      Check_All ("files-extra_info_reader.ad?");
      Check_All ("files-file_system-*_info.adb");
      Check_All ("files-file_system-extra_info_of.adb");
      Check_All ("files-extra_info.ads");
      Check_All ("files-file_system-count_text_lines.adb");
      Check_All ("files-file_system-text_encoding_name.adb");
      --  Its worker runs a tree walk on a large stack while the caller waits.
      Check_All ("files-file_system-support.adb");

      --  Every unit that runs a task of its own is checked above, or says
      --  here why its package-level variables are not shared with the task.
      declare
         Search : Ada.Directories.Search_Type;
         Item   : Ada.Directories.Directory_Entry_Type;
         Main_Thread_State : constant Name_Sets.Set :=
           Name_Sets.Union
             --  Reaper is set and read by Ensure_Reaper and Shutdown only, on
             --  the thread that starts jobs; the reaper task touches neither.
             (Name_Sets.To_Set ("files-process_jobs.adb"),
              --  The monitor task reads the report label from a protected
              --  object and the report folder from the environment; the
              --  package's report variables are Scavenge's and Clean_Report's.
              Name_Sets.To_Set ("files-job_scavenger.adb"));
      begin
         Ada.Directories.Start_Search
           (Search, Root & "/src", "*.adb", [Ada.Directories.Ordinary_File => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            if Ada.Strings.Fixed.Index
                 (Code_Of (To_String (Project_Tools.Text.Read_Text_File (Ada.Directories.Full_Name (Item)))),
                  "task body") > 0
              and then not Checked.Contains (Ada.Directories.Simple_Name (Item))
              and then not Main_Thread_State.Contains (Ada.Directories.Simple_Name (Item))
            then
               Put_Line
                 (Standard_Error,
                  "src/" & Ada.Directories.Simple_Name (Item) & " runs a task: add it to Check_Shared_Package_State,"
                  & " or say there why its package state is not shared");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end loop;
         Ada.Directories.End_Search (Search);
      end;
   end Check_Shared_Package_State;

   --  A timer that subtracts from the clock (Clock - Since) overflows when
   --  Since is Time_First, the "never" many timers start from; that raised
   --  on every pass of the event loop and froze every window. Timers in src/
   --  ask Files.Timing.Elapsed, or add (Clock >= Since + Span), instead.
   procedure Check_Clock_Arithmetic is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
      package Name_Sets is new Ada.Containers.Indefinite_Hashed_Sets
        (Element_Type => String, Hash => Ada.Strings.Hash, Equivalent_Elements => "=");
      Time_Names : Name_Sets.Set;

      procedure Refuse (Path, What : String) is
      begin
         Put_Line
           (Standard_Error,
            Path & ": " & What & " can overflow (Time_First is a common start); use Files.Timing.Elapsed");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end Refuse;

      procedure Check (Path : String) is
         Code : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
         From : Positive := Code'First;
         At_Clock : Natural;
      begin
         loop
            At_Clock := Ada.Strings.Fixed.Index (Code (From .. Code'Last), "Clock");
            exit when At_Clock = 0;
            declare
               Next : Positive := At_Clock + 5;
            begin
               --  Clock, Clock (), then blanks, then a lone minus.
               if Next + 1 <= Code'Last and then Code (Next .. Next + 1) = "()" then
                  Next := Next + 2;
               end if;
               while Next <= Code'Last and then Code (Next) in ' ' | ASCII.LF | ASCII.CR | ASCII.HT loop
                  Next := Next + 1;
               end loop;
               if Next <= Code'Last and then Code (Next) = '-'
                 and then (At_Clock = Code'First
                           or else Code (At_Clock - 1) not in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_')
               then
                  Refuse (Path, "subtracting from the clock");
               end if;
               exit when At_Clock + 5 > Code'Last;
               From := At_Clock + 5;
            end;
         end loop;
         if Ada.Strings.Fixed.Index (Code, "- Ada.Real_Time.Time_First") > 0
           or else Ada.Strings.Fixed.Index (Code, "-Ada.Real_Time.Time_First") > 0
         then
            Refuse (Path, "subtracting Time_First");
         end if;
         --  The operator spelled out does the same, and Files.Timing is where
         --  it is done once, guarded.
         if Ada.Directories.Simple_Name (Path) not in "files-timing.adb" | "files-timing.ads"
           and then (Ada.Strings.Fixed.Index (Code, "Ada.Real_Time.""-""") > 0
                     or else Ada.Strings.Fixed.Index (Code, "Ada.Calendar.""-""") > 0)
         then
            Refuse (Path, "subtracting times with the operator named");
         end if;
         --  A use clause lets a time be declared as plain Time, and a subtype
         --  gives it another name: either hides it from the name check below.
         declare
            Lower : constant String := Ada.Characters.Handling.To_Lower (Code);

            --  Whether a use clause (not use type) names a clock package,
            --  alone or in a list: "use Ada.Calendar, Other;" counts too.
            function Uses_A_Clock_Package return Boolean is
               From   : Positive := Lower'First;
               At_Use : Natural;
            begin
               loop
                  At_Use := Ada.Strings.Fixed.Index (Lower (From .. Lower'Last), "use ");
                  exit when At_Use = 0;
                  if At_Use = Lower'First
                    or else Lower (At_Use - 1) not in 'a' .. 'z' | '0' .. '9' | '_' | '.'
                  then
                     declare
                        Stop    : constant Natural :=
                          Ada.Strings.Fixed.Index (Lower (At_Use .. Lower'Last), ";");
                        Clause  : constant String :=
                          (if Stop = 0 then "" else Lower (At_Use + 4 .. Stop - 1));
                        Item_At : Positive := Clause'First;
                        Comma   : Natural;
                     begin
                        if Clause'Length > 0
                          and then Ada.Strings.Fixed.Trim (Clause, Ada.Strings.Both)'Length > 0
                          and then Ada.Strings.Fixed.Head (Ada.Strings.Fixed.Trim (Clause, Ada.Strings.Left), 5)
                                     /= "type "
                          and then Ada.Strings.Fixed.Head (Ada.Strings.Fixed.Trim (Clause, Ada.Strings.Left), 4)
                                     /= "all "
                        then
                           loop
                              Comma := Ada.Strings.Fixed.Index (Clause (Item_At .. Clause'Last), ",");
                              declare
                                 Name : constant String :=
                                   Ada.Strings.Fixed.Trim
                                     (Ada.Strings.Fixed.Translate
                                        (Clause (Item_At .. (if Comma = 0 then Clause'Last else Comma - 1)),
                                         Ada.Strings.Maps.To_Mapping (ASCII.LF & ASCII.CR & ASCII.HT, "   ")),
                                      Ada.Strings.Both);
                              begin
                                 if Name in "ada.real_time" | "ada.calendar" then
                                    return True;
                                 end if;
                              end;
                              exit when Comma = 0;
                              Item_At := Comma + 1;
                           end loop;
                        end if;
                     end;
                  end if;
                  exit when At_Use + 4 > Lower'Last;
                  From := At_Use + 4;
               end loop;
               return False;
            end Uses_A_Clock_Package;
         begin
            if Uses_A_Clock_Package then
               Refuse (Path, "a use clause for a clock package (use type is fine)");
            elsif Ada.Strings.Fixed.Index (Lower, " is ada.real_time.time;") > 0
              or else Ada.Strings.Fixed.Index (Lower, " is ada.calendar.time;") > 0
            then
               Refuse (Path, "a renamed time type");
            end if;
         end;
         --  Now - Last, where Last is a time some variable or field starts
         --  at: the right operand is a name declared as a time in the file's
         --  unit family (its last component, for a field).
         declare
            Index : Natural := Ada.Strings.Fixed.Index (Code, "-");
         begin
            while Index /= 0 loop
               declare
                  First  : Positive := Index + 1;
                  Last   : Natural;
                  Before : Integer;
               begin
                  while First <= Code'Last and then Code (First) in ' ' | ASCII.LF | ASCII.CR | ASCII.HT loop
                     First := First + 1;
                  end loop;
                  Last := First - 1;
                  while Last < Code'Last
                    and then Code (Last + 1) in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | '.'
                  loop
                     Last := Last + 1;
                  end loop;
                  --  Binary only: a name, a literal or a parenthesis before it.
                  Before := Index - 1;
                  while Before >= Code'First and then Code (Before) in ' ' | ASCII.LF | ASCII.CR | ASCII.HT loop
                     Before := Before - 1;
                  end loop;
                  if Last >= First
                    and then Before >= Code'First
                    and then Code (Before) in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | ')'
                  then
                     declare
                        Operand : constant String := Code (First .. Last);
                        Dot     : constant Natural := Ada.Strings.Fixed.Index (Operand, ".", Ada.Strings.Backward);
                        Name    : constant String :=
                          (if Dot = 0 then Operand else Operand (Dot + 1 .. Operand'Last));
                     begin
                        if Name /= "" and then Time_Names.Contains (Ada.Characters.Handling.To_Lower (Name)) then
                           Refuse (Path, "subtracting the time " & Operand);
                        end if;
                     end;
                  end if;
               end;
               exit when Index = Code'Last;
               Index := Ada.Strings.Fixed.Index (Code (Index + 1 .. Code'Last), "-");
            end loop;
         end;
      end Check;

      --  Every name declared with a time type: "Name : [aliased] [constant]
      --  Ada.Real_Time.Time" or "... Ada.Calendar.Time".
      procedure Collect (Path : String) is
         Code : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
      begin
         for Type_Name of String_List'
           [To_Unbounded_String ("Ada.Real_Time.Time"), To_Unbounded_String ("Ada.Calendar.Time")]
         loop
            declare
               Pattern : constant String := To_String (Type_Name);
               At_Type : Natural := Ada.Strings.Fixed.Index (Code, Pattern);
            begin
               while At_Type /= 0 loop
                  declare
                     After : constant Positive := At_Type + Pattern'Length;
                     Colon : Natural := At_Type - 1;
                  begin
                     --  The whole type name, not Time_Span or Time_First.
                     if After > Code'Last
                       or else Code (After) not in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' | '.'
                     then
                        --  Back over "constant", "aliased" and blanks to the colon.
                        while Colon >= Code'First and then Code (Colon) /= ':'
                          and then Code (Colon) not in ';' | '(' | ASCII.LF
                        loop
                           Colon := Colon - 1;
                        end loop;
                        if Colon >= Code'First and then Code (Colon) = ':' then
                           declare
                              Last  : Natural := Colon - 1;
                              First : Natural;
                           begin
                              while Last >= Code'First and then Code (Last) = ' ' loop
                                 Last := Last - 1;
                              end loop;
                              First := Last;
                              while First > Code'First
                                and then Code (First - 1) in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_'
                              loop
                                 First := First - 1;
                              end loop;
                              if Last >= First and then First >= Code'First then
                                 Time_Names.Include (Ada.Characters.Handling.To_Lower (Code (First .. Last)));
                              end if;
                           end;
                        end if;
                     end if;
                     exit when After > Code'Last;
                     At_Type := Ada.Strings.Fixed.Index (Code (After .. Code'Last), Pattern);
                  end;
               end loop;
            end;
         end loop;
      end Collect;

      procedure For_Each_Source (Visit : not null access procedure (Path : String)) is
      begin
         Ada.Directories.Start_Search
           (Search, Root & "/src", "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            Visit (Ada.Directories.Full_Name (Item));
         end loop;
         Ada.Directories.End_Search (Search);
      end For_Each_Source;
      --  The times a file can name: its own, and those of the specs and
      --  bodies of its unit family (a stem that is a dash-prefix of its own).
      procedure Check_With_Family (Path : String) is
         Stem : constant String := Ada.Directories.Base_Name (Path);

         procedure Collect_If_Family (Other : String) is
            Other_Stem : constant String := Ada.Directories.Base_Name (Other);
         begin
            if Other_Stem = Stem
              or else (Other_Stem'Length < Stem'Length
                       and then Stem (Stem'First .. Stem'First + Other_Stem'Length - 1) = Other_Stem
                       and then Stem (Stem'First + Other_Stem'Length) = '-')
            then
               Collect (Other);
            end if;
         end Collect_If_Family;

         Family_Search : Ada.Directories.Search_Type;
         Family_Item   : Ada.Directories.Directory_Entry_Type;
      begin
         Time_Names.Clear;
         Ada.Directories.Start_Search
           (Family_Search, Root & "/src", "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
         while Ada.Directories.More_Entries (Family_Search) loop
            Ada.Directories.Get_Next_Entry (Family_Search, Family_Item);
            Collect_If_Family (Ada.Directories.Full_Name (Family_Item));
         end loop;
         Ada.Directories.End_Search (Family_Search);
         Check (Path);
      end Check_With_Family;
   begin
      For_Each_Source (Check_With_Family'Access);
   end Check_Clock_Arithmetic;

   --  The environment is read in one place: Files.Environment asks Hostkit,
   --  which knows how each host keeps it (a variable set to "" is no variable
   --  on Windows), so no unit answers differently from the rest.
   procedure Check_Environment_Access is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
   begin
      Ada.Directories.Start_Search
        (Search, Root & "/src", "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Path : constant String := Ada.Directories.Full_Name (Item);
            Code : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
            Lower : constant String := Ada.Characters.Handling.To_Lower (Code);
         begin
            --  Ada's own, Hostkit's (which Files.Environment wraps), a C
            --  getenv bound by hand, GNAT's command-line environment.
            if Ada.Directories.Simple_Name (Path) not in "files-environment.adb" | "files-environment.ads"
              and then (Ada.Strings.Fixed.Index (Lower, "ada.environment_variables") > 0
                        or else Ada.Strings.Fixed.Index (Lower, "hostkit.environment") > 0
                        or else Ada.Strings.Fixed.Index (Lower, "getenv") > 0
                        or else Ada.Strings.Fixed.Index (Lower, "environment_value") > 0
                        or else Ada.Strings.Fixed.Index (Lower, "command_line.environment") > 0)
            then
               Ada.Directories.End_Search (Search);
               Put_Line (Standard_Error, Path & ": reads the environment directly; use Files.Environment");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   end Check_Environment_Access;

   --  GNAT's Ada.Directories reads a path's text with a 256-character
   --  component limit on Windows (Name_Error past it): leaves, parents and
   --  joins go through Files.Fs_Primitives (Hostkit.Path_Text) or
   --  Hostkit.Fs.Join. Simple_Name of a search entry is fine, written with
   --  its Directory_Entry name.
   procedure Check_Path_Text_Calls is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
   begin
      Ada.Directories.Start_Search
        (Search, Root & "/src", "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Path  : constant String := Ada.Directories.Full_Name (Item);
            Lower : constant String :=
              Ada.Characters.Handling.To_Lower
                (Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => True));
            Simple : constant String := "ada.directories.simple_name (";
            From   : Positive := Lower'First;
            At_Simple : Natural;
            Bad    : Boolean :=
              Ada.Strings.Fixed.Index (Lower, "ada.directories.containing_directory (") > 0
              or else Ada.Strings.Fixed.Index (Lower, "ada.directories.compose (") > 0;
         begin
            loop
               At_Simple := Ada.Strings.Fixed.Index (Lower (From .. Lower'Last), Simple);
               exit when At_Simple = 0;
               if Ada.Strings.Fixed.Index
                    (Lower (At_Simple + Simple'Length .. Natural'Min (Lower'Last, At_Simple + Simple'Length + 40)),
                     "directory_entry =>") /= At_Simple + Simple'Length
               then
                  Bad := True;
               end if;
               exit when At_Simple + Simple'Length > Lower'Last;
               From := At_Simple + Simple'Length;
            end loop;
            if Bad then
               Ada.Directories.End_Search (Search);
               Put_Line
                 (Standard_Error,
                  Path & ": reads a path with Ada.Directories (Simple_Name, Containing_Directory, Compose);"
                  & " use Files.Fs_Primitives or Hostkit.Fs.Join");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   end Check_Path_Text_Calls;

   --  Every flush goes through Files.Durability, where the suite can make
   --  one fail on every host: a Hostkit.Durability.Sync_* call elsewhere in
   --  src/ is a flush no test can fail.
   procedure Check_Durability_Calls is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;
   begin
      Ada.Directories.Start_Search
        (Search, Root & "/src", "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Path  : constant String := Ada.Directories.Full_Name (Item);
            Lower : constant String :=
              Ada.Characters.Handling.To_Lower
                (Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => True));
         begin
            if Ada.Directories.Simple_Name (Item) /= "files-durability.adb"
              and then Ada.Strings.Fixed.Index (Lower, "hostkit.durability.sync_") > 0
            then
               Ada.Directories.End_Search (Search);
               Put_Line
                 (Standard_Error,
                  Path & ": flushes with Hostkit.Durability.Sync_*; use Files.Durability, which tests can fail");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   end Check_Durability_Calls;

   --  GNAT's Windows runtime refuses a path past 260 characters before
   --  Windows is asked -- in Ada.Directories, GNAT.OS_Lib,
   --  GNAT.Directory_Operations and System.File_IO (Stream_IO and Text_IO
   --  Open and Create) alike -- so a folder deep enough could be listed but
   --  not opened, copied or deleted. By-path file-system calls in src/ go
   --  through Files.Fs_Primitives or Hostkit (Fs, Regular_Files,
   --  Directory_Listing, Path_Text), which reach any depth. A package
   --  renaming one of these units is read as the unit, and a use clause for
   --  one is refused: it would hide the calls.
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

   --  The model caches its visible rows (Support.Ensure_Visible_Map); a
   --  subprogram that writes the items, their order, the filter or the
   --  search flag must drop the cache (Invalidate_Visible) or every lookup
   --  after it serves the old rows. Checked per top-level subprogram of each
   --  files-model*.adb (a subunit is one), comments stripped, whitespace run
   --  together so a call split over lines is still seen.
   procedure Check_Visible_Cache_Invalidation is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;

      Writes : constant array (Positive range <>) of Unbounded_String :=
        [To_Unbounded_String ("model.items :="),
         To_Unbounded_String ("model.items.clear"),
         To_Unbounded_String ("model.items.append"),
         To_Unbounded_String ("model.items.prepend"),
         To_Unbounded_String ("model.items.delete"),
         To_Unbounded_String ("model.items.insert"),
         To_Unbounded_String ("model.items.move"),
         To_Unbounded_String ("model.items.swap"),
         To_Unbounded_String ("model.items.set_length"),
         To_Unbounded_String ("model.items.reverse_elements"),
         To_Unbounded_String ("sort_items (model.items"),
         To_Unbounded_String ("filter_value :="),
         To_Unbounded_String ("search_results_active :=")];

      --  Text lowered, with every run of blanks and line ends one space.
      function Collapsed (Text : String) return String is
         Result : Unbounded_String;
         Blank  : Boolean := False;
      begin
         for C of Ada.Characters.Handling.To_Lower (Text) loop
            if C in ' ' | ASCII.HT | ASCII.LF | ASCII.CR then
               Blank := True;
            else
               if Blank and then Length (Result) > 0 then
                  Append (Result, ' ');
               end if;
               Blank := False;
               Append (Result, C);
            end if;
         end loop;
         return To_String (Result);
      end Collapsed;

      procedure Check_File (Path : String) is
         Code    : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
         Indent  : constant Natural := (if Ada.Strings.Fixed.Index (Code, "separate (") > 0 then 0 else 3);
         Pad     : constant String (1 .. Indent) := [others => ' '];
         Name    : Unbounded_String;
         Body_Of : Unbounded_String;

         --  The name a top-level subprogram header at Indent declares, or "".
         function Header_Name (Line : String) return String is
         begin
            for Word in 1 .. 2 loop
               declare
                  Lead : constant String := Pad & (if Word = 1 then "procedure " else "function ");
               begin
                  if Line'Length > Lead'Length and then Line (Line'First .. Line'First + Lead'Length - 1) = Lead then
                     declare
                        Rest : constant String := Line (Line'First + Lead'Length .. Line'Last);
                        Stop : Natural := Rest'First;
                     begin
                        while Stop <= Rest'Last and then Rest (Stop) not in ' ' | '(' | ';' loop
                           Stop := Stop + 1;
                        end loop;
                        return Rest (Rest'First .. Stop - 1);
                     end;
                  end if;
               end;
            end loop;
            return "";
         end Header_Name;

         procedure Visit (Line : String) is
         begin
            if Length (Name) = 0 then
               if Header_Name (Line) /= "" then
                  Name := To_Unbounded_String (Header_Name (Line));
                  Body_Of := To_Unbounded_String (Line);
               end if;
               return;
            end if;
            Append (Body_Of, ASCII.LF & Line);
            if Line = Pad & "end " & To_String (Name) & ";" then
               declare
                  Text : constant String := Collapsed (To_String (Body_Of));
               begin
                  if Ada.Strings.Fixed.Index (Text, "invalidate_visible") = 0 then
                     for Write of Writes loop
                        if Ada.Strings.Fixed.Index (Text, To_String (Write)) > 0 then
                           Put_Line
                             (Standard_Error,
                              Path & ": " & To_String (Name) & " writes '" & To_String (Write)
                              & "' without Invalidate_Visible: the visible-row cache would serve old rows");
                           Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
                           raise Program_Error;
                        end if;
                     end loop;
                  end if;
               end;
               Name := Null_Unbounded_String;
            end if;
         end Visit;

         First : Positive := Code'First;
      begin
         for Index in Code'Range loop
            if Code (Index) = ASCII.LF then
               Visit (Code (First .. Index - 1));
               First := Index + 1;
            end if;
         end loop;
         if First <= Code'Last then
            Visit (Code (First .. Code'Last));
         end if;
      end Check_File;
   begin
      Ada.Directories.Start_Search
        (Search, Root & "/src", "files-model*.adb", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         Check_File (Ada.Directories.Full_Name (Item));
      end loop;
      Ada.Directories.End_Search (Search);
   end Check_Visible_Cache_Invalidation;

   --  A handler that catches everything and carries on must say what it
   --  caught (Files.Diagnostics.Note), or a failure vanishes without a trace
   --  even with FILES_DIAGNOSTICS set: a "when others" exception handler in
   --  src/ either raises or names its occurrence and notes it. Files.Diagnostics
   --  and Files.Environment (which Note is built on) are exempt. The note (or
   --  other hand-on) must be a top-level statement of the handler, run on every
   --  path: one inside an if, case, loop or block leaves the other paths silent,
   --  and only a call of Diagnostics.Note itself counts (not Footnote (E, ...)).
   procedure Check_Swallowing_Handlers is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;

      procedure Check_File (Path : String) is
         Code  : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)));
         package Line_Vectors is new Ada.Containers.Indefinite_Vectors (Positive, String);
         Lines : Line_Vectors.Vector;

         function Indent (Line : String) return Natural is
         begin
            for Index in Line'Range loop
               if Line (Index) /= ' ' then
                  return Index - Line'First;
               end if;
            end loop;
            return Line'Length;
         end Indent;

         function Blank (Line : String) return Boolean is (Indent (Line) = Line'Length);

         function Trimmed (Line : String) return String is (Ada.Strings.Fixed.Trim (Line, Ada.Strings.Both));

         --  Whether Text (lower case, trimmed) starts with the reserved word Word.
         function Starts_With_Word (Text : String; Word : String) return Boolean is
           (Text'Length >= Word'Length
            and then Text (Text'First .. Text'First + Word'Length - 1) = Word
            and then (Text'Length = Word'Length
                      or else Text (Text'First + Word'Length) not in 'a' .. 'z' | '0' .. '9' | '_'));

         --  Whether a statement line opens, continues or closes a compound
         --  statement (if, case, a loop, a block, select), whose contents run
         --  on some paths only, or not at the handler's top level.
         function Opens_Nested (Line : String) return Boolean is
            Text  : constant String := Ada.Characters.Handling.To_Lower (Trimmed (Line));
            Colon : constant Natural := Ada.Strings.Fixed.Index (Text, ":");
            function Opens (Words : String) return Boolean is
              (Starts_With_Word (Words, "if") or else Starts_With_Word (Words, "elsif")
               or else Starts_With_Word (Words, "else") or else Starts_With_Word (Words, "then")
               or else Starts_With_Word (Words, "case") or else Starts_With_Word (Words, "when")
               or else Starts_With_Word (Words, "loop") or else Starts_With_Word (Words, "for")
               or else Starts_With_Word (Words, "while") or else Starts_With_Word (Words, "declare")
               or else Starts_With_Word (Words, "begin") or else Starts_With_Word (Words, "exception")
               or else Starts_With_Word (Words, "select") or else Starts_With_Word (Words, "or")
               or else Starts_With_Word (Words, "end"));
            --  Whether the text before the colon is a statement label.
            function Labelled return Boolean is
            begin
               for C of Trimmed (Text (Text'First .. Colon - 1)) loop
                  if C not in 'a' .. 'z' | '0' .. '9' | '_' then
                     return False;
                  end if;
               end loop;
               return True;
            end Labelled;
         begin
            --  A named loop or block: "Search : loop".
            return Opens (Text)
              or else (Colon > Text'First
                       and then Colon < Text'Last
                       and then Text (Colon + 1) /= '='
                       and then Labelled
                       and then Opens (Trimmed (Text (Colon + 1 .. Text'Last))));
         end Opens_Nested;

         procedure Refuse (At_Line : Positive; Why : String) is
         begin
            Put_Line
              (Standard_Error, Path & ":" & Ada.Strings.Fixed.Trim (At_Line'Image, Ada.Strings.Left) & ": " & Why);
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         end Refuse;

         First : Positive := Code'First;
      begin
         for Index in Code'Range loop
            if Code (Index) = ASCII.LF then
               Lines.Append (Code (First .. Index - 1));
               First := Index + 1;
            end if;
         end loop;
         if First <= Code'Last then
            Lines.Append (Code (First .. Code'Last));
         end if;
         for Number in Lines.First_Index .. Lines.Last_Index loop
            declare
               Line   : constant String := Lines (Number);
               Text   : constant String := Trimmed (Line);
               Arrow  : constant Natural := Ada.Strings.Fixed.Index (Text, "=>");
               Margin : constant Natural := Indent (Line);
            begin
               if Text'Length > 5 and then Text (Text'First .. Text'First + 4) = "when " and then Arrow > 0 then
                  declare
                     --  The choice parameter, if named: "when E : others =>".
                     Colon   : constant Natural := Ada.Strings.Fixed.Index (Text (Text'First .. Arrow), ":");
                     Name    : constant String :=
                       (if Colon = 0 then "" else Trimmed (Text (Text'First + 5 .. Colon - 1)));
                     Handler : Boolean := False;
                     --  "when others" carries anything on; a named choice
                     --  ("when E : Name_Error") only what it names.
                     Others_Of : constant Boolean :=
                       Ada.Strings.Fixed.Index
                         (Ada.Characters.Handling.To_Lower (Text (Text'First .. Arrow)), "others") > 0;
                     --  The handler's top-level statements: what it does on
                     --  every path, outside any if, case, loop or block.
                     Nested : Boolean := Opens_Nested (Text (Arrow + 2 .. Text'Last));
                     Top_Of : Unbounded_String :=
                       (if Nested then Null_Unbounded_String else To_Unbounded_String (Text (Arrow + 2 .. Text'Last)));
                     Last_Statement : Unbounded_String :=
                       To_Unbounded_String (Trimmed (Text (Arrow + 2 .. Text'Last)));
                  begin
                     --  An exception handler: the nearest line above at a
                     --  smaller indent is "exception" (other choices between).
                     for Above in reverse Lines.First_Index .. Number - 1 loop
                        if not Blank (Lines (Above)) and then Indent (Lines (Above)) < Margin then
                           Handler := Trimmed (Lines (Above)) = "exception";
                           exit;
                        end if;
                     end loop;
                     if Handler then
                        for Below in Number + 1 .. Lines.Last_Index loop
                           exit when not Blank (Lines (Below)) and then Indent (Lines (Below)) <= Margin;
                           if not Blank (Lines (Below)) then
                              Last_Statement := To_Unbounded_String (Trimmed (Lines (Below)));
                              --  A line at the statements' own indent starts a
                              --  statement; a deeper one continues it, or sits
                              --  inside the compound statement it opened.
                              if Indent (Lines (Below)) <= Margin + 3 then
                                 Nested := Opens_Nested (Lines (Below));
                              end if;
                              if not Nested then
                                 Append (Top_Of, ASCII.LF & Lines (Below));
                              end if;
                           end if;
                        end loop;
                        declare
                           --  Code only, lower case, and without pragma
                           --  Unreferenced, which names an occurrence to say
                           --  it is not used.
                           function Without_Unreferenced (Text : String) return String is
                              At_Pragma : constant Natural := Ada.Strings.Fixed.Index (Text, "pragma unreferenced");
                              Stop      : Natural;
                           begin
                              if At_Pragma = 0 then
                                 return Text;
                              end if;
                              Stop := Ada.Strings.Fixed.Index (Text (At_Pragma .. Text'Last), ";");
                              if Stop = 0 then
                                 Stop := Text'Last;
                              end if;
                              return Text (Text'First .. At_Pragma - 1)
                                & Without_Unreferenced (Text (Stop + 1 .. Text'Last));
                           end Without_Unreferenced;
                           Statements : constant String :=
                             Without_Unreferenced (Ada.Characters.Handling.To_Lower (To_String (Top_Of)));

                           --  What a handler that carries on does, on every
                           --  path, with what it caught: notes it
                           --  (Files.Diagnostics.Note), or keeps it for a caller
                           --  (Save_Occurrence). Naming it in some other way --
                           --  a comparison, an assignment, Footnote (E, ...) --
                           --  is not noting it.
                           function Hands_On (Occurrence : String) return Boolean is
                              --  The statements without blanks or line breaks,
                              --  so a call reads the same however it is laid out.
                              Squeezed : String (1 .. Statements'Length);
                              Last     : Natural := 0;
                              function Has (Text : String) return Boolean is
                                (Last > 0 and then Ada.Strings.Fixed.Index (Squeezed (1 .. Last), Text) > 0);

                              --  A call of Diagnostics.Note (qualified, as
                              --  Files.Diagnostics.Note or Diagnostics.Note)
                              --  with the occurrence: not a Note of some other
                              --  name that merely ends in "note".
                              function Notes return Boolean is
                                 Call    : constant String := "diagnostics.note(" & Occurrence & ",";
                                 From    : Positive := 1;
                                 At_Call : Natural;
                              begin
                                 while From <= Last loop
                                    At_Call := Ada.Strings.Fixed.Index (Squeezed (1 .. Last), Call, From);
                                    exit when At_Call = 0;
                                    if At_Call = 1 or else Squeezed (At_Call - 1) not in 'a' .. 'z' | '0' .. '9' | '_'
                                    then
                                       return True;
                                    end if;
                                    From := At_Call + 1;
                                 end loop;
                                 return False;
                              end Notes;
                           begin
                              for C of Statements loop
                                 if C not in ' ' | ASCII.LF | ASCII.CR | ASCII.HT then
                                    Last := Last + 1;
                                    Squeezed (Last) := C;
                                 end if;
                              end loop;
                              return Notes
                                or else Has ("note_event_loop(" & Occurrence & ")")
                                --  Reported to the user, as a startup error is.
                                or else Has ("exception_message(" & Occurrence & ")")
                                or else Has ("exception_information(" & Occurrence & ")")
                                or else (Has ("save_occurrence(") and then Has ("," & Occurrence & ")"));
                           end Hands_On;
                           --  Re-raising counts only as what the handler ends
                           --  with: a raise inside an if leaves the other path
                           --  carrying on, silently.
                           Final_Line : constant String :=
                             Ada.Characters.Handling.To_Lower (To_String (Last_Statement));
                           --  The last statement of that line: "Close (F); raise;".
                           Before_Final : constant Natural :=
                             (if Final_Line'Length > 1
                              then Ada.Strings.Fixed.Index
                                (Final_Line (Final_Line'First .. Final_Line'Last - 1), ";", Ada.Strings.Backward)
                              else 0);
                           Ends : constant String :=
                             Trimmed (Final_Line ((if Before_Final = 0 then Final_Line'First else Before_Final + 1)
                                                  .. Final_Line'Last));
                           Re_Raised : constant Boolean :=
                             (Ends'Length >= 5 and then Ends (Ends'First .. Ends'First + 4) = "raise")
                             or else Ada.Strings.Fixed.Index (Ends, "reraise_occurrence") > 0;
                        begin
                           if Re_Raised then
                              null;
                           elsif Name = "" then
                              if Others_Of then
                                 Refuse (Number, "a 'when others' handler carries on without noting what it caught");
                              end if;
                           elsif not Hands_On (Ada.Characters.Handling.To_Lower (Name)) then
                              Refuse (Number, "a handler names " & Name & " and carries on without using it");
                           end if;
                        end;
                     end if;
                  end;
               end if;
            end;
         end loop;
      end Check_File;
   begin
      Ada.Directories.Start_Search
        (Search, Root & "/src", "*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         if Ada.Directories.Simple_Name (Item)
           not in "files-diagnostics.ads" | "files-diagnostics.adb" | "files-environment.ads" | "files-environment.adb"
         then
            Check_File (Ada.Directories.Full_Name (Item));
         end if;
      end loop;
      Ada.Directories.End_Search (Search);
   end Check_Swallowing_Handlers;

   procedure Check_Localization_Usage is
      Main_Manifest : constant String := Root & "/alire.toml";
      Localization  : constant String := Root & "/src/files-localization.adb";
      Check_Source  : constant String := Root & "/tools/src/check_all.adb";
   begin
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "i18n = ""^1.1.0""",
         "files must depend on the i18n crate");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "i18n = { path = ""../i18n"" }",
         "files must pin i18n to the local relative crate");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "if Literal = ""cd /d """ & ASCII.LF
         & "        or else Literal = ""cd """,
         "hard-coded text checks must keep terminal shell-verb exemptions narrow");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "function Diagnostic_Pragma_Length",
         "hard-coded text checks must exempt developer-diagnostic pragma messages");
      Project_Tools.Files.Require_Contains
        (Check_Source,
         "if Literal = ""untitled """,
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
      Require_Registered_Routine
        ("Test_Localization_Runtime_Labels",
         "the test of startup, runtime-smoke and CLI help labels");
      Require_Registered_Routine
        ("Test_Startup_And_Runtime_Smoke_Reports",
         "the test of the startup and runtime smoke reports");
      Require_Registered_Routine
        ("Test_Detected_Locale_Catalogs",
         "the test of translated locale catalog loading");
      --  The per-host locale calls, and the frameworks they need, are Hostkit's
      --  now and are guarded by check_hostkit's Require_Binding (verified there
      --  by a negative test, after this comment was written while that guard did
      --  not yet exist). What has to stay true here is that
      --  files asks the host one question rather than branching per OS on its
      --  way to the environment fallbacks.
      Require_Registered_Routine
        ("Test_Host_Locale_Fallbacks",
         "the test of asking the host for its locale");
      Require_Registered_Routine
        ("Test_Localization_Pane_Labels",
         "the test of pane, status and landmark labels");
      Require_Registered_Routine
        ("Test_Localization_Error_And_Command_Keys",
         "the test of error keys and command names and descriptions");
      Check_Command_Localization_Keys;
      Check_Indirect_Localization_Keys_In_Tree (Root & "/src");
      Check_Direct_Localization_Call_Keys_In_Tree (Root & "/src");
   end Check_Localization_Usage;

   --  The pattern is looked for in code only: a comment that names what a
   --  unit must not do (as this file's own comments do) is no violation.
   procedure Require_Not_Contains
     (Path    : String;
      Pattern : String;
      Message : String) is
   begin
      --  A guard on a file that was renamed or split away guards nothing:
      --  say so, rather than pass.
      if not Project_Tools.Files.File_Exists (Path) then
         Put_Line (Standard_Error, "guarded file is missing: " & Path & " (" & Message & ")");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
      if Ada.Strings.Fixed.Index
          (Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => not Quotes (Pattern)),
           Pattern) > 0
      then
         Put_Line (Standard_Error, Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
   end Require_Not_Contains;

   --  The other way round: Path's code must say Pattern. For wiring that
   --  would otherwise be checked only by a name existing somewhere in src.
   procedure Require_Contains
     (Path    : String;
      Pattern : String;
      Message : String) is
   begin
      if not Project_Tools.Files.File_Exists (Path)
        or else Ada.Strings.Fixed.Index
                  (Code_Of
                     (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => not Quotes (Pattern)),
                   Pattern) = 0
      then
         Put_Line (Standard_Error, Path & ": " & Message);
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
   end Require_Contains;

   --  Like Require_Not_Contains, but also scans every subunit body of the unit
   --  whose body is Base_Path -- the sibling files named <stem>-*.adb. A
   --  guardrail expressed over a unit body therefore keeps covering code that
   --  has since been moved out into subunits, so splitting a large body never
   --  silently narrows the guardrail's reach.
   procedure Require_Not_Contains_In_Unit
     (Base_Path : String;
      Pattern   : String;
      Message   : String)
   is
      Dir     : constant String := Ada.Directories.Containing_Directory (Base_Path);
      Stem    : constant String := Ada.Directories.Base_Name (Base_Path);
      Ext     : constant String := Ada.Directories.Extension (Base_Path);
      Prefix  : constant String := Stem & "-";
      Suffix  : constant String := ".adb";
      Search  : Ada.Directories.Search_Type;
      Item    : Ada.Directories.Directory_Entry_Type;
      Started : Boolean := False;
   begin
      Require_Not_Contains (Base_Path, Pattern, Message);

      --  Only a body has subunits; a spec (.ads) is covered on its own.
      if Ext /= "adb" then
         return;
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Dir,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
            Ada.Directories.Directory     => False,
            Ada.Directories.Special_File  => False]);
      Started := True;
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Item);
         begin
            if Name'Length > Prefix'Length + Suffix'Length
              and then Name (Name'First .. Name'First + Prefix'Length - 1) = Prefix
              and then Name (Name'Last - Suffix'Length + 1 .. Name'Last) = Suffix
            then
               Require_Not_Contains
                 (Ada.Directories.Full_Name (Item), Pattern, Message);
            end if;
         end;
      end loop;
      Ada.Directories.End_Search (Search);
   exception
      when others =>
         if Started then
            Ada.Directories.End_Search (Search);
         end if;
         raise;
   end Require_Not_Contains_In_Unit;

   procedure Check_Filetype_Detection_Order is
   begin
      Require_Registered_Routine
        ("Test_Filetype_Detection",
         "the test of file type detection");
   end Check_Filetype_Detection_Order;

   --  The units that reach the filesystem or start processes: event
   --  translation, the model and rendering import none of them (Hostkit and
   --  its children are the platform layer: spawning, shells, file metadata).
   --  Each is a unit-name prefix, so children are caught too, and the with
   --  clauses are parsed rather than matched as text, so "with Ada.Text_IO,
   --  Ada.Directories;" or a clause split over lines cannot slip through.
   Filesystem_Units : constant String_List :=
     [To_Unbounded_String ("Hostkit"),
      To_Unbounded_String ("Ada.Directories"),
      To_Unbounded_String ("Ada.Streams.Stream_IO"),
      To_Unbounded_String ("Ada.Text_IO"),
      To_Unbounded_String ("Ada.Wide_Text_IO"),
      To_Unbounded_String ("Ada.Wide_Wide_Text_IO"),
      To_Unbounded_String ("Ada.Direct_IO"),
      To_Unbounded_String ("Ada.Sequential_IO"),
      To_Unbounded_String ("Text_IO"),
      To_Unbounded_String ("Direct_IO"),
      To_Unbounded_String ("Sequential_IO"),
      To_Unbounded_String ("GNAT.OS_Lib"),
      To_Unbounded_String ("System.OS_Lib"),
      To_Unbounded_String ("GNAT.Directory_Operations"),
      To_Unbounded_String ("GNAT.Expect"),
      To_Unbounded_String ("GNAT.Sockets"),
      To_Unbounded_String ("Ada.Command_Line"),
      To_Unbounded_String ("Ada.Environment_Variables"),
      To_Unbounded_String ("Interfaces.C"),
      --  System covers its children: addresses, storage, machine code.
      To_Unbounded_String ("System")];
   No_Units : constant String_List := [1 .. 0 => <>];

   procedure Check_Event_Translation_Contract is
      Events_Spec : constant String := Root & "/src/files-events.ads";
      Events_Body : constant String := Root & "/src/files-events.adb";

      --  Translation may only import Files.UTF8, Files.UI, and the pure
      --  Files.Rendering.Hit geometry, which forbids the mutable model,
      --  filesystem-operation, and filesystem-inspection units.
      Body_Allowed : constant String_List :=
        [To_Unbounded_String ("Files.Rendering.Hit"),
         To_Unbounded_String ("Files.UTF8"),
         To_Unbounded_String ("Files.UI")];

      --  Nor does it bind to foreign code itself: no import, export or
      --  machine-level representation.
      Foreign_Tokens : constant String_List :=
        [To_Unbounded_String ("Import"),
         To_Unbounded_String ("Export"),
         To_Unbounded_String ("Convention"),
         To_Unbounded_String ("External_Name"),
         To_Unbounded_String ("Link_Name"),
         To_Unbounded_String ("Address")];

      --  Reject a with of any Filesystem_Units unit in Path.
      --
      --  @param Path An Ada source of Files.Events.
      procedure Require_No_Filesystem_Imports (Path : String) is
      begin
         for Unit of Filesystem_Units loop
            Require_Only_Allowed_With_Clauses (Path, To_String (Unit), No_Units);
         end loop;
      exception
         when Program_Error =>
            Ada.Text_IO.Put_Line
              (Ada.Text_IO.Standard_Error,
               "error: event translation must not import filesystem or process units: " & Path);
            raise;
      end Require_No_Filesystem_Imports;

      --  Apply the body's with-clause boundary to every subunit of
      --  Files.Events (files-events-*.adb, nested subunits included): a
      --  subunit inherits the body's context and may add its own with
      --  clauses, which would otherwise widen the boundary unseen.
      procedure Check_Subunit_With_Clauses is
         Search  : Ada.Directories.Search_Type;
         Item    : Ada.Directories.Directory_Entry_Type;
         Prefix  : constant String := "files-events-";
         Started : Boolean := False;
      begin
         Ada.Directories.Start_Search
           (Search, Root & "/src", Prefix & "*.adb", [Ada.Directories.Ordinary_File => True, others => False]);
         Started := True;
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            Require_Only_Allowed_With_Clauses (Ada.Directories.Full_Name (Item), "Files.", Body_Allowed);
            Require_No_Filesystem_Imports (Ada.Directories.Full_Name (Item));
            Project_Tools.Ada_Source.Require_No_Code_Tokens (Ada.Directories.Full_Name (Item), Foreign_Tokens);
         end loop;
         Ada.Directories.End_Search (Search);
      exception
         when others =>
            if Started then
               Ada.Directories.End_Search (Search);
            end if;
            raise;
      end Check_Subunit_With_Clauses;
   begin
      --  No filesystem or process imports in the spec, the body, or (below)
      --  any subunit.
      Require_No_Filesystem_Imports (Events_Spec);
      Require_No_Filesystem_Imports (Events_Body);
      --  Lock the Files.* import boundary through the shared helper, over the
      --  body and every subunit.
      Require_Only_Allowed_With_Clauses (Events_Body, "Files.", Body_Allowed);
      Check_Subunit_With_Clauses;
      --  The spec names the types translation reads and produces: a
      --  Command_Id in an Input_Action (Files.Commands), the View_Snapshot and
      --  Frame_Commands that Translate_Click hit-tests (Files.Rendering), and
      --  the shared value types (Files.Types), and the base line height its
      --  defaults name (Files.UI). Those four are allowed there and nothing
      --  else -- the body checks below still forbid any call into them beyond
      --  reading those values.
      Require_Only_Allowed_With_Clauses
        (Events_Spec,
         "Files.",
         [To_Unbounded_String ("Files.Commands"),
          To_Unbounded_String ("Files.Rendering"),
          To_Unbounded_String ("Files.Types"),
          To_Unbounded_String ("Files.UI")]);
      Require_Not_Contains
        (Events_Spec,
         "Files.Model.",
         "event translation's spec must not name live model state");
      Require_Not_Contains
        (Events_Spec,
         "Files.File_System.",
         "event translation's spec must not name filesystem state");
      Require_Not_Contains
        (Events_Spec,
         "Files.Operations.",
         "event translation's spec must not name operation execution");
      Require_Not_Contains_In_Unit
        (Events_Body,
         "Files.Commands.Execution",
         "event translation must not directly execute commands");
      Require_Not_Contains_In_Unit
        (Events_Body,
         "Files.Operations.",
         "event translation must not route through operation execution");
      Require_Not_Contains_In_Unit
        (Events_Body,
         "Files.File_System.",
         "event translation must not inspect or mutate the filesystem");
      Require_Not_Contains_In_Unit
        (Events_Body,
         "Files.Model.",
         "event translation must not mutate or inspect live model state");

      --  The model holds its background jobs' handles as data; starting,
      --  polling, cancelling and stepping them is Files.Operations' work. So
      --  model code names only the handle type and the queries below.
      for Job_Package of String_List'
        [To_Unbounded_String ("Files.Transfer_Jobs"),
         To_Unbounded_String ("Files.Process_Jobs"),
         To_Unbounded_String ("Files.Folder_Size")]
      loop
         Require_Only_Names_From
           ("files-model",
            To_String (Job_Package),
            [To_Unbounded_String ("Session"),
             To_Unbounded_String ("Active"),
             To_Unbounded_String ("Is_Active"),
             To_Unbounded_String ("Target_For_Test"),
             To_Unbounded_String ("Path_Vectors"),
             --  Finished measurements handed to the model: data, not a job.
             To_Unbounded_String ("Measurement_Vectors")],
            "the model drives no background job");
      end loop;

      --  The model reads no disk: what it shows was read by an operation or
      --  a job, so it can be rebuilt and tested without one. Names a model
      --  unit may take from the packages that do I/O are the pure ones.
      Require_Only_Names_From
        ("files-model", "Files.Settings",
         [To_Unbounded_String ("Settings_Model"),
          To_Unbounded_String ("Settings_Draft"),
          To_Unbounded_String ("Path_Label_Vectors"),
          To_Unbounded_String ("Path_Sets")],
         "the model reads no disk (settings are loaded and saved elsewhere)",
         --  Settings is also what the model's parameters are called.
         Short_Too => False);
      Require_Only_Names_From
        ("files-model", "Files.Desktop_Applications",
         [To_Unbounded_String ("Application_Vectors")],
         "the model reads no disk (applications are listed elsewhere)",
         Short_Too => False);
      Require_Only_Names_From
        ("files-model", "Ada.Directories", [To_Unbounded_String ("Simple_Name")],
         "the model reads no disk");
      Require_Only_Names_From
        ("files-model", "GNAT.OS_Lib", [To_Unbounded_String ("Is_Absolute_Path")],
         "the model reads no disk");
      Require_Only_Names_From
        ("files-model",
         "Files.File_System",
         [To_Unbounded_String ("Directory_Signature"),
          To_Unbounded_String ("Directory_Size_Result"),
          To_Unbounded_String ("Drop_Copy"),
          To_Unbounded_String ("Drop_Move"),
          To_Unbounded_String ("Drop_Import_Mode"),
          To_Unbounded_String ("Make_Item"),
          To_Unbounded_String ("Path_Result"),
          To_Unbounded_String ("Path_Status"),
          To_Unbounded_String ("Path_Valid"),
          To_Unbounded_String ("Root_Entry"),
          To_Unbounded_String ("Root_Entry_Vectors"),
          To_Unbounded_String ("Root_Filesystem"),
          To_Unbounded_String ("Root_Kind"),
          To_Unbounded_String ("Root_Ready"),
          To_Unbounded_String ("Sort_Items")],
         "the model reads no disk");
      for Banned of String_List'
        [To_Unbounded_String ("Hostkit."),
         To_Unbounded_String ("Ada.Text_IO"),
         To_Unbounded_String ("Ada.Streams.Stream_IO"),
         To_Unbounded_String ("Files.Capped_Files"),
         To_Unbounded_String ("Files.Fs_Primitives")]
      loop
         Require_Not_Contains_In_Unit
           (Root & "/src/files-model.adb",
            To_String (Banned),
            "the model reads no disk (" & To_String (Banned) & ")");
         Require_Not_Contains
           (Root & "/src/files-model.ads",
            To_String (Banned),
            "the model reads no disk (" & To_String (Banned) & ")");
      end loop;
      --  A deny-list misses a new way to the disk (it went through
      --  Copy_Context, which makes a transport): every files-model* unit
      --  may import only these. A new import is a decision made here.
      Require_Only_Names_From
        ("files-model", "Files.Copy_Context",
         [To_Unbounded_String ("Session"), To_Unbounded_String ("Empty_Session")],
         "the model makes no transport; Operations.Begin_Paste_Execution does");
      declare
         Search  : Ada.Directories.Search_Type;
         Item    : Ada.Directories.Directory_Entry_Type;
         Allowed : constant String_List :=
           [To_Unbounded_String ("Files.Command_Palette"),
            To_Unbounded_String ("Files.Copy_Context"),
            To_Unbounded_String ("Files.Desktop_Applications"),
            --  A handler's trace of what it carried on past, not model I/O.
            To_Unbounded_String ("Files.Diagnostics"),
            --  The info pane's extra line as data: the model only keeps it.
            To_Unbounded_String ("Files.Extra_Info"),
            To_Unbounded_String ("Files.File_System"),
            To_Unbounded_String ("Files.Folder_Size"),
            To_Unbounded_String ("Files.Folder_Tree"),
            To_Unbounded_String ("Files.Grouping"),
            To_Unbounded_String ("Files.Items"),
            To_Unbounded_String ("Files.Model.Support"),
            To_Unbounded_String ("Files.Paste"),
            To_Unbounded_String ("Files.Path_Checks"),
            To_Unbounded_String ("Files.Process_Jobs"),
            To_Unbounded_String ("Files.Quick_Look"),
            To_Unbounded_String ("Files.Settings"),
            To_Unbounded_String ("Files.Settings_Form"),
            To_Unbounded_String ("Files.Shared_Bytes"),
            To_Unbounded_String ("Files.Transfer_Jobs"),
            To_Unbounded_String ("Files.Type_Ahead"),
            To_Unbounded_String ("Files.Types"),
            To_Unbounded_String ("Files.Undo_Payloads"),
            To_Unbounded_String ("Files.UTF8")];
      begin
         Ada.Directories.Start_Search
           (Search, Root & "/src", "files-model*.ad?", [Ada.Directories.Ordinary_File => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            Require_Only_Allowed_With_Clauses (Ada.Directories.Full_Name (Item), "Files.", Allowed);
            --  Nor any unit that does I/O, however it is spelled: a deny-list
            --  of a few names let GNAT.Directory_Operations or a C import
            --  through. Ada.Directories is held to Simple_Name above.
            for Unit of Filesystem_Units loop
               if To_String (Unit) /= "Ada.Directories" then
                  Require_Only_Allowed_With_Clauses (Ada.Directories.Full_Name (Item), To_String (Unit), No_Units);
               end if;
            end loop;
         end loop;
         Ada.Directories.End_Search (Search);
      end;
   end Check_Event_Translation_Contract;

   --  The test suite steers a few behaviours through FILES_TEST_* variables
   --  (no volume trash, its scratch area). The shipped program reads them
   --  too, so they stay in the units listed here: a new one is a decision,
   --  not a convenience.
   --  The commands are named without the model (Files.Commands), so input
   --  translation does not depend on it; what needs the model is in
   --  Files.Commands.Status and .Execution. The model holds the palette's and
   --  the settings panel's state; the window layer (Files.Overlays) draws
   --  and localizes them.
   procedure Check_Command_And_Overlay_Layers is
      Search : Ada.Directories.Search_Type;
      Item   : Ada.Directories.Directory_Entry_Type;

      --  The with clauses parsed (a list or a split clause cannot hide one),
      --  and no qualified name either, in the spec, the body and every
      --  subunit; the Status and Execution children are meant to use it.
      procedure Check (Path : String) is
      begin
         Require_Only_Allowed_With_Clauses (Path, "Files.Model", No_Units);
         Require_Not_Contains (Path, "Files.Model.", "Files.Commands must not read the model");
      end Check;
   begin
      Check (Root & "/src/files-commands.ads");
      Check (Root & "/src/files-commands.adb");
      Ada.Directories.Start_Search
        (Search, Root & "/src", "files-commands-*.adb", [Ada.Directories.Ordinary_File => True, others => False]);
      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Item);
         if Ada.Strings.Fixed.Index
              (To_String (Project_Tools.Text.Read_Text_File (Ada.Directories.Full_Name (Item))),
               "separate (Files.Commands)") > 0
         then
            Check (Ada.Directories.Full_Name (Item));
         end if;
      end loop;
      Ada.Directories.End_Search (Search);
      for Pattern of String_List'
        [To_Unbounded_String ("Build_Frame"),
         To_Unbounded_String ("Files.Localization")]
      loop
         Require_Not_Contains_In_Unit
           (Root & "/src/files-model.adb", To_String (Pattern),
            "the model holds overlay state; Files.Overlays draws and localizes it (" & To_String (Pattern) & ")");
         --  The specs too: a with clause there reaches every model body,
         --  which could then use the unit by a name this check never sees.
         Ada.Directories.Start_Search
           (Search, Root & "/src", "files-model*.ads", [Ada.Directories.Ordinary_File => True, others => False]);
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            Require_Not_Contains
              (Ada.Directories.Full_Name (Item), To_String (Pattern),
               "the model holds overlay state; Files.Overlays draws and localizes it (" & To_String (Pattern)
               & ", " & Ada.Directories.Simple_Name (Item) & ")");
         end loop;
         Ada.Directories.End_Search (Search);
      end loop;
   end Check_Command_And_Overlay_Layers;

   procedure Check_Test_Hooks is
      Hooks : constant Project_Tools.Files.Path_List :=
        [To_Unbounded_String (Root & "/src/files-file_system-support.ads"),
         To_Unbounded_String (Root & "/src/files-file_system-support.adb"),
         To_Unbounded_String (Root & "/src/files-file_system-volume_trash_supported.adb"),
         To_Unbounded_String (Root & "/src/files-file_system-volume_trash_bases.adb")];
      Unexpected : constant String :=
        Project_Tools.Ada_Source.First_Source_File_Containing
          (Root & "/src",
           "FILES_TEST_",
           Hooks);
      --  A name built in pieces ("FILES_" & "TEST_X") reads a hook the
      --  search above cannot see: the prefix is never split, anywhere.
      Split : constant String :=
        Project_Tools.Ada_Source.First_Source_File_Containing (Root & "/src", "FILES_"" &", Hooks);
   begin
      if Split /= "" then
         Put_Line (Standard_Error, Split & ": builds a FILES_ variable name in pieces; spell it whole");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
      if Unexpected /= "" then
         Put_Line (Standard_Error, Unexpected & ": reads a FILES_TEST_* variable outside the listed test hooks");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
      --  And every listed hook still is one: a stale entry would let a new
      --  hook into that file pass unreviewed.
      for Hook of Hooks loop
         Project_Tools.Files.Require_Contains
           (To_String (Hook), "FILES_TEST_", To_String (Hook) & " is listed as a test hook but reads none");
      end loop;
   end Check_Test_Hooks;

   procedure Check_Crate_Structure is
      Main_Manifest  : constant String := Root & "/alire.toml";
      Top_Tests_Manifest : constant String := Root & "/tests/alire.toml";
      Tools_Manifest : constant String := Root & "/tools/alire.toml";
      Main_Project   : constant String := Root & "/files.gpr";
      Top_Tests_Project : constant String := Root & "/tests/tests.gpr";
      Tools_Project  : constant String := Root & "/tools/files_check_all.gpr";
      Main_Ignore    : constant String := Root & "/.gitignore";
      Top_Tests_Ignore : constant String := Root & "/tests/.gitignore";
      Tools_Ignore   : constant String := Root & "/tools/.gitignore";
   begin
      Project_Tools.Files.Require_Files
        ([To_Unbounded_String (Main_Project),
          To_Unbounded_String (Top_Tests_Manifest),
          To_Unbounded_String (Top_Tests_Project),
          To_Unbounded_String (Tools_Manifest),
          To_Unbounded_String (Tools_Project),
          To_Unbounded_String (Root & "/tools/src/check_all.adb"),
          To_Unbounded_String (Root & "/tools/src/cldr_to_catalog.adb"),
          To_Unbounded_String (Main_Ignore),
          To_Unbounded_String (Top_Tests_Ignore),
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
         "guikit = ""^0.1.0""",
         "files must depend on the guikit crate");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "guikit = { path = ""../guikit"" }",
         "files must pin guikit to the local relative crate");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "i18n = ""^1.1.0""",
         "files must depend on the i18n crate");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "i18n = { path = ""../i18n"" }",
         "files must pin i18n to the local relative crate");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "textrender = ""^1.0.0""",
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
         "for Source_Dirs use (""src/"", ""config/"");",
         "files project must build one source list for every host");
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
        (Root & "/tools/src/check_all.adb",
         "Run (""top-level tests build"", Root & ""/tests"", Alr, [1 => new String'(""build"")]);",
         "full validation must build the top-level tests sub-crate");
      Project_Tools.Files.Require_Contains
        (Root & "/tools/src/check_all.adb",
         "Run (""top-level AUnit tests"", Root & ""/tests"", ""./bin/tests"", []);",
         "full validation must run the top-level tests sub-crate");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Manifest,
         "files = ""^0.1.0""",
         "top-level tests sub-crate must depend on the files crate");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Manifest,
         "files = { path = "".."" }",
         "top-level tests sub-crate must pin the parent files crate by local relative path");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Manifest,
         "aunit = ",
         "top-level tests sub-crate must depend on AUnit");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Project,
         "for Source_Dirs use (""tests/src/""",
         "top-level tests sub-crate must build the AUnit suite sources");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Project,
         "for Main use (""tests.adb""",
         "top-level tests sub-crate must build the AUnit runner");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Project,
         """noop.adb""",
         "the suite must ship the no-op program its open-action tests launch");
      Project_Tools.Files.Require_Contains
        (Top_Tests_Project,
         """failing.adb""",
         "the suite must ship the failing program its open-action tests launch");
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
         "project_tools = ""^0.1.0""",
         "checker tooling must depend on the project_tools crate");
      Project_Tools.Files.Require_Contains
        (Tools_Manifest,
         "project_tools = { path = ""../../project_tools"" }",
         "checker tooling must pin project_tools to the local relative crate");
      Project_Tools.Files.Require_Contains
        (Tools_Project,
         "for Main use (""check_all.adb"", ""cldr_to_catalog.adb"", ""release_check.adb"");",
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
         "for Executable (""release_check.adb"") use ""release_check"";",
         "checker tooling project must produce the release checker executable");
      Project_Tools.Files.Require_Contains
        (Tools_Project,
         "for Source_Dirs use (""src"", ""config"");",
         "checker tooling project must build its Ada sources and generated config");
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

   procedure Check_Application_CLI_Surface is
      Application_Spec : constant String := Root & "/src/files-application.ads";
      Application_Body : constant String := Root & "/src/files-application.adb";
      Tests            : constant String := Combined_Suite;
   begin
      Require_Not_Contains_In_Unit
        (Root & "/src/files-rendering.adb",
         "Unit_Width - 1",
         "text glyph rendering must not half-shift wide Unicode filename glyphs");
      Project_Tools.Files.Require_Contains
        (Root & "/share/files.catalog",
         "en.cli.help.option.version = ",
         "localized catalog must include version help text");
   end Check_Application_CLI_Surface;

   procedure Check_Executable_CLI_Help is
   begin
      Run_And_Require_Output
        (Label   => "files long help",
         Dir             => Root,
         Program         => "./bin/files",
         Args            => [1 => new String'("--help")],
         Output_Path     => Temp_Path ("help-long.txt"),
         Required_First  => "Usage: files",
         Required_Second => "--settings PATH");
      Run_And_Require_Output
        (Label   => "files short help",
         Dir             => Root,
         Program         => "./bin/files",
         Args            => [1 => new String'("-h")],
         Output_Path     => Temp_Path ("help-short.txt"),
         Required_First  => "Usage: files",
         Required_Second => "--help, -h");
      Run_And_Require_Output
        (Label   => "files version",
         Dir             => Root,
         Program         => "./bin/files",
         Args            => [1 => new String'("--version")],
         Output_Path     => Temp_Path ("version.txt"),
         Required_First  => "files ",
         Required_Second => "0.1.0-dev");
   end Check_Executable_CLI_Help;

   procedure Check_Desktop_Runtime_Contract is
      Windows_Body : constant String := Root & "/src/files-application-windows.adb";
      Tests        : constant String := Combined_Suite;
   begin
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Glyphs.Missing_Glyph_Count /= 0",
         "headless smoke must not reject otherwise visible frames solely for missing-glyph fallback");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Glfw.Windows.Context.Make_Current",
         "desktop Vulkan runtime must not make an OpenGL context current");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Glfw.Windows.Context.Swap_Buffers",
         "desktop Vulkan runtime must not swap OpenGL buffers");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Glfw.Windows.Context.Set_Swap_Interval",
         "desktop Vulkan runtime must not configure OpenGL swap interval");
      Require_Registered_Routine
        ("Test_Runtime_Capabilities_And_Drop_Events",
         "the test of runtime capabilities and drop events");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Runtime.Last_Missing_Glyph_Count = 0",
         "live smoke must not reject otherwise visible frames solely for missing-glyph fallback");
      --  The window's wiring, in the window's own code (the test suite once
      --  checked these names anywhere in src, which a stale mention passed).
      Require_Contains
        (Windows_Body, "Glfw.Windows.Drop.Paths.Watch", "every window must hand its drops to the import queue");
      Require_Contains
        (Windows_Body, "Handle_Drop_Input", "the event loop must import queued drops");
      Require_Contains (Windows_Body, "Files.Window_Icon.Set", "every window must show the application icon");
      Require_Contains
        (Windows_Body, "Guikit.Vulkan.Wait_For_Events", "the event loop must wait for events, not spin");
      Require_Contains
        (Windows_Body, "Files.Refresh_Jobs.Poll_Watch", "the event loop must poll the folder watch");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "inotify",
         "window code must not name a Linux-only facility directly; go through Hostkit.Watch");
   end Check_Desktop_Runtime_Contract;

   procedure Check_Rendering_Architecture is
      Rendering_Body : constant String := Root & "/src/files-rendering.adb";
      Rendering_Spec : constant String := Root & "/src/files-rendering.ads";
      Hit_Body       : constant String := Root & "/src/files-rendering-hit.adb";
      Hit_Spec       : constant String := Root & "/src/files-rendering-hit.ads";
      Fonts_Body     : constant String := Root & "/src/files-fonts.adb";
      Fonts_Spec     : constant String := Root & "/src/files-fonts.ads";
      Application_Body : constant String := Root & "/src/files-application.adb";
      Windows_Body   : constant String := Root & "/src/files-application-windows.adb";
      Tests          : constant String := Combined_Suite;

      procedure Check_Rendering_Unit
        (Path  : String;
         Label : String) is
      begin
         Require_Not_Contains_In_Unit
           (Path,
            "with Ada.Directories;",
            Label & " must not import Ada.Directories for filesystem access");
         Require_Not_Contains_In_Unit
           (Path,
            "Ada.Directories.",
            Label & " must not perform filesystem access");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Operations.",
            Label & " must not execute operations");
         --  The qualified forms alone let `use Files.Operations;` and an
         --  unqualified call through; the dependency itself is what is barred.
         Require_Not_Contains_In_Unit
           (Path,
            "with Files.Operations",
            Label & " must not depend on operations");
         Require_Not_Contains_In_Unit
           (Path,
            "with Files.Controller",
            Label & " must not depend on the controller");
         Require_Not_Contains_In_Unit
           (Path,
            "with Files.Application",
            Label & " must not depend on application startup");
         Require_Not_Contains_In_Unit
           (Path,
            "with Files.Interaction",
            Label & " must not depend on the interaction reducer");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Controller.",
            Label & " must not route controller actions");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Application.",
            Label & " must not call application startup logic");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Commands.Execution",
            Label & " must not dispatch commands");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Commands.Find_By_Shortcut",
            Label & " must not translate input shortcuts");
         Require_Not_Contains_In_Unit
           (Path,
            "with GNAT.OS_Lib;",
            Label & " must not import OS process bindings");
         Require_Not_Contains_In_Unit
           (Path,
            "GNAT.OS_Lib.",
            Label & " must not call OS process bindings");
         Require_Not_Contains_In_Unit
           (Path,
            "GNAT.Expect.",
            Label & " must not call process interaction bindings");
         Require_Not_Contains_In_Unit
           (Path,
            "Create_Process",
            Label & " must not create external processes");
         Require_Not_Contains_In_Unit
           (Path,
            "Spawn",
            Label & " must not spawn external processes");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Settings.Add_Extension_Mapping",
            Label & " must not mutate settings extension mappings");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Settings.Add_Icon_Mapping",
            Label & " must not mutate settings icon mappings");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Settings.Add_Open_Action",
            Label & " must not mutate settings open-action mappings");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Settings.Apply_Draft",
            Label & " must not apply settings drafts");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Settings.Ensure_Default_File",
            Label & " must not create settings files");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Settings.Save_Text",
            Label & " must not write settings text");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Settings.Load_File",
            Label & " must not load settings files");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Model.Set_",
            Label & " must not mutate model state");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Model.Begin_",
            Label & " must not mutate model state");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Model.Cancel_",
            Label & " must not mutate model state");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Model.Clear_",
            Label & " must not mutate model state");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Model.Close_",
            Label & " must not mutate model state");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Model.Focus_",
            Label & " must not mutate focus state");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Model.Go_",
            Label & " must not mutate path history");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Model.Navigate_",
            Label & " must not mutate path history");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Model.Open_",
            Label & " must not mutate model state");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Model.Replace_",
            Label & " must not mutate model state");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Model.Resume_",
            Label & " must not mutate rename state");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Model.Scroll_",
            Label & " must not mutate scroll state");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Model.Select_",
            Label & " must not mutate selection state");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Model.Move_Selection",
            Label & " must not mutate selection state");
         Require_Not_Contains_In_Unit
           (Path,
            "Files.Model.Toggle_",
            Label & " must not mutate model state");
         --  The snapshot and frame read nothing from disk: a stat per item
         --  there would run on every rebuild.
         for Banned of Project_Tools.Ada_Source.String_List'
           [To_Unbounded_String ("Hostkit."),
            To_Unbounded_String ("Ada.Text_IO"),
            To_Unbounded_String ("Ada.Streams.Stream_IO"),
            To_Unbounded_String ("Files.Capped_Files"),
            To_Unbounded_String ("Files.Fs_Primitives")]
         loop
            Require_Not_Contains_In_Unit
              (Path,
               To_String (Banned),
               Label & " must not do I/O (" & To_String (Banned) & ")");
         end loop;
      end Check_Rendering_Unit;
   begin
      --  Rendering reads the file system's types and two capability queries;
      --  every call that lists, writes or validates is someone else's.
      Require_Only_Names_From
        ("files-rendering",
         "Files.File_System",
         [To_Unbounded_String ("Directory_Item"),
          To_Unbounded_String ("Item_Vectors"),
          To_Unbounded_String ("Supports_Permissions"),
          To_Unbounded_String ("Supports_Ownership"),
          To_Unbounded_String ("Drop_Move"),
          To_Unbounded_String ("Drop_Import_Mode"),
          To_Unbounded_String ("Directory_Size_Result")],
         "rendering must not list, write or validate files");
      Check_Rendering_Unit (Rendering_Spec, "rendering spec");
      Check_Rendering_Unit (Rendering_Body, "rendering body");
      Check_Rendering_Unit (Hit_Spec, "hit-testing spec");

      --  Lock the Files.* import boundary of the rendering layer through the
      --  shared helper. The allow-lists are the units each source actually
      --  imports today, so the operations, controller, and application-startup
      --  units (and any other new Files.* dependency) are rejected.
      Require_Only_Allowed_With_Clauses
        (Rendering_Spec,
         "Files.",
         [To_Unbounded_String ("Files.Breadcrumbs"),
          To_Unbounded_String ("Files.Commands"),
          To_Unbounded_String ("Files.Folder_Tree"),
          To_Unbounded_String ("Files.File_Types"),
          To_Unbounded_String ("Files.Icon_Themes"),
          To_Unbounded_String ("Files.Model"),
          To_Unbounded_String ("Files.Quick_Look"),
          To_Unbounded_String ("Files.Settings"),
          To_Unbounded_String ("Files.Shared_Bytes"),
          To_Unbounded_String ("Files.Types")]);
      Require_Only_Allowed_With_Clauses
        (Rendering_Body,
         "Files.",
         [To_Unbounded_String ("Files.Accessibility"),
          To_Unbounded_String ("Files.Command_Palette"),
          To_Unbounded_String ("Files.Display_Text"),
          To_Unbounded_String ("Files.File_System"),
          To_Unbounded_String ("Files.File_Types"),
          To_Unbounded_String ("Files.Fonts"),
          To_Unbounded_String ("Files.Localization"),
          To_Unbounded_String ("Files.UI"),
          To_Unbounded_String ("Files.UTF8")]);
      --  Hit-testing stays pure geometry: it may import only the domain UI
      --  layout it maps pixels through (the body is also covered above as a
      --  files-rendering-* source).
      Require_Only_Allowed_With_Clauses
        (Hit_Body,
         "Files.",
         [To_Unbounded_String ("Files.UI")]);

      --  A subunit inherits its parent's context and may add with clauses
      --  of its own, which the two lists above would not see. Every
      --  files-rendering-* body is held to the union of the two, plus the
      --  units the snapshot and frame subunits import for themselves.
      declare
         Search  : Ada.Directories.Search_Type;
         Item    : Ada.Directories.Directory_Entry_Type;
         Started : Boolean := False;
         Stateful_Overlay_Units : constant Project_Tools.Ada_Source.String_List :=
           [To_Unbounded_String ("Guikit.Command_Palette"),
            To_Unbounded_String ("Guikit.Settings_Panel")];
         Family_Allowed : constant Project_Tools.Ada_Source.String_List :=
           [To_Unbounded_String ("Files.Accessibility"),
            To_Unbounded_String ("Files.Breadcrumbs"),
            To_Unbounded_String ("Files.Command_Palette"),
            To_Unbounded_String ("Files.Commands"),
            To_Unbounded_String ("Files.Commands.Status"),
            To_Unbounded_String ("Files.Extension_Labels"),
            To_Unbounded_String ("Files.Extra_Info"),
            To_Unbounded_String ("Files.File_System"),
            To_Unbounded_String ("Files.File_Types"),
            To_Unbounded_String ("Files.Folder_Tree"),
            To_Unbounded_String ("Files.Icon_Themes"),
            To_Unbounded_String ("Files.Fonts"),
            To_Unbounded_String ("Files.Grouping"),
            To_Unbounded_String ("Files.Items"),
            To_Unbounded_String ("Files.Localization"),
            To_Unbounded_String ("Files.Model"),
            To_Unbounded_String ("Files.Quick_Look"),
            To_Unbounded_String ("Files.Root_Labels"),
            To_Unbounded_String ("Files.Settings"),
            To_Unbounded_String ("Files.Shared_Bytes"),
            To_Unbounded_String ("Files.Types"),
            To_Unbounded_String ("Files.UI"),
            To_Unbounded_String ("Files.UTF8")];
      begin
         Ada.Directories.Start_Search
           (Search, Root & "/src", "files-rendering-*.adb", [Ada.Directories.Ordinary_File => True, others => False]);
         Started := True;
         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            Require_Only_Allowed_With_Clauses (Ada.Directories.Full_Name (Item), "Files.", Family_Allowed);
            --  The stateful overlays render at the window layer (CLAUDE.md):
            --  their state cannot pass through the immutable snapshot.
            for Unit of Stateful_Overlay_Units loop
               Require_Only_Allowed_With_Clauses (Ada.Directories.Full_Name (Item), To_String (Unit), No_Units);
            end loop;
            for Unit of Filesystem_Units loop
               Require_Only_Allowed_With_Clauses (Ada.Directories.Full_Name (Item), To_String (Unit), No_Units);
            end loop;
         end loop;
         Ada.Directories.End_Search (Search);
         --  The parent's own spec and body too: the text checks above match
         --  one spelling of a with clause, this one parses them.
         for Suffix in 1 .. 2 loop
            for Unit of Filesystem_Units loop
               Require_Only_Allowed_With_Clauses
                 (Root & "/src/files-rendering.ad" & (if Suffix = 1 then "s" else "b"), To_String (Unit), No_Units);
            end loop;
            for Unit of Stateful_Overlay_Units loop
               Require_Only_Allowed_With_Clauses
                 (Root & "/src/files-rendering.ad" & (if Suffix = 1 then "s" else "b"), To_String (Unit), No_Units);
            end loop;
         end loop;
      exception
         when others =>
            if Started then
               Ada.Directories.End_Search (Search);
            end if;
            raise;
      end;

      Require_Not_Contains
        (Fonts_Body,
         "or else Has_Suffix (Lower, "".ttc"")",
         "font discovery must not select TTC collections that the text renderer cannot initialize");
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
      Require_Not_Contains
        (Fonts_Body,
         "function Is_Required_Zero_Width_Codepoint",
         "font discovery must not keep a local required zero-width glyph classifier");
      Require_Not_Contains_In_Unit
        (Windows_Body,
         "Glyphs.Missing_Glyph_Count > 0",
         "live rendering must not reload fonts during every frame with missing glyphs");
      Require_Not_Contains_In_Unit
        (Rendering_Body,
         "/usr/share/fonts",
         "rendering body must not hard-code system font paths");
      Require_Not_Contains_In_Unit
        (Rendering_Body,
         "Add_Border (X, Y, Draw_Size, Draw_Size, Border_Color);",
         "main-section icon assets must not draw an extra outer square border");
      Require_Not_Contains_In_Unit
        (Rendering_Body,
         "procedure Add_Pixel_Icon",
         "toolbar icon rendering must not use enlarged 7x7 pixel glyphs");
      Require_Not_Contains_In_Unit
        (Rendering_Body,
         "Item_State_Inset",
         "main-view hover and selection blocks must include the item padding area");
      Require_Not_Contains_In_Unit
        (Root & "/src/files-rendering.adb",
         "Prefix & ""...""",
         "rendering fitted text must not append three ASCII dots");
      Require_Not_Contains_In_Unit
        (Rendering_Body,
         "function Is_Required_Zero_Width_Codepoint",
         "text glyph rendering must not keep a local required zero-width glyph classifier");
      Require_Not_Contains_In_Unit
        (Root & "/src/files-rendering.adb",
         "procedure Decode_Next_Codepoint" & ASCII.LF
         & "           (Content   : String;",
         "text glyph rendering must not keep a local UTF-8 decoder");

      --  The biggest bodies may shrink but not grow (CLAUDE.md: keep
      --  files-rendering.adb from regrowing): a new large subprogram goes
      --  into a subunit of its own. Lower a ceiling when a file shrinks.
      declare
         procedure Require_At_Most (Name : String; Lines : Positive) is
            Text  : constant String := To_String (Project_Tools.Text.Read_Text_File (Root & "/src/" & Name));
            Count : constant Natural := Ada.Strings.Fixed.Count (Text, [1 => ASCII.LF]);
         begin
            if Count > Lines then
               Put_Line
                 (Standard_Error,
                  Name & " has" & Count'Image & " lines, over its ceiling of" & Lines'Image
                  & ": move the new code into a subunit");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end Require_At_Most;
      begin
         Require_At_Most ("files-rendering.adb", 1_458);
         Require_At_Most ("files-rendering-build_frame_commands.adb", 920);
         Require_At_Most ("files-application-windows.adb", 1_635);
      end;
   end Check_Rendering_Architecture;

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
         Triangles  : Natural := 0;

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

         procedure Check_Triangle (Text : String) is
            X1 : Natural;
            Y1 : Natural;
            X2 : Natural;
            Y2 : Natural;
            X3 : Natural;
            Y3 : Natural;
         begin
            if not Saw_Grid then
               Fail_Icon (Path, "triangle appears before grid declaration");
            elsif Field (Text, 8) /= "" then
               Fail_Icon (Path, "triangle has too many fields");
            elsif not Try_Parse_Natural (Field (Text, 1), X1)
              or else not Try_Parse_Natural (Field (Text, 2), Y1)
              or else not Try_Parse_Natural (Field (Text, 3), X2)
              or else not Try_Parse_Natural (Field (Text, 4), Y2)
              or else not Try_Parse_Natural (Field (Text, 5), X3)
              or else not Try_Parse_Natural (Field (Text, 6), Y3)
            then
               Fail_Icon (Path, "triangle has nonnumeric fields");
            elsif X1 > Grid or else Y1 > Grid or else X2 > Grid or else Y2 > Grid
              or else X3 > Grid or else Y3 > Grid
            then
               Fail_Icon (Path, "triangle exceeds declared grid");
            elsif not Valid_Icon_Role (Field (Text, 7)) then
               Fail_Icon (Path, "triangle uses an unknown role");
            end if;

            Triangles := Triangles + 1;
         end Check_Triangle;

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
            elsif Starts_With (Line, "tri=") then
               Check_Triangle (Value_After_Prefix (Line, "tri="));
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
         elsif Rectangles = 0 and then Triangles = 0 then
            Fail_Icon (Path, "icon asset must contain at least one shape");
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

   --  files used to carry a per-OS body tree of its own -- trash, volumes,
   --  metadata syscalls, the directory watch, the host locale -- selected by a
   --  Source_Dirs case per host. All of it differs only because the host
   --  differs, which is hostkit's charter, and it lives there now; hostkit's own
   --  checker guards those bodies on the hosts where they are real.
   --
   --  What is left to guard here is that the tree does not come back: a per-OS
   --  directory reappearing in files means the split is being re-litigated one
   --  file at a time, which is how there came to be two of them in one
   --  application in the first place.
   procedure Check_Platform_Bodies is
   begin
      Require_Not_Contains
        (Root & "/files.gpr",
         "src/platform/",
         "files.gpr must not reintroduce a per-OS source directory; per-host code is hostkit's");
      --  Nor per-OS bodies picked by naming exceptions, which is how the last
      --  two (a regular-file open and a rename's write access) came back after
      --  the directory was gone.
      Require_Not_Contains
        (Root & "/files.gpr",
         "package Naming",
         "files.gpr must not select per-OS bodies with a Naming package; per-host code is hostkit's");
      Project_Tools.Files.Require_Contains
        (Root & "/alire.toml",
         "hostkit = ",
         "files must depend on hostkit, which owns every per-host body it used to carry");
   end Check_Platform_Bodies;

   procedure Check_Packaging_Metadata is
      Stage : constant String := Temp_Path ("install-stage");

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
               elsif Full = Root & "/share/i18n" then
                  --  Generated build output, not a source-tracked resource: the
                  --  post-build bundler copies the i18n data tree here from the
                  --  resolved dependency (it is gitignored), and release_check
                  --  verifies its presence. The hand-maintained package.manifest
                  --  lists only the resources that live in this repository.
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
         "native AT-SPI, UI Automation",
         "platform support documentation must record native accessibility provider support");
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
         "Categories=System;FileManager;FileTools;",
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
         "<p>Files is an Ada desktop file explorer for browsing, searching, organizing, and opening local files.</p>",
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
         "Categories=System;FileManager;FileTools;",
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
         "<p>Files is an Ada desktop file explorer for browsing, searching, organizing, and opening local files.</p>",
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

   --  Test coverage by area: each suite must keep registering tests. A check
   --  that only looked for a package name in the suite text was satisfied by
   --  a with clause alone; a suite that lost its tests now fails here.
   procedure Check_Test_Subsystem_Coverage is
      procedure Require_Tests (Suite : String; Expected : Positive) is
         --  Registrations in code: one commented out is not counted.
         Text  : constant String :=
           Code_Of
             (To_String (Project_Tools.Text.Read_Text_File (Root & "/tests/tests/src/files_suite-" & Suite & ".adb")));
         Count : Natural := 0;
         From  : Natural := Text'First;

         --  Whether Code calls a check: a name starting Assert, Expect or
         --  Require (qualified or not: Assert_Equal, Assert_Within and the
         --  suite's other assertion helpers among them) followed by its
         --  arguments or ";", and not the name being declared. A message or
         --  an identifier such as Required_Size does not count, nor does Skip:
         --  a body that only skips checks nothing on any host.
         function Calls_A_Check (Code : String) return Boolean is
            function Identifier_Char (C : Character) return Boolean is
              (C in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_');
            function Declares (At_Name : Positive) return Boolean is
              (At_Name - Code'First >= 10
               and then (Ada.Strings.Fixed.Tail (Code (Code'First .. At_Name - 1), 10) = "procedure "
                         or else Ada.Strings.Fixed.Tail (Code (Code'First .. At_Name - 1), 9) = "function "));
            type Check_Names is array (1 .. 3) of Unbounded_String;
            Names : constant Check_Names :=
              [To_Unbounded_String ("Assert"), To_Unbounded_String ("Expect"), To_Unbounded_String ("Require")];
         begin
            for Name of Names loop
               declare
                  Word : constant String := To_String (Name);
                  From : Positive := Code'First;
                  At_Word : Natural;
                  Next : Positive;
               begin
                  loop
                     At_Word := Ada.Strings.Fixed.Index (Code (From .. Code'Last), Word);
                     exit when At_Word = 0;
                     if At_Word = Code'First or else not Identifier_Char (Code (At_Word - 1)) then
                        Next := At_Word + Word'Length;
                        while Next <= Code'Last and then Identifier_Char (Code (Next)) loop
                           Next := Next + 1;
                        end loop;
                        while Next <= Code'Last and then Code (Next) in ' ' | ASCII.LF | ASCII.CR | ASCII.HT loop
                           Next := Next + 1;
                        end loop;
                        if Next <= Code'Last and then Code (Next) in '(' | ';' and then not Declares (At_Word) then
                           return True;
                        end if;
                     end if;
                     exit when At_Word + Word'Length > Code'Last;
                     From := At_Word + Word'Length;
                  end loop;
               end;
            end loop;
            return False;
         end Calls_A_Check;

         --  A registered test must check something: a body with no Assert
         --  (or a helper named for its Expect/Require) passes always, and so
         --  does one whose only call is a Skip.
         procedure Require_Checks (Routine : String) is
            Unit : constant String :=
              Root & "/tests/tests/src/files_suite-" & Suite & "-"
              & Ada.Characters.Handling.To_Lower (Routine) & ".adb";
            Body_Text : constant String :=
              (if Ada.Directories.Exists (Unit)
               then Code_Of (To_String (Project_Tools.Text.Read_Text_File (Unit)), Blank_Strings => True)
               else Text);
            Start : constant Natural :=
              (if Ada.Directories.Exists (Unit) then Body_Text'First
               else Ada.Strings.Fixed.Index (Body_Text, "procedure " & Routine & " (T"));
            Stop  : constant Natural :=
              (if Start = 0 then 0
               else Ada.Strings.Fixed.Index (Body_Text (Start .. Body_Text'Last), "end " & Routine & ";"));
         begin
            if Start = 0 or else Stop = 0 or else not Calls_A_Check (Body_Text (Start .. Stop)) then
               Put_Line (Standard_Error, "the " & Suite & " test " & Routine & " registers but checks nothing");
               Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
               raise Program_Error;
            end if;
         end Require_Checks;
      begin
         loop
            declare
               At_Name : constant Natural :=
                 Ada.Strings.Fixed.Index (Text (From .. Text'Last), "Register_Routine");
               At_T    : Natural;
               At_Tick : Natural;
            begin
               exit when At_Name = 0;
               Count := Count + 1;
               From := At_Name + 1;
               At_T := Ada.Strings.Fixed.Index (Text (At_Name .. Text'Last), "(T, ");
               At_Tick := (if At_T = 0 then 0 else Ada.Strings.Fixed.Index (Text (At_T .. Text'Last), "'Access"));
               if At_Tick > At_T + 4 then
                  Require_Checks (Text (At_T + 4 .. At_Tick - 1));
               end if;
            end;
         end loop;
         --  Exact, not a floor: a test added without the number moving here
         --  hides the next one lost.
         if Count /= Expected then
            Put_Line
              (Standard_Error,
               "the " & Suite & " test suite registers" & Natural'Image (Count)
               & " tests, not the" & Positive'Image (Expected) & " expected here");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         end if;
      end Require_Tests;
   begin
      --  The floors are the counts as of the last change to a suite, so a
      --  lost test fails here; raise a floor when a suite grows.
      Require_Tests ("settings", 35);
      Require_Tests ("startup", 30);
      Require_Tests ("commands", 39);
      Require_Tests ("model", 54);
      Require_Tests ("interaction", 85);
      Require_Tests ("rendering", 101);
      Require_Tests ("operations", 310);
   end Check_Test_Subsystem_Coverage;

begin
   if not Project_Tools.Files.File_Exists (Root & "/files.gpr") then
      Put_Line (Standard_Error, "check_all must be run from the files project root or tools directory");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Require_Command ("alr");
   Require_Alire_GNAT_15;

   Project_Tools.Files.Write_Text_File (Combined_Suite, Suite_Sources);

   Check_Line_Lengths;
   Check_Consecutive_Empty_Lines;
   Check_Whitespace;
   Check_GNATdoc_Comments;
   Check_Ada_Keyword_Identifiers;
   Check_AUnit_Test_Registration;
   Check_Test_Subsystem_Coverage;
   Check_Ada_Only_Tooling;
   Check_Localization_Usage;
   Check_Clock_Arithmetic;
   Check_Environment_Access;
   Check_Path_Text_Calls;
   Check_Durability_Calls;
   Check_Raw_File_System_Calls;
   Check_Visible_Cache_Invalidation;
   Check_Swallowing_Handlers;
   Check_Shared_Package_State;
   Check_Host_Questions;
   Check_Filetype_Detection_Order;
   Check_Event_Translation_Contract;
   Check_Test_Hooks;
   Check_Command_And_Overlay_Layers;
   Check_Crate_Structure;
   Check_Application_CLI_Surface;
   Check_Rendering_Architecture;
   Check_Icon_Assets;
   Check_Platform_Bodies;
   Check_Packaging_Metadata;
   Check_CLDR_Importer;
   Run ("files build", Root, Alr, [1 => new String'("build")]);
   Check_Executable_CLI_Help;
   Check_Desktop_Runtime_Contract;
   Run ("top-level tests build", Root & "/tests", Alr, [1 => new String'("build")]);
   --  CI has just run the suite with its own settings (a small stack among
   --  them) and passes --skip-suite rather than run it a second time.
   if not (Ada.Command_Line.Argument_Count >= 1 and then Ada.Command_Line.Argument (1) = "--skip-suite") then
      Run ("top-level AUnit tests", Root & "/tests", "./bin/tests", []);
   end if;
   Cleanup_Temps;
   Put_Line ("files project checks passed");
   Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
exception
   when E : Program_Error =>
      --  A check that failed reports itself and raises Program_Error; a
      --  Program_Error from anywhere else is a failure too, never a pass.
      Cleanup_Temps;
      if Ada.Exceptions.Exception_Message (E) /= "" then
         Put_Line (Standard_Error, "files project checks failed: " & Ada.Exceptions.Exception_Information (E));
      end if;
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
   when E : others =>
      Cleanup_Temps;
      Put_Line
        (Standard_Error,
         "files project checks failed: " & Ada.Exceptions.Exception_Message (E));
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
end Check_All;
