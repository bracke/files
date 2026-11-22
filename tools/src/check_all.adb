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
with Project_Tools.Ada_Source.Tokens;
with Project_Tools.AUnit_Checks;
with Project_Tools.Files;
with Project_Tools.Processes;
with Project_Tools.Source_Budgets;
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

   --  Problems found so far. A check reports each one it finds (Report) and
   --  carries on, so one run lists them all; the run fails once, after the
   --  last check and before the build and the suite.
   Problems : Natural := 0;

   --  Count Count problems that were reported elsewhere (a shared check of
   --  Project_Tools that prints its own), and fail the run.
   procedure Count_Problems (Count : Natural) is
   begin
      if Count > 0 then
         Problems := Problems + Count;
         Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      end if;
   end Count_Problems;

   --  Report one problem: Message on standard error, counted, and the run's
   --  exit status set to failure.
   procedure Report (Message : String) is
   begin
      Put_Line (Standard_Error, Message);
      Count_Problems (1);
   end Report;

   --  Run one check, Name for what it guards. A check reports each problem
   --  and carries on; an exception is one that could not finish (a missing
   --  prerequisite, a fault of its own), named and counted as one problem,
   --  and the next check runs.
   procedure Run_Check (Name : String; Check : not null access procedure) is
   begin
      Check.all;
   exception
      when E : others =>
         Report (Name & " stopped early: " & Ada.Exceptions.Exception_Information (E));
   end Run_Check;

   --  Whether any check has reported a problem; if so, the run says how many
   --  and its exit status is already failure.
   function Problems_Found (Before : String) return Boolean is
   begin
      if Problems > 0 then
         Put_Line
           (Standard_Error,
            "files project checks failed:" & Natural'Image (Problems) & " problem(s) found before " & Before);
      end if;
      return Problems > 0;
   end Problems_Found;

   --  The guards a check calls report and carry on, so one run lists every
   --  problem: these stand in for Project_Tools' Require_* guards, which
   --  print and raise Program_Error at the first one.

   --  Path's text, as it is (not only its code), must hold Pattern;
   --  reported as Message: Path otherwise, or when Path is missing.
   procedure Require_In_Text (Path : String; Pattern : String; Message : String) is
   begin
      if not Project_Tools.Files.File_Exists (Path) or else not Project_Tools.Files.File_Contains (Path, Pattern) then
         Report (Message & ": " & Path);
      end if;
   end Require_In_Text;

   --  Every path of Paths names a file; each missing one is reported.
   procedure Require_Present (Paths : Project_Tools.Files.Path_List; Message : String) is
   begin
      for Path of Paths loop
         if not Project_Tools.Files.File_Exists (To_String (Path)) then
            Report (Message & ": " & To_String (Path));
         end if;
      end loop;
   end Require_Present;

   --  Run one Project_Tools guard that prints every problem it finds itself
   --  and then raises Program_Error: counted as one problem, and the check
   --  that called it carries on with its next file.
   procedure Guarded (Guard : not null access procedure) is
   begin
      Guard.all;
   exception
      when Program_Error =>
         Count_Problems (1);
   end Guarded;

   --  Project_Tools.Ada_Source's guard, as one that carries on: this
   --  homograph hides the use-visible one in every check.
   procedure Require_Only_Allowed_With_Clauses
     (Source_Path : String;
      Prefix      : String;
      Allowed     : String_List;
      Quiet       : Boolean := False)
   is
      procedure Guard is
      begin
         Project_Tools.Ada_Source.Require_Only_Allowed_With_Clauses (Source_Path, Prefix, Allowed, Quiet);
      end Guard;
   begin
      Guarded (Guard'Access);
   end Require_Only_Allowed_With_Clauses;
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
         Report ("could not run `alr exec -- gnatls --version`");
      elsif Ada.Strings.Fixed.Index (To_String (Output), "GNATLS 15.") = 0 then
         Report ("wrong Ada compiler: files validation must use Alire GNAT 15; got: "
            & To_String (Output));
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
        or else Ends_With (Name, ".yml")
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

   --  Report each line of Path holding a byte above 127: Alire's TOML reader
   --  takes a manifest to be ASCII.
   procedure Check_Ascii_Only_In_File (Path : String) is separate;

   --  Every text file of the project the line checks read: the text files
   --  (Is_Text_Project_File) of the source, test, tooling, configuration and
   --  share trees, build output skipped, and the manifests, project files and
   --  ignore lists at the roots of the main, test and tooling crates, the
   --  release manifest and the CI workflow.
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
         To_Unbounded_String (Root & "/.github/workflows/ci.yml"),
         To_Unbounded_String (Root & "/alire.release.toml"),
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
        & Text_Files_In (Root & "/tools/i18n_bundle")
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

   --  Text with its Ada comments removed, so a registration that is only
   --  mentioned in a comment, or commented out, does not count as one. With
   --  Blank_Strings the contents of string literals are spaces too, their
   --  quotes kept. The one Ada lexer, Project_Tools.Ada_Source.Tokens.
   function Code_Of (Text : String; Blank_Strings : Boolean := False) return String
     renames Project_Tools.Ada_Source.Tokens.Without_Comments;

   --  Whether a pattern spells a string literal: one that does is looked
   --  for in code with its strings kept, every other one with them blanked.
   function Quotes (Pattern : String) return Boolean is
     (Ada.Strings.Fixed.Index (Pattern, """") > 0);

   --  Ada source as tokens, for the checks that must not be fooled by a
   --  comment or a string literal that spells what they look for, nor by
   --  how a statement is laid out over lines.
   package Tokens renames Project_Tools.Ada_Source.Tokens;

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
         Report (Routine & ", " & Message & ", must stay registered");
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

   function Looks_Like_User_Text (Literal : String) return Boolean is separate;

   --  The length in tokens of a developer-diagnostic pragma header ("pragma
   --  Compile_Time_Error" and friends) beginning at Toks (From), or 0 when
   --  none does. Their string arguments are compile-time messages for
   --  developers, never localizable user text, so the scanner skips the whole
   --  statement.
   function Diagnostic_Pragma_Length (Toks : Tokens.Token_List; From : Positive) return Natural is
      use Tokens;
   begin
      if From + 1 <= Toks.Last_Index
        and then Is_Word (Toks (From), "pragma")
        and then (Is_Word (Toks (From + 1), "compile_time_error")
                  or else Is_Word (Toks (From + 1), "compile_time_warning")
                  or else Is_Word (Toks (From + 1), "assert"))
      then
         return 2;
      end if;

      return 0;
   end Diagnostic_Pragma_Length;

   procedure Check_No_User_Text_Literals (Path : String) is separate;

   procedure Check_Catalog_Unique_Keys is separate;

   procedure Check_Catalog_Format is separate;

   procedure Check_Catalog_Baseline_Keys is separate;

   procedure Check_Error_Localization_Test_Coverage is separate;

   package Key_Sets is new Ada.Containers.Indefinite_Hashed_Sets
     (Element_Type        => String,
      Hash                => Ada.Strings.Hash,
      Equivalent_Elements => "=");

   --  The default catalog's text, read once: every key check asks it.
   Catalog_Text   : Unbounded_String;
   Catalog_Loaded : Boolean := False;

   --  The namespaces of the catalog's own keys ("status." of en.status.items):
   --  a literal in one of them names a localization key. Read from the
   --  catalog, so a new namespace is checked the day its first key lands.
   Catalog_Namespaces : Key_Sets.Set;

   --  Keys already reported missing, so the direct, indirect and command
   --  checks, which overlap, report each missing key once.
   Reported_Missing_Keys : Key_Sets.Set;

   procedure Load_Catalog is
      Path : constant String := Root & "/share/files.catalog";
   begin
      if Catalog_Loaded then
         return;
      end if;
      Catalog_Loaded := True;
      if not Project_Tools.Files.File_Exists (Path) then
         return;
      end if;
      Catalog_Text := ASCII.LF & Project_Tools.Text.Read_Text_File (Path);
      declare
         Text  : constant String := To_String (Catalog_Text);
         Start : Natural := Ada.Strings.Fixed.Index (Text, ASCII.LF & "en.");
      begin
         while Start > 0 loop
            declare
               First : constant Positive := Start + 4;
               Dot   : constant Natural := Ada.Strings.Fixed.Index (Text, ".", First);
               Eol   : constant Natural := Ada.Strings.Fixed.Index (Text, [ASCII.LF], First);
            begin
               if Dot > First and then (Eol = 0 or else Dot < Eol) then
                  Catalog_Namespaces.Include (Text (First .. Dot));
               end if;
               Start := Ada.Strings.Fixed.Index (Text, ASCII.LF & "en.", First);
            end;
         end loop;
      end;
   end Load_Catalog;

   function In_Localization_Namespace (Key : String) return Boolean is
      Dot : constant Natural := Ada.Strings.Fixed.Index (Key, ".");
   begin
      Load_Catalog;
      return Dot > Key'First and then Catalog_Namespaces.Contains (Key (Key'First .. Dot));
   end In_Localization_Namespace;

   --  Whether Text begins some catalog key without being one: a prefix the
   --  code completes at run time ("key.name." & Key). Callers ask
   --  only for a literal that '&' follows; a bare literal that is a prefix
   --  is a truncated key, not a fragment.
   function Is_Key_Fragment (Text : String) return Boolean is
   begin
      Load_Catalog;
      return Ada.Strings.Fixed.Index (To_String (Catalog_Text), ASCII.LF & "en." & Text & " = ") = 0
        and then Ada.Strings.Fixed.Index (To_String (Catalog_Text), ASCII.LF & "en." & Text) > 0;
   end Is_Key_Fragment;

   --  Key must be in the default catalog; Where names the source that asks
   --  for it. A key already reported missing is not reported again.
   procedure Require_Catalog_Key (Where : String; Key : String) is
   begin
      Load_Catalog;
      if Ada.Strings.Fixed.Index (To_String (Catalog_Text), ASCII.LF & "en." & Key & " = ") = 0
        and then not Reported_Missing_Keys.Contains (Key)
      then
         Reported_Missing_Keys.Include (Key);
         Report (Where & ": localization key must exist in share/files.catalog: " & Key);
      end if;
   end Require_Catalog_Key;

   procedure Check_Command_Localization_Keys is separate;

   function Is_Complete_Localization_Key (Key : String) return Boolean is
   begin
      return
        Key /= ""
        and then Key /= "settings.conf"
        and then Key (Key'Last) /= '.'
        and then In_Localization_Namespace (Key);
   end Is_Complete_Localization_Key;

   function Is_Indirect_Localization_Key (Key : String) return Boolean is
   begin
      return
        Key /= ""
        and then Key (Key'Last) /= '.'
        and then Key /= "settings.conf"
        and then not Contains (Key, "|")
        and then In_Localization_Namespace (Key);
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
   --  joins go through Files.IO.Fs_Primitives (Hostkit.Path_Text) or
   --  Hostkit.Fs.Join. Simple_Name of a search entry is fine, written with
   --  its Directory_Entry name.
   procedure Check_Path_Text_Calls is separate;

   --  Every flush goes through Files.IO.Durability, where the suite can make
   --  one fail on every host: a Hostkit.Durability.Sync_* call elsewhere in
   --  src/ is a flush no test can fail.
   procedure Check_Durability_Calls is separate;

   --  GNAT's Windows runtime refuses a path past 260 characters before
   --  Windows is asked -- in Ada.Directories, GNAT.OS_Lib,
   --  GNAT.Directory_Operations and System.File_IO (Stream_IO and Text_IO
   --  Open and Create) alike -- so a folder deep enough could be listed but
   --  not opened, copied or deleted. By-path file-system calls in src/ go
   --  through Files.IO.Fs_Primitives or Hostkit (Fs, Regular_Files,
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
         Report ("guarded file is missing: " & Path & " (" & Message & ")");
         return;
      end if;
      if Ada.Strings.Fixed.Index
          (Code_Of (To_String (Project_Tools.Text.Read_Text_File (Path)), Blank_Strings => not Quotes (Pattern)),
           Pattern) > 0
      then
         Report (Message);
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
         Report (Path & ": " & Message);
      end if;
   end Require_Contains;

   --  Like Require_Contains, but the pattern may be in the unit whose body is
   --  Base_Path or in any of its subunits (Is_Subunit_Of: a child unit's
   --  body named <stem>-*.adb does not count): a call the guardrail asks for
   --  still counts once a split moves it into a subunit.
   procedure Require_Contains_In_Unit
     (Base_Path : String;
      Pattern   : String;
      Message   : String)
   is separate;

   procedure Check_Localization_Usage is separate;

   --  Like Require_Not_Contains, but also scans every body of the unit family
   --  whose body is Base_Path -- its subunits and its child units' bodies,
   --  the sibling files named <stem>-*.adb. A guardrail expressed over a unit
   --  body therefore keeps covering code that has since been moved out into
   --  subunits or children, so a split never silently narrows its reach.
   procedure Require_Not_Contains_In_Unit
     (Base_Path : String;
      Pattern   : String;
      Message   : String)
   is separate;

   --  Like Require_Not_Contains_In_Unit, but Pattern is Ada read as tokens:
   --  a match is the same words, literals and delimiters in the same order,
   --  however they are laid out over lines or spaced, comments ignored. A
   --  guarded unit that no longer exists is refused too, so a guard cannot
   --  pass silently for want of a file to look in.
   procedure Require_No_Tokens_In_Unit
     (Base_Path : String;
      Pattern   : String;
      Message   : String)
   is separate;

   --  Refuse a string literal containing Text in the unit family whose body
   --  is Base_Path (as Require_Not_Contains_In_Unit scans it). The text
   --  checks blank a literal's contents unless their pattern holds a quote,
   --  so what only a literal can say -- a path, a message -- is looked for
   --  here.
   procedure Require_No_Literal_In_Unit
     (Base_Path : String;
      Text      : String;
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

   --  The commands are named without the model (Files.Commands), so input
   --  translation does not depend on it; what needs the model is in
   --  Files.Commands.Status and Files.Controller.Execute_Pure_Command. The
   --  model holds the palette's and the settings panel's state; the window
   --  layer (Files.Overlays) draws and localizes them.
   procedure Check_Command_And_Overlay_Layers is separate;

   --  Files.Jobs imports nothing but its own family, Files.IO and the leaf units.
   procedure Check_Job_Layer is separate;

   --  Nothing Files.File_System reaches, however indirectly, is Files.Settings:
   --  it classifies items by Files.File_Types.Classification alone.
   procedure Check_File_System_Closure is separate;

   --  No rendering unit calls a Files.Model subprogram that takes the
   --  Window_Model "in out"; the mutators are read from the model's specs.
   procedure Check_Rendering_Model_Reads is separate;

   --  The test suite steers a few behaviours through FILES_TEST_* variables
   --  (no volume trash, its scratch area). The shipped program reads them
   --  too, so they stay in the units listed here: a new one is a decision,
   --  not a convenience.
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

   --  A test that arms a process-wide test hook (Refuse_Next_Launch,
   --  Fail_Stage_Sync, Set_Unavailable (True), ...) disarms it on its failure
   --  path too: an exception handler of the test (or of the block right after
   --  the arming) that calls the matching disarm, directly or through a
   --  procedure of the test's own, or an object of a Limited_Controlled guard
   --  whose Finalize does. Otherwise a failing assertion leaves the hook armed
   --  and the tests after it fail for no reason of their own.
   procedure Check_Test_Hook_Disarms is separate;

   --  A stage made with Files.Jobs.Context.Create_Stage is removed with
   --  Discard_Stage, which drops its record with it: a test that deletes one
   --  with Delete_Permanently or Delete_Tree leaves a record behind for the
   --  sweep, and the tests after it, to trip over.
   procedure Check_Test_Stage_Removal is separate;

   --  A link a test makes that the host may refuse (a symbolic link without
   --  the privilege on Windows, any link on a FAT volume) says so when it is
   --  refused: Files_Suite.Support.Disk.Link_Not_Made fails on Linux and
   --  skips elsewhere. An Assert of the link fails where the host merely
   --  takes no links; a result dropped or tested without a report checks
   --  nothing there and says nothing about it.
   procedure Check_Test_Link_Routing is separate;

   --  Every share/locales catalog takes the {arguments} the default
   --  locale's message takes, checked by messages' catalog_check: a
   --  placeholder dropped in translation renders without its value.
   procedure Check_Locale_Catalog_Arguments is separate;

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

   --  Ada.Characters.Handling.To_Lower maps Latin-1, so on UTF-8 text it
   --  rewrites lead bytes (0xC0 .. 0xDE): "Ä" (C3 84) becomes E3 84. src/
   --  lower-cases with Files.Text_Case.To_Lower_Ascii (tokens, keys, MIME types,
   --  extensions) or Files.Text_Case.Fold_Case (what a person reads), never that.
   procedure Check_Ascii_Lowercasing is separate;

   --  Recovery and job units decide what to remove or forget by whether an
   --  entry is gone. Hostkit's Kind_Of and Is_Link answer "not there" for a
   --  lookup the host refused too, so negating Exists or Entry_Exists there
   --  takes EACCES or EIO for absence and drops the only pointer to a staged
   --  or preserved entry. They ask Entry_Is_Absent (gone for sure) instead,
   --  and a kind test (Directory_Exists, File_Exists) for validity.
   procedure Check_Refused_Is_Not_Absent is separate;

   type Check_Procedure is access procedure;

   --  A check and the name a run reports it by.
   type Named_Check is record
      Name  : Unbounded_String;
      Check : Check_Procedure;
   end record;

   function Named (Name : String; Check : Check_Procedure) return Named_Check is
     (Name => To_Unbounded_String (Name), Check => Check);

   --  Every check of the tree, in the order they run. Each runs even when one
   --  before it found a problem; the build waits for all of them.
   Checks : constant array (Positive range <>) of Named_Check :=
     [Named ("Check_Project_Text_Files", Check_Project_Text_Files'Access),
      Named ("Check_GNATdoc_Comments", Check_GNATdoc_Comments'Access),
      Named ("Check_AUnit_Test_Registration", Check_AUnit_Test_Registration'Access),
      Named ("Check_Test_Subsystem_Coverage", Check_Test_Subsystem_Coverage'Access),
      Named ("Check_Ada_Only_Tooling", Check_Ada_Only_Tooling'Access),
      Named ("Check_Localization_Usage", Check_Localization_Usage'Access),
      Named ("Check_Clock_Arithmetic", Check_Clock_Arithmetic'Access),
      Named ("Check_Environment_Access", Check_Environment_Access'Access),
      Named ("Check_Path_Text_Calls", Check_Path_Text_Calls'Access),
      Named ("Check_Durability_Calls", Check_Durability_Calls'Access),
      Named ("Check_Raw_File_System_Calls", Check_Raw_File_System_Calls'Access),
      Named ("Check_Visible_Cache_Invalidation", Check_Visible_Cache_Invalidation'Access),
      Named ("Check_Swallowing_Handlers", Check_Swallowing_Handlers'Access),
      Named ("Check_Shared_Package_State", Check_Shared_Package_State'Access),
      Named ("Check_Host_Questions", Check_Host_Questions'Access),
      Named ("Check_Filetype_Detection_Order", Check_Filetype_Detection_Order'Access),
      Named ("Check_Event_Translation_Contract", Check_Event_Translation_Contract'Access),
      Named ("Check_Test_Hooks", Check_Test_Hooks'Access),
      Named ("Check_Test_Hook_Disarms", Check_Test_Hook_Disarms'Access),
      Named ("Check_Test_Stage_Removal", Check_Test_Stage_Removal'Access),
      Named ("Check_Test_Link_Routing", Check_Test_Link_Routing'Access),
      Named ("Check_Command_And_Overlay_Layers", Check_Command_And_Overlay_Layers'Access),
      Named ("Check_Job_Layer", Check_Job_Layer'Access),
      Named ("Check_File_System_Closure", Check_File_System_Closure'Access),
      Named ("Check_Rendering_Model_Reads", Check_Rendering_Model_Reads'Access),
      Named ("Check_Crate_Structure", Check_Crate_Structure'Access),
      Named ("Check_Application_CLI_Surface", Check_Application_CLI_Surface'Access),
      Named ("Check_Rendering_Architecture", Check_Rendering_Architecture'Access),
      Named ("Check_Icon_Assets", Check_Icon_Assets'Access),
      Named ("Check_Platform_Bodies", Check_Platform_Bodies'Access),
      Named ("Check_Packaging_Metadata", Check_Packaging_Metadata'Access),
      Named ("Check_CLDR_Importer", Check_CLDR_Importer'Access),
      Named ("Check_Locale_Catalog_Arguments", Check_Locale_Catalog_Arguments'Access),
      Named ("Check_Ascii_Lowercasing", Check_Ascii_Lowercasing'Access),
      Named ("Check_Refused_Is_Not_Absent", Check_Refused_Is_Not_Absent'Access)];

begin
   if not Project_Tools.Files.File_Exists (Root & "/files.gpr") then
      Put_Line (Standard_Error, "check_all must be run from the files project root or tools directory");
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      return;
   end if;

   Require_Command ("alr");
   Run_Check ("Require_Alire_GNAT_15", Require_Alire_GNAT_15'Access);

   Project_Tools.Files.Write_Text_File (Combined_Suite, Suite_Sources);
   Project_Tools.Files.Write_Text_File (Combined_Check_All, Check_All_Sources);

   --  "--only <Check_Name>" runs that one check of the tree and stops: no
   --  build and no suite, for working on a check or on what it reports.
   if Ada.Command_Line.Argument_Count = 2 and then Ada.Command_Line.Argument (1) = "--only" then
      declare
         Found : Boolean := False;
      begin
         for Item of Checks loop
            if To_String (Item.Name) = Ada.Command_Line.Argument (2) then
               Found := True;
               Run_Check (To_String (Item.Name), Item.Check);
            end if;
         end loop;
         Cleanup_Temps;
         if not Found then
            Put_Line (Standard_Error, "check_all: no check named " & Ada.Command_Line.Argument (2));
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
         elsif not Problems_Found ("the end of " & Ada.Command_Line.Argument (2)) then
            Put_Line (Ada.Command_Line.Argument (2) & " passed");
            Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Success);
         end if;
         return;
      end;
   end if;

   for Item of Checks loop
      Run_Check (To_String (Item.Name), Item.Check);
   end loop;
   if Problems_Found ("the build") then
      Cleanup_Temps;
      return;
   end if;
   --  Non-interactive (a stale lockfile must not stop on a prompt) and at the
   --  development profile for every crate: a release build of the siblings
   --  (guikit at -O3) runs the compiler out of memory on a small machine.
   Run ("files build", Root, Alr,
        [new String'("-n"), new String'("build"), new String'("--profiles=*=development")]);
   Run_Check ("Check_Executable_CLI_Help", Check_Executable_CLI_Help'Access);
   Run_Check ("Check_Desktop_Runtime_Contract", Check_Desktop_Runtime_Contract'Access);
   if Problems_Found ("the suite") then
      Cleanup_Temps;
      return;
   end if;
   Run ("top-level tests build", Root & "/tests", Alr,
        [new String'("-n"), new String'("build"), new String'("--profiles=*=development")]);
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
      --  The build steps report themselves and raise Program_Error; a
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
