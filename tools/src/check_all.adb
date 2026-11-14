with Ada.Command_Line;
with Ada.Characters.Handling;
with Ada.Containers.Indefinite_Hashed_Sets;
with Ada.Containers.Indefinite_Vectors;
with Ada.Containers.Vectors;
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

--  Each check is a subunit of its own, check_all-<check>.adb (the largest
--  split further, check_all-<check>-<part>.adb); this body keeps what several
--  checks share, each helper ahead of the first check that uses it, and runs
--  the checks in order.
procedure Check_All is
   use Ada.Strings.Unbounded;
   use Ada.Text_IO;

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
   --  check_all's own source, this body and every subunit of it, as one
   --  text: the checks of its own exemptions find them in whichever file
   --  they are. Written once at startup (see main body).
   Combined_Check_All : constant String := Temp_Path ("combined-check-all.txt");
   Alr  : constant String := Project_Tools.Processes.Locate_Command ("alr");

   procedure Cleanup_Temps is
   begin
      Project_Tools.Files.Delete_File_If_Present (Combined_Suite);
      Project_Tools.Files.Delete_File_If_Present (Combined_Check_All);
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

   --  Build output directories, never walked by a tree check.
   Generated_Directories : constant Project_Tools.Files.Name_List :=
     [To_Unbounded_String ("bin"), To_Unbounded_String ("obj")];

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
   is separate;

   --  Concatenate the aggregator and every split section body of the AUnit
   --  suite, so contract checks can assert against the suite as a whole.
   --  Every suite body, subunits included: a test moved into its own
   --  files_suite-<suite>-test_<name>.adb must still count.
   function Suite_Sources return String is
      Dir    : constant String := Root & "/tests/tests/src";
      Result : Unbounded_String;
   begin
      for Path of Project_Tools.Files.List_Tree (Dir, "files_suite*.adb", Generated_Directories) loop
         Append (Result, Project_Tools.Text.Read_Text_File (To_String (Path)));
         Append (Result, ASCII.LF);
      end loop;
      return To_String (Result);
   end Suite_Sources;

   --  Concatenate check_all.adb and its subunits (check_all-*.adb).
   function Check_All_Sources return String is
      Dir    : constant String := Root & "/tools/src";
      Result : Unbounded_String;
   begin
      for Path of Project_Tools.Files.List_Tree (Dir, "check_all*.adb", Generated_Directories) loop
         Append (Result, Project_Tools.Text.Read_Text_File (To_String (Path)));
         Append (Result, ASCII.LF);
      end loop;
      return To_String (Result);
   end Check_All_Sources;

   procedure Check_CLDR_Importer is separate;

   procedure Check_Line_Lengths_In_File (Path : String) is separate;

   procedure Check_Consecutive_Empty_Lines_In_File (Path : String) is separate;

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

   procedure Check_Whitespace_In_File (Path : String) is separate;

   --  Every text file of the project the line checks read: the text files
   --  (Is_Text_Project_File) of the source, test, tooling, configuration and
   --  share trees, build output skipped, and the manifests, project files and
   --  ignore lists at the roots of the main, test and tooling crates.
   function Project_Text_Files return Project_Tools.Files.Path_List is
      use type Project_Tools.Files.Path_List;

      function Text_Files_In (Path : String) return Project_Tools.Files.Path_List is
         Found  : constant Project_Tools.Files.Path_List :=
           Project_Tools.Files.List_Tree (Path, "*", Generated_Directories);
         Result : Project_Tools.Files.Path_List (1 .. Found'Length);
         Last   : Natural := 0;
      begin
         for Item of Found loop
            if Is_Text_Project_File (Ada.Directories.Simple_Name (To_String (Item))) then
               Last := Last + 1;
               Result (Last) := Item;
            end if;
         end loop;
         return Result (1 .. Last);
      end Text_Files_In;

      At_Roots : constant Project_Tools.Files.Path_List :=
        [To_Unbounded_String (Root & "/.gitignore"),
         To_Unbounded_String (Root & "/alire.toml"),
         To_Unbounded_String (Root & "/files.gpr"),
         To_Unbounded_String (Root & "/tests/.gitignore"),
         To_Unbounded_String (Root & "/tests/alire.toml"),
         To_Unbounded_String (Root & "/tests/tests.gpr"),
         To_Unbounded_String (Root & "/tools/alire.toml"),
         To_Unbounded_String (Root & "/tools/files_check_all.gpr")];
   begin
      return Text_Files_In (Root & "/config")
        & Text_Files_In (Root & "/src")
        & Text_Files_In (Root & "/tests/tests/src")
        & Text_Files_In (Root & "/tools/config")
        & Text_Files_In (Root & "/tools/src")
        & Text_Files_In (Root & "/share")
        & At_Roots;
   end Project_Text_Files;

   --  One pass over Project_Text_Files running every line check on each:
   --  line length, consecutive empty lines and, where it applies
   --  (Is_Whitespace_Checked_File), tabs and trailing whitespace.
   procedure Check_Project_Text_Files is separate;

   --  Visit every Ada source (".ads" and ".adb") under Path, build output
   --  skipped, but the one whose simple name is Except.
   procedure For_Each_Ada_Source
     (Path   : String;
      Visit  : not null access procedure (Path : String);
      Except : String := "") is
   begin
      for Source of Project_Tools.Files.List_Tree (Path, "*.ad[sb]", Generated_Directories) loop
         if Ada.Directories.Simple_Name (To_String (Source)) /= Except then
            Visit (To_String (Source));
         end if;
      end loop;
   end For_Each_Ada_Source;

   procedure Check_GNATdoc_In_File (Path : String) is separate;

   procedure Check_GNATdoc_Comments is separate;

   procedure Check_Ada_Keyword_Identifier_In_File (Path : String) is separate;

   procedure Check_Ada_Keyword_Identifiers is separate;

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

   function Is_Ada_Identifier_Char (Char : Character) return Boolean is
     (Char in 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_');

   --  Ada source as tokens, for the checks that must not be fooled by a
   --  comment or a string literal that spells what they look for, nor by
   --  how a statement is laid out over lines.
   package Tokens is
      --  A word (identifier, keyword or number), a string or character
      --  literal (its contents, quotes and doubling undone), or a delimiter.
      type Token_Kind is (Word, Literal, Symbol);

      --  One token: its kind and its text, lower case.
      type Token is record
         Kind : Token_Kind := Symbol;
         Text : Unbounded_String;
      end record;

      package Token_Vectors is new Ada.Containers.Vectors (Index_Type => Positive, Element_Type => Token);

      --  The tokens of a source, in order.
      subtype Token_List is Token_Vectors.Vector;

      --  @param Item Token to test.
      --  @param Text Delimiter text, lower case.
      --  @return True when Item is the delimiter Text.
      function Is_Symbol (Item : Token; Text : String) return Boolean is
        (Item.Kind = Symbol and then To_String (Item.Text) = Text);

      --  @param Item Token to test.
      --  @param Text Word, lower case.
      --  @return True when Item is the word Text.
      function Is_Word (Item : Token; Text : String) return Boolean is
        (Item.Kind = Word and then To_String (Item.Text) = Text);

      --  The tokens of an Ada source, lower-cased, comments dropped. A quote
      --  after a word (but one a character literal may follow, as "when")
      --  or ")" is an attribute's tick (String'("x")); any other one with a
      --  character two places on opens a character literal.
      --  @param Source Ada source text.
      --  @return Its tokens, in order.
      function Tokens_Of (Source : String) return Token_List;
   end Tokens;

   package body Tokens is separate;

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
   is separate;

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
   procedure Require_Registered_Routine (Routine : String; Message : String) is
      Code : constant String := Code_Of (To_String (Project_Tools.Text.Read_Text_File (Combined_Suite)));
   begin
      if Ada.Strings.Fixed.Index (Code, "(T, " & Routine & "'Access") = 0 then
         Put_Line (Standard_Error, Routine & ", " & Message & ", must stay registered");
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         raise Program_Error;
      end if;
   end Require_Registered_Routine;

   --  Every test package is in the suite, and every Test_* routine a suite
   --  body declares is registered there: a declared, stubbed and written
   --  test that nobody registers compiles cleanly and never runs.
   procedure Check_AUnit_Test_Registration is separate;

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

   procedure Check_Ada_Only_Tooling_File
     (Name : String;
      Full : String) is separate;

   procedure Check_Ada_Only_Tooling_In_Tree (Path : String) is separate;

   procedure Check_Ada_Only_Tooling_At_Project_Root is separate;

   procedure Check_Ada_Only_Tooling is separate;

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

   function Looks_Like_User_Text (Literal : String) return Boolean is separate;

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

   procedure Check_No_User_Text_Literals (Path : String) is separate;

   procedure Check_Command_Localization_Keys is separate;

   procedure Check_Catalog_Unique_Keys is separate;

   procedure Check_Catalog_Format is separate;

   procedure Check_Catalog_Baseline_Keys is separate;

   procedure Check_Error_Localization_Test_Coverage is separate;

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

   procedure Check_Indirect_Localization_Keys_In_File (Path : String) is separate;

   procedure Check_Direct_Localization_Call_Keys_In_File (Path : String) is separate;

   --  Which host this is, is asked of Hostkit.Host.Current: the build's OS
   --  string spelled the same question a second way, and the code around each
   --  spelling drifted (a separator rule here, a path rule there).
   procedure Check_Host_Questions is separate;

   --  Thumbnails are made on the refresh tasks and on the UI thread at once,
   --  and images are decoded there and on the Quick Look decoder's task. A
   --  variable at the package level is shared by them, unguarded: one held
   --  the path being written and was overwritten mid-write. State belongs in
   --  the subprogram, or in a protected object.
   procedure Check_Shared_Package_State is separate;

   --  A timer that subtracts from the clock (Clock - Since) overflows when
   --  Since is Time_First, the "never" many timers start from; that raised
   --  on every pass of the event loop and froze every window. Timers in src/
   --  ask Files.Timing.Elapsed, or add (Clock >= Since + Span), instead.
   procedure Check_Clock_Arithmetic is separate;

   --  The environment is read in one place: Files.Environment asks Hostkit,
   --  which knows how each host keeps it (a variable set to "" is no variable
   --  on Windows), so no unit answers differently from the rest.
   procedure Check_Environment_Access is separate;

   --  GNAT's Ada.Directories reads a path's text with a 256-character
   --  component limit on Windows (Name_Error past it): leaves, parents and
   --  joins go through Files.Fs_Primitives (Hostkit.Path_Text) or
   --  Hostkit.Fs.Join. Simple_Name of a search entry is fine, written with
   --  its Directory_Entry name.
   procedure Check_Path_Text_Calls is separate;

   --  Every flush goes through Files.Durability, where the suite can make
   --  one fail on every host: a Hostkit.Durability.Sync_* call elsewhere in
   --  src/ is a flush no test can fail.
   procedure Check_Durability_Calls is separate;

   --  GNAT's Windows runtime refuses a path past 260 characters before
   --  Windows is asked -- in Ada.Directories, GNAT.OS_Lib,
   --  GNAT.Directory_Operations and System.File_IO (Stream_IO and Text_IO
   --  Open and Create) alike -- so a folder deep enough could be listed but
   --  not opened, copied or deleted. By-path file-system calls in src/ go
   --  through Files.Fs_Primitives or Hostkit (Fs, Regular_Files,
   --  Directory_Listing, Path_Text), which reach any depth. A package
   --  renaming one of these units is read as the unit, and a use clause for
   --  one is refused: it would hide the calls.
   procedure Check_Raw_File_System_Calls is separate;

   --  The model caches its visible rows (Support.Ensure_Visible_Map); a
   --  subprogram that writes the items, their order, the filter or the
   --  search flag must drop the cache (Invalidate_Visible) or every lookup
   --  after it serves the old rows. Checked per top-level subprogram of each
   --  files-model*.adb (a subunit is one), comments stripped, whitespace run
   --  together so a call split over lines is still seen.
   procedure Check_Visible_Cache_Invalidation is separate;

   --  A handler that catches everything and carries on must say what it
   --  caught (Files.Diagnostics.Note), or a failure vanishes without a trace
   --  even with FILES_DIAGNOSTICS set: a "when others" exception handler in
   --  src/ either raises or names its occurrence and notes it. Files.Diagnostics
   --  and Files.Environment (which Note is built on) are exempt. The note (or
   --  other hand-on) must be a top-level statement of the handler, run on every
   --  path: one inside an if, case, loop or block leaves the other paths silent,
   --  and only a call of Diagnostics.Note itself counts (not Footnote (E, ...)).
   procedure Check_Swallowing_Handlers is separate;

   procedure Check_Localization_Usage is separate;

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
   is separate;

   procedure Check_Filetype_Detection_Order is separate;

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

   procedure Check_Event_Translation_Contract is separate;

   --  The test suite steers a few behaviours through FILES_TEST_* variables
   --  (no volume trash, its scratch area). The shipped program reads them
   --  too, so they stay in the units listed here: a new one is a decision,
   --  not a convenience.
   --  The commands are named without the model (Files.Commands), so input
   --  translation does not depend on it; what needs the model is in
   --  Files.Commands.Status and .Execution. The model holds the palette's and
   --  the settings panel's state; the window layer (Files.Overlays) draws
   --  and localizes them.
   procedure Check_Command_And_Overlay_Layers is separate;

   --  Test hooks are environment variables named FILES_TEST_*, read only in
   --  the listed files. FILES_TRASH_BACKEND is no test hook -- production
   --  reads it, to force another host's trash layout -- but the suite leans
   --  on it to run the Windows and macOS backends on Linux, so it is held to
   --  the same rule: one known reader. A second one would let the override
   --  switch production behaviour where nobody reviewed it. Either name built
   --  in pieces -- joined literals or characters, in parentheses or
   --  qualified, or a string constant or variable of any unit in src/
   --  (aliased, constrained, in a list, renamed, split over lines) joined to
   --  one -- counts as read, and so does either name in any letter case:
   --  Windows looks variables up regardless of case.
   procedure Check_Test_Hooks is separate;

   procedure Check_Crate_Structure is separate;

   procedure Check_Application_CLI_Surface is separate;

   procedure Check_Executable_CLI_Help is separate;

   procedure Check_Desktop_Runtime_Contract is separate;

   procedure Check_Rendering_Architecture is separate;

   procedure Check_Icon_Assets is separate;

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
   procedure Check_Platform_Bodies is separate;

   procedure Check_Packaging_Metadata is separate;

   --  Test coverage by area: each suite must keep registering tests. A check
   --  that only looked for a package name in the suite text was satisfied by
   --  a with clause alone; a suite that lost its tests now fails here.
   procedure Check_Test_Subsystem_Coverage is separate;

begin
   if not Project_Tools.Files.File_Exists (Root & "/files.gpr") then
      Put_Line (Standard_Error, "check_all must be run from the files project root or tools directory");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Require_Command ("alr");
   Require_Alire_GNAT_15;

   Project_Tools.Files.Write_Text_File (Combined_Suite, Suite_Sources);
   Project_Tools.Files.Write_Text_File (Combined_Check_All, Check_All_Sources);

   Check_Project_Text_Files;
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
