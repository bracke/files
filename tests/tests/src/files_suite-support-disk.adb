with Files.File_System;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Ada.Strings;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;

with Project_Tools.Files;

with GNAT.OS_Lib;

with Hostkit.Fs;
with Hostkit.Host;
with Hostkit.Metadata;
with Hostkit.Process;

with Files_Suite.Support.Timing;

package body Files_Suite.Support.Disk is
   use Files_Suite.Support.Timing;

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;

   function Create_Symlink
     (Target   : String;
      Linkpath : String)
      return Boolean is
   begin
      --  Through the platform layer: symlink(2) is POSIX-only, and naming it here
      --  made the test executable impossible to link on Windows. A platform that
      --  will not make a link returns False, and every caller already guards on
      --  that -- Windows needs Developer Mode or a privilege to create one.
      return Hostkit.Fs.Create_Link (Target, Linkpath);
   end Create_Symlink;

   procedure Link_Not_Made (Test : String; Kind : Link_Kind := Symbolic_Link) is
      use type Hostkit.Host.Kind;
      Name : constant String := (if Kind = Hard_Link then "hard link" else "symbolic link");
   begin
      if Hostkit.Host.Current = Hostkit.Host.Linux then
         Assert (False, Test & ": could not make a " & Name & " in the test root, which Linux always allows");
      else
         Skip (Test, "this host would not make the " & Name & " the test needs");
      end if;
   end Link_Not_Made;

   --  On Windows, put back the inherited access of Path and everything
   --  under it (icacls /reset), whatever DACLs a test left there.
   procedure Reset_Access (Path : String) is
      Program   : constant String := Hostkit.Process.Locate ("icacls");
      Arguments : Hostkit.String_Vectors.Vector;
   begin
      if Hostkit.Host."=" (Hostkit.Host.Current, Hostkit.Host.Windows) and then Program /= "" then
         Arguments.Append (Ada.Strings.Unbounded.To_Unbounded_String (Path));
         Arguments.Append (Ada.Strings.Unbounded.To_Unbounded_String ("/reset"));
         Arguments.Append (Ada.Strings.Unbounded.To_Unbounded_String ("/T"));
         Arguments.Append (Ada.Strings.Unbounded.To_Unbounded_String ("/C"));
         Arguments.Append (Ada.Strings.Unbounded.To_Unbounded_String ("/Q"));
         declare
            Result : constant Hostkit.Process.Process_Outcome :=
              Hostkit.Process.Run_Captured (Program, Arguments, Timeout_Ms => 60_000);
            pragma Unreferenced (Result);
         begin
            null;
         end;
      end if;
   end Reset_Access;

   procedure Reset_Root is
      Removed : Files.File_System.Mutation_Result;
   begin
      if Ada.Directories.Exists (Root) or else Hostkit.Fs.Is_Link (Root) then
         --  A just-reaped Windows helper can retain a directory handle for a
         --  short interval after its result has been collected.  Retry the
         --  idempotent cleanup so that this normal release latency does not
         --  poison every later test that shares Root.
         for Attempt in Polling (Interval => 0.01) loop
            Removed := Files.File_System.Delete_Permanently (Root);
            exit when Removed.Success
              or else not (Ada.Directories.Exists (Root) or else Hostkit.Fs.Is_Link (Root));
         end loop;
         if not Removed.Success and then (Ada.Directories.Exists (Root) or else Hostkit.Fs.Is_Link (Root)) then
            declare
               Message : constant String :=
                 "test fixture cleanup removes links without following targets; cwd="
                 & Ada.Directories.Current_Directory & "; root=" & Root
                 & "; error=" & To_String (Removed.Error_Key) & Access_Report (Root, Tree => True);
            begin
               --  Fail this test, but leave the next one a clean root: what
               --  an earlier test's DACLs refuse, their reset to the inherited
               --  access lets go.
               Reset_Access (Root);
               Removed := Files.File_System.Delete_Permanently (Root);
               Assert
                 (False,
                  Message & (if Removed.Success then "; gone after an access reset" else "; still there after one"));
            end;
         end if;
      end if;
      Ada.Directories.Create_Path (Root);
   end Reset_Root;

   function Access_Report (Path : String; Tree : Boolean := False) return String is
      Program   : constant String := Hostkit.Process.Locate ("icacls");
      Report    : constant String := Path & ".access-report";
      Arguments : Hostkit.String_Vectors.Vector;
      Result    : Hostkit.Process.Process_Outcome;
   begin
      if Hostkit.Host."/=" (Hostkit.Host.Current, Hostkit.Host.Windows) or else Program = "" then
         return "";
      end if;
      Arguments.Append (Ada.Strings.Unbounded.To_Unbounded_String (Path));
      if Tree then
         Arguments.Append (Ada.Strings.Unbounded.To_Unbounded_String ("/T"));
         Arguments.Append (Ada.Strings.Unbounded.To_Unbounded_String ("/C"));
      end if;
      Result := Hostkit.Process.Run_Captured (Program, Arguments, Stdout_Path => Report, Timeout_Ms => 10_000);
      if not Result.Started or else not Ada.Directories.Exists (Report) then
         return " (icacls did not run)";
      end if;
      declare
         Text : constant String := Project_Tools.Files.Read_Raw_File (Report);
      begin
         Ada.Directories.Delete_File (Report);
         return " -- " & Text;
      end;
   exception
      when Failure : others =>
         return " (icacls failed: " & Ada.Exceptions.Exception_Message (Failure) & ")";
   end Access_Report;

   procedure Forbid_Deletion (Path : String) is
      use type Hostkit.Fs.Entry_Kind;
   begin
      if not Hostkit.Metadata.Mode_Bits_Are_Native then
         Assert
           (Hostkit.Metadata.Set_Exact_Permissions
              (Path, (if Hostkit.Fs.Kind_Of (Path) = Hostkit.Fs.Directory_Entry then 8#555# else 8#444#)),
            "the fixture's own access is made read-only so it cannot be deleted: " & Path);
      end if;
   end Forbid_Deletion;

   procedure Allow_Deletion (Path : String) is
      use type Hostkit.Fs.Entry_Kind;
      Ignored : Boolean;
   begin
      if not Hostkit.Metadata.Mode_Bits_Are_Native and then Hostkit.Fs.Kind_Of (Path) /= Hostkit.Fs.Missing_Entry
      then
         Ignored := Hostkit.Metadata.Set_Exact_Permissions
           (Path, (if Hostkit.Fs.Kind_Of (Path) = Hostkit.Fs.Directory_Entry then 8#755# else 8#644#));
      end if;
   end Allow_Deletion;

   procedure Write_File (Path : String; Content : String := "x") is
   begin
      Project_Tools.Files.Write_Text_File (Path, Content);
   end Write_File;

   --  The whole of Path, one Character per byte, through
   --  Hostkit.Fs.Open_Stream (past Windows' path limit). Nothing there, or a
   --  folder, reads as Absent; any other failure to read raises, so an
   --  assertion over the bytes fails on it rather than passing as "not held".
   function Read_Bytes (Path : String; Absent : out Boolean) return String is
      use type Ada.Streams.Stream_Element_Offset;
      use type Hostkit.Fs.Entry_Kind;
      File   : Ada.Streams.Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 64 * 1024);
      Last   : Ada.Streams.Stream_Element_Offset;
      Whole  : Unbounded_String;
   begin
      Absent := False;
      if Hostkit.Fs.Entry_Is_Absent (Path) or else Hostkit.Fs.Kind_Of (Path) = Hostkit.Fs.Directory_Entry then
         Absent := True;
         return "";
      end if;
      Hostkit.Fs.Open_Stream (File, Ada.Streams.Stream_IO.In_File, Path);
      loop
         Ada.Streams.Stream_IO.Read (File, Buffer, Last);
         for Index in Buffer'First .. Last loop
            Append (Whole, Character'Val (Buffer (Index)));
         end loop;
         exit when Last < Buffer'Last;
      end loop;
      Ada.Streams.Stream_IO.Close (File);
      return To_String (Whole);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Read_Bytes;

   function File_Is (Path : String; Bytes : String) return Boolean is
      Absent : Boolean;
      Whole  : constant String := Read_Bytes (Path, Absent);
   begin
      return not Absent and then Whole = Bytes;
   end File_Is;

   function File_Has_Bytes (Path : String; Bytes : String) return Boolean is
      Absent : Boolean;
      Whole  : constant String := Read_Bytes (Path, Absent);
   begin
      return not Absent and then Bytes /= "" and then Ada.Strings.Fixed.Index (Whole, Bytes) > 0;
   end File_Has_Bytes;

   procedure Write_Binary_File
     (Path    : String;
      Content : String)
   is
      File   : Ada.Streams.Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. Content'Length);
   begin
      for Index in Content'Range loop
         Buffer (Ada.Streams.Stream_Element_Offset (Index - Content'First + 1)) :=
           Ada.Streams.Stream_Element (Character'Pos (Content (Index)));
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
   end Write_Binary_File;

   procedure Write_Filler_File
     (Path         : String;
      Filler       : Character;
      Filler_Count : Natural;
      Trailer      : String := "")
   is
      File      : Ada.Streams.Stream_IO.File_Type;
      Chunk     : constant Ada.Streams.Stream_Element_Array (1 .. 4096) :=
        [others => Ada.Streams.Stream_Element (Character'Pos (Filler))];
      Remaining : Natural := Filler_Count;
      Tail      : Ada.Streams.Stream_Element_Array (1 .. Trailer'Length);
   begin
      Hostkit.Fs.Create_Stream (File, Ada.Streams.Stream_IO.Out_File, Path);
      while Remaining > 0 loop
         declare
            This : constant Natural := Natural'Min (Remaining, Chunk'Length);
         begin
            Ada.Streams.Stream_IO.Write
              (File, Chunk (1 .. Ada.Streams.Stream_Element_Offset (This)));
            Remaining := Remaining - This;
         end;
      end loop;

      for Index in Trailer'Range loop
         Tail (Ada.Streams.Stream_Element_Offset (Index - Trailer'First + 1)) :=
           Ada.Streams.Stream_Element (Character'Pos (Trailer (Index)));
      end loop;
      Ada.Streams.Stream_IO.Write (File, Tail);
      Ada.Streams.Stream_IO.Close (File);
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Write_Filler_File;

   function Join (Parent : String; Name : String) return String is
   begin
      return Hostkit.Fs.Join (Parent, Name);
   end Join;

   function Compute_Root return String is
      function System_Temp return String;

      function System_Temp return String is
         use Ada.Environment_Variables;
      begin
         --  TMPDIR on Unix, TEMP/TMP on Windows.
         if Exists ("TMPDIR") and then Value ("TMPDIR") /= "" then
            return Value ("TMPDIR");
         elsif Exists ("TEMP") and then Value ("TEMP") /= "" then
            return Value ("TEMP");
         elsif Exists ("TMP") and then Value ("TMP") /= "" then
            return Value ("TMP");
         else
            return "/tmp";
         end if;
      end System_Temp;

      --  Resolve_Links is the point of this: the model reports canonical paths,
      --  so the fixtures must be built under one too, or every path comparison
      --  fails on macOS.
      Resolved : constant String :=
        GNAT.OS_Lib.Normalize_Pathname
          (System_Temp, Resolve_Links => True);
   begin
      if Ada.Environment_Variables.Exists ("FILES_TEST_ROOT")
        and then Ada.Environment_Variables.Value ("FILES_TEST_ROOT") /= ""
      then
         return Ada.Environment_Variables.Value ("FILES_TEST_ROOT");
      end if;
      return Hostkit.Fs.Join (Resolved, "files_aunit");

   exception
      when others =>
         return "/tmp/files_aunit";
   end Compute_Root;

   Cached_Root : Unbounded_String := Null_Unbounded_String;

   function Root return String is
   begin
      if Length (Cached_Root) = 0 then
         Cached_Root := To_Unbounded_String (Compute_Root);
      end if;
      return To_String (Cached_Root);
   end Root;

   function Companion_Program (Name : String) return String is
      --  The suite ships its own Noop and Failing programs and launches those:
      --  borrowing an executable from the host does not travel. /bin/true is
      --  absent on macOS, absent again on Windows, and every Windows stand-in
      --  either refused the arguments or -- cmd.exe -- opened an interactive
      --  shell and sat waiting for input until CI gave up. They live beside the
      --  test binary, so find them relative to it rather than to the working
      --  directory.
      Self : constant String := Ada.Command_Line.Command_Name;
   begin
      declare
         Directory : constant String :=
           Ada.Directories.Containing_Directory (Self);
         Suffix    : constant String :=
           (if Self'Length >= 4
              and then Self (Self'Last - 3 .. Self'Last) = ".exe"
            then ".exe" else "");
      begin
         return Ada.Directories.Compose (Directory, Name & Suffix);
      end;

   exception
      when others =>
         return Name;
   end Companion_Program;

   function Honours_Executable_Bit return Boolean is
      use type Hostkit.Host.Kind;
   begin
      return Hostkit.Host.Current /= Hostkit.Host.Windows;
   end Honours_Executable_Bit;

   function No_Op_Executable return String is
   begin
      return Companion_Program ("noop");
   end No_Op_Executable;

   function Failing_Executable return String is
   begin
      return Companion_Program ("failing");
   end Failing_Executable;

   function Marker_Executable return String is
   begin
      return Companion_Program ("marker");
   end Marker_Executable;

   function Filesystem_Root return String is
      Base : constant String := Root;
   begin
      if Base'Length >= 2 and then Base (Base'First + 1) = ':' then
         return Base (Base'First .. Base'First + 1) & '\';
      end if;

      return "/";
   end Filesystem_Root;

   function Path_Exists (Path : String) return Boolean is
   begin
      return Ada.Directories.Exists (Path);
   exception
      when others =>
         return False;
   end Path_Exists;

   Case_Probe_Done   : Boolean := False;
   Case_Probe_Result : Boolean := False;

   function Case_Insensitive_Filesystem return Boolean is
      Probe_Dir : constant String := Ada.Directories.Containing_Directory (Root);
      Lower     : constant String := Join (Probe_Dir, "files_case_probe");
      Upper     : constant String := Join (Probe_Dir, "FILES_CASE_PROBE");
   begin
      if Case_Probe_Done then
         return Case_Probe_Result;
      end if;

      Write_File (Lower);
      Case_Probe_Result := Ada.Directories.Exists (Upper);
      Ada.Directories.Delete_File (Lower);
      Case_Probe_Done := True;
      return Case_Probe_Result;

   exception
      when others =>
         Case_Probe_Done := True;
         Case_Probe_Result := False;
         return False;
   end Case_Insensitive_Filesystem;

   function Numbered_File (Directory : String; N : Positive) return String is
     (Join (Directory, "f" & Files.Types.Natural_Text (N) & ".txt"));

end Files_Suite.Support.Disk;
