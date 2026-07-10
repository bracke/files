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
             [1 => new String'("exec"),
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

   procedure Check_AUnit_Test_Registration is
   begin
      Project_Tools.AUnit_Checks.Require_Registered_Test_Packages
        (Test_Dir         => Root & "/tests/tests/src",
         Spec_Pattern     => "files_suite-*.ads",
         Suite_Path       => Root & "/tests/tests/src/files_suite.adb",
         Suite_Add_Prefix => "Result.Add_Test (",
         Suite_Add_Suffix => ".Suite)",
         Section_Marker   => "function Suite");
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

      --  Delegate Python-artifact detection to the shared tree check across the
      --  same source trees the inline scan covers.
      Scan_Python (Root & "/config");
      Scan_Python (Root & "/scripts");
      Scan_Python (Root & "/src");
      Scan_Python (Root & "/tests");
      Scan_Python (Root & "/tools");
      Scan_Python (Root & "/share");

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

   procedure Check_Filetype_Detection_Order is
      File_Types_Body : constant String := Root & "/src/files-file_types.adb";
   begin
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
      --  Lock the Files.* import boundary through the shared helper: event
      --  translation may only import Files.UTF8 and Files.UI, which forbids the
      --  mutable model, filesystem-operation, and filesystem-inspection units.
      Require_Only_Allowed_With_Clauses
        (Events_Body,
         "Files.",
         [To_Unbounded_String ("Files.UTF8"),
          To_Unbounded_String ("Files.UI")]);
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
   end Check_Event_Translation_Contract;

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
         "guikit = ""*""",
         "files must depend on the guikit crate");
      Project_Tools.Files.Require_Contains
        (Main_Manifest,
         "guikit = { path = ""../guikit"" }",
         "files must pin guikit to the local relative crate");
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
        (Root & "/tools/src/check_all.adb",
         "Run (""top-level tests build"", Root & ""/tests"", Alr, [1 => new String'(""build"")]);",
         "full validation must build the top-level tests sub-crate");
      Project_Tools.Files.Require_Contains
        (Root & "/tools/src/check_all.adb",
         "Run (""top-level AUnit tests"", Root & ""/tests"", ""./bin/tests"", []);",
         "full validation must run the top-level tests sub-crate");
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
      Require_Not_Contains
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
      Require_Not_Contains
        (Windows_Body,
         "Glyphs.Missing_Glyph_Count /= 0",
         "headless smoke must not reject otherwise visible frames solely for missing-glyph fallback");
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
        (Combined_Suite,
         "runtime capabilities expose drop event-source automation",
         "desktop runtime tests must cover drop event-source automation");
      Require_Not_Contains
        (Windows_Body,
         "Runtime.Last_Missing_Glyph_Count = 0",
         "live smoke must not reject otherwise visible frames solely for missing-glyph fallback");
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
            "Files.Controller.",
            Label & " must not route controller actions");
         Require_Not_Contains
           (Path,
            "Files.Application.",
            Label & " must not call application startup logic");
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

      --  Lock the Files.* import boundary of the rendering layer through the
      --  shared helper. The allow-lists are the units each source actually
      --  imports today, so the operations, controller, and application-startup
      --  units (and any other new Files.* dependency) are rejected.
      Require_Only_Allowed_With_Clauses
        (Rendering_Spec,
         "Files.",
         [To_Unbounded_String ("Files.Breadcrumbs"),
          To_Unbounded_String ("Files.Commands"),
          To_Unbounded_String ("Files.File_System"),
          To_Unbounded_String ("Files.Folder_Tree"),
          To_Unbounded_String ("Files.Model"),
          To_Unbounded_String ("Files.Quick_Look"),
          To_Unbounded_String ("Files.Settings"),
          To_Unbounded_String ("Files.Types")]);
      Require_Only_Allowed_With_Clauses
        (Rendering_Body,
         "Files.",
         [To_Unbounded_String ("Files.Accessibility"),
          To_Unbounded_String ("Files.Command_Palette"),
          To_Unbounded_String ("Files.File_Types"),
          To_Unbounded_String ("Files.Fonts"),
          To_Unbounded_String ("Files.Localization"),
          To_Unbounded_String ("Files.Platform.Metadata"),
          To_Unbounded_String ("Files.UTF8"),
          To_Unbounded_String ("Files.UI")]);

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
      Require_Not_Contains
        (Windows_Body,
         "Glyphs.Missing_Glyph_Count > 0",
         "live rendering must not reload fonts during every frame with missing glyphs");
      Require_Not_Contains
        (Rendering_Body,
         "/usr/share/fonts",
         "rendering body must not hard-code system font paths");
      Require_Not_Contains
        (Rendering_Body,
         "Add_Border (X, Y, Draw_Size, Draw_Size, Border_Color);",
         "main-section icon assets must not draw an extra outer square border");
      Require_Not_Contains
        (Rendering_Body,
         "procedure Add_Pixel_Icon",
         "toolbar icon rendering must not use enlarged 7x7 pixel glyphs");
      Require_Not_Contains
        (Rendering_Body,
         "Item_State_Inset",
         "main-view hover and selection blocks must include the item padding area");
      Require_Not_Contains
        (Vulkan_Body,
         "Renderer.Command_Buffers (Positive (Image_Index) + 1)",
         "Vulkan presentation must not convert zero image indexes to Positive before adding one");
      Require_Not_Contains
        (Root & "/src/files-rendering.adb",
         "Prefix & ""...""",
         "rendering fitted text must not append three ASCII dots");
      Require_Not_Contains
        (Rendering_Body,
         "function Is_Required_Zero_Width_Codepoint",
         "text glyph rendering must not keep a local required zero-width glyph classifier");
      Require_Not_Contains
        (Root & "/src/files-rendering.adb",
         "procedure Decode_Next_Codepoint" & ASCII.LF
         & "           (Content   : String;",
         "text glyph rendering must not keep a local UTF-8 decoder");
      Require_Not_Contains
        (Root & "/src/files-rendering-vulkan.adb",
         "mag_Filter               => Vk.FILTER_LINEAR",
         "Vulkan atlas samplers must not blur UI atlases with linear magnification");
      Require_Not_Contains
        (Root & "/src/files-rendering-vulkan.adb",
         "min_Filter               => Vk.FILTER_LINEAR",
         "Vulkan atlas samplers must not blur UI atlases with linear minification");
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

   --  Robust test-coverage signal (replaces the removed brittle exact-message
   --  contract checks): require the test suite to exercise each production
   --  subsystem. The compiler and the AUnit suite verify behavior; this only
   --  guards against a subsystem silently losing all test coverage.
   procedure Check_Test_Subsystem_Coverage is
      Suite : constant String := To_String (Project_Tools.Text.Read_Text_File (Combined_Suite));
      procedure Require_Tested (Token : String; What : String) is
      begin
         if not Project_Tools.Text.Contains (Suite, Token) then
            Put_Line
              (Standard_Error,
               "test suite must exercise " & What & " (missing reference: " & Token & ")");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
            raise Program_Error;
         end if;
      end Require_Tested;
   begin
      Require_Tested ("Files.Rendering", "the rendering subsystem");
      Require_Tested ("Files.Events", "the events subsystem");
      Require_Tested ("Files.Model", "the model subsystem");
      Require_Tested ("Files.Controller", "the controller subsystem");
      Require_Tested ("Files.Commands", "the command registry");
      Require_Tested ("Files.Command_Palette", "the command palette");
      Require_Tested ("Files.Settings", "the settings subsystem");
      Require_Tested ("Files.Operations", "the operations subsystem");
      Require_Tested ("Files.File_System", "the file-system subsystem");
      Require_Tested ("Files.UI", "the UI layout helpers");
      Require_Tested ("Files.Accessibility", "the accessibility bridge");
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
   Check_Filetype_Detection_Order;
   Check_Event_Translation_Contract;
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
