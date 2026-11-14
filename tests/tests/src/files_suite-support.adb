with Files.File_System;
with Files.Model.Testing;
with Files.Refresh_Jobs;
with Ada.Text_IO;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Exceptions;
with Interfaces;
with Ada.Strings;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;

with AUnit;
with AUnit.Assertions;

with Project_Tools.Files;

with GNAT.OS_Lib;
with GNAT.CRC32;

with Hostkit.Fs;
with Hostkit.Host;
with Hostkit.Metadata;
with Hostkit.Process;
with Files.Model.Pasting;
with Files.Model.Selection;

package body Files_Suite.Support is

   function Polling
     (Limit    : Duration := Poll_Limit;
      Interval : Duration := 0.001)
      return Poll_Iterators.Forward_Iterator'Class
   is
      use type Ada.Real_Time.Time;
   begin
      return Poll_Iterator'
        (Deadline => Ada.Real_Time.Clock + Ada.Real_Time.To_Time_Span (Limit),
         Interval => Interval);
   end Polling;

   overriding function Next (Object : Poll_Iterator; Position : Poll_Cursor) return Poll_Cursor is
      use type Ada.Real_Time.Time;
   begin
      delay Object.Interval;
      return (if Ada.Real_Time.Clock >= Object.Deadline then 0 else Position + 1);
   end Next;

   function Now return Instant is (Ada.Real_Time.Clock);

   function Elapsed (Since : Instant) return Span is
      use type Ada.Real_Time.Time;
   begin
      return Ada.Real_Time.Clock - Since;
   end Elapsed;

   function Seconds (Taken : Span) return Duration is (Ada.Real_Time.To_Duration (Taken));

   --  Far beyond any runner worth waiting for; it keeps Scaled clear of
   --  Duration'Last.
   Maximum_Time_Scale : constant Duration := 100.0;

   function Time_Scale return Duration is
      Text : constant String := Ada.Environment_Variables.Value ("FILES_TEST_TIME_SCALE", "");
      Value : Duration;
   begin
      if Text = "" then
         return 1.0;
      end if;
      Value := Duration'Value (Text);
      return (if Value < 1.0 then 1.0 else Duration'Min (Value, Maximum_Time_Scale));
   exception
      when Constraint_Error =>
         return 1.0;
   end Time_Scale;

   function Scaled (Bound : Duration) return Span is
     (Ada.Real_Time.To_Time_Span (Duration (Bound * Time_Scale)));

   procedure Assert_Within (Taken : Span; Limit : Span; Message : String) is
      use type Ada.Real_Time.Time_Span;
   begin
      AUnit.Assertions.Assert
        (Taken < Limit,
         Message & " (took" & Duration'Image (Seconds (Taken)) & " s, limit"
         & Duration'Image (Seconds (Limit)) & " s)");
   end Assert_Within;

   procedure Assert_Within (Since : Instant; Limit : Span; Message : String) is
      Taken : constant Span := Elapsed (Since);
   begin
      Assert_Within (Taken, Limit, Message);
   end Assert_Within;

   use Ada.Strings.Unbounded;
   use AUnit.Assertions;
   --  Bit masking in Chunk's CRC bytes, and the adapter check in
   --  Honours_Executable_Bit.
   use type Interfaces.Unsigned_32;

   function Click_Action
     (Snapshot    : Files.Rendering.View_Snapshot;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Activate    : Boolean := False;
      Modifiers   : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Line_Height : Positive := 20)
      return Files.Events.Input_Action
   is (Files.Events.Translate_Click
         (Snapshot,
          Files.Rendering.Build_Frame_Commands (Snapshot, Width, Height, Line_Height),
          X, Y, Width, Height, Activate, Modifiers, Line_Height));

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

   procedure Run_Command
     (Id    : Files.Commands.Command_Id;
      Model : in out Files.Model.Window_Model)
   is
      Result : constant Files.Controller.Controller_Result :=
        Files.Controller.Execute_Non_Settings_Command (Id, Model, Files.Settings.Default_Settings);
      pragma Unreferenced (Result);
   begin
      null;
   end Run_Command;

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

   procedure Write_Long_Path_File (Path : String; Content : String) is
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
   end Write_Long_Path_File;

   function Long_Path_File_Is (Path : String; Bytes : String) return Boolean is
      use type Ada.Streams.Stream_Element_Offset;
      use type Hostkit.Fs.Entry_Kind;
      File   : Ada.Streams.Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 4_096);
      Last   : Ada.Streams.Stream_Element_Offset;
      Whole  : Unbounded_String;
   begin
      if Hostkit.Fs.Kind_Of (Path) /= Hostkit.Fs.Ordinary_File_Entry then
         return False;
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
      return To_String (Whole) = Bytes;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;
         raise;
   end Long_Path_File_Is;

   procedure Write_File (Path : String; Content : String := "x") is
   begin
      Project_Tools.Files.Write_Text_File (Path, Content);
   end Write_File;

   function File_Is (Path : String; Bytes : String) return Boolean is
     (Ada.Directories.Exists (Path) and then Project_Tools.Files.Read_Raw_File (Path) = Bytes);

   function File_Has_Bytes (Path : String; Bytes : String) return Boolean is
      use type Ada.Streams.Stream_Element_Offset;

      File   : Ada.Streams.Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 64 * 1024);
      Last   : Ada.Streams.Stream_Element_Offset;
      Whole  : Unbounded_String;
   begin
      if Bytes = "" or else not Ada.Directories.Exists (Path) then
         return False;
      end if;

      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);

      while not Ada.Streams.Stream_IO.End_Of_File (File) loop
         Ada.Streams.Stream_IO.Read (File, Buffer, Last);
         exit when Last < Buffer'First;

         declare
            Chunk : String (1 .. Natural (Last - Buffer'First + 1));
         begin
            for Index in Chunk'Range loop
               Chunk (Index) :=
                 Character'Val
                   (Buffer (Ada.Streams.Stream_Element_Offset (Index) + Buffer'First - 1));
            end loop;

            Append (Whole, Chunk);
         end;
      end loop;

      Ada.Streams.Stream_IO.Close (File);
      return Ada.Strings.Fixed.Index (To_String (Whole), Bytes) > 0;
   exception
      when others =>
         if Ada.Streams.Stream_IO.Is_Open (File) then
            Ada.Streams.Stream_IO.Close (File);
         end if;

         return False;
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

      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
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
      Ada.Streams.Stream_IO.Create (File, Ada.Streams.Stream_IO.Out_File, Path);
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

   function Byte (Value : Natural) return Character is
   begin
      return Character'Val (Value);
   end Byte;

   function Minimal_Png_Header
     (Width  : Natural;
      Height : Natural)
      return String is
   begin
      return
        Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#) & Byte (16#1A#) & Byte (16#0A#) &
        Byte (0) & Byte (0) & Byte (0) & Byte (13) & "IHDR" &
        Byte ((Width / 16#1000000#) mod 256) &
        Byte ((Width / 16#10000#) mod 256) &
        Byte ((Width / 16#100#) mod 256) &
        Byte (Width mod 256) &
        Byte ((Height / 16#1000000#) mod 256) &
        Byte ((Height / 16#10000#) mod 256) &
        Byte ((Height / 16#100#) mod 256) &
        Byte (Height mod 256) &
        Byte (8) & Byte (2) & Byte (0) & Byte (0) & Byte (0);
   end Minimal_Png_Header;

   function Stored_Zlib_Stream
     (Payload : String)
      return String
   is
      S1 : Natural := 1;
      S2 : Natural := 0;
      Len : constant Natural := Payload'Length;
      NLen : constant Natural := 65_535 - Len;
   begin
      for Value of Payload loop
         S1 := (S1 + Character'Pos (Value)) mod 65_521;
         S2 := (S2 + S1) mod 65_521;
      end loop;

      return
        Byte (16#78#) & Byte (16#01#) &
        Byte (16#01#) &
        Byte (Len mod 256) & Byte ((Len / 256) mod 256) &
        Byte (NLen mod 256) & Byte ((NLen / 256) mod 256) &
        Payload &
        Byte ((S2 / 256) mod 256) & Byte (S2 mod 256) &
        Byte ((S1 / 256) mod 256) & Byte (S1 mod 256);
   end Stored_Zlib_Stream;

   function Chunk
     (Kind : String;
      Data : String)
      return String
   is
      Context : GNAT.CRC32.CRC32;
      Value   : Interfaces.Unsigned_32;
   begin
      GNAT.CRC32.Initialize (Context);
      GNAT.CRC32.Update (Context, Kind & Data);
      Value := GNAT.CRC32.Get_Value (Context);
      return
        Byte ((Data'Length / 16#1000000#) mod 256) &
        Byte ((Data'Length / 16#10000#) mod 256) &
        Byte ((Data'Length / 16#100#) mod 256) &
        Byte (Data'Length mod 256) &
        Kind & Data &
        Byte (Natural (Interfaces.Shift_Right (Value, 24) and 16#FF#)) &
        Byte (Natural (Interfaces.Shift_Right (Value, 16) and 16#FF#)) &
        Byte (Natural (Interfaces.Shift_Right (Value, 8) and 16#FF#)) &
        Byte (Natural (Value and 16#FF#));
   end Chunk;

   function Minimal_Png_RGB
     (Width   : Natural;
      Height  : Natural;
      Payload : String)
      return String is
   begin
      return
        Byte (16#89#) & "PNG" & Byte (16#0D#) & Byte (16#0A#) & Byte (16#1A#) & Byte (16#0A#) &
        Chunk
          ("IHDR",
           Byte ((Width / 16#1000000#) mod 256) &
           Byte ((Width / 16#10000#) mod 256) &
           Byte ((Width / 16#100#) mod 256) &
           Byte (Width mod 256) &
           Byte ((Height / 16#1000000#) mod 256) &
           Byte ((Height / 16#10000#) mod 256) &
           Byte ((Height / 16#100#) mod 256) &
           Byte (Height mod 256) &
           Byte (8) & Byte (2) & Byte (0) & Byte (0) & Byte (0)) &
        Chunk ("IDAT", Stored_Zlib_Stream (Payload)) &
        Chunk ("IEND", "");
   end Minimal_Png_RGB;

   function Red_Jpeg_8x8 return String is
      Hex : constant String :=
           "FFD8FFE000104A46494600010100000100010000FFDB0043000302020302020303030304030304050805050404050A07" &
           "0706080C0A0C0C0B0A0B0B0D0E12100D0E110E0B0B1016101113141515150C0F171816141812141514FFDB0043010304" &
           "0405040509050509140D0B0D141414141414141414141414141414141414141414141414141414141414141414141414" &
           "1414141414141414141414141414FFC00011080008000803011100021101031101FFC400140001000000000000000000" &
           "00000000000008FFC40014100100000000000000000000000000000000FFC40015010101000000000000000000000000" &
           "00000709FFC40014110100000000000000000000000000000000FFDA000C03010002110311003F003A03154DFFD9";
      Bytes : String (1 .. Hex'Length / 2);
   begin
      for Index in Bytes'Range loop
         Bytes (Index) :=
           Character'Val (Natural'Value ("16#" & Hex (Hex'First + 2 * (Index - 1) .. Hex'First + 2 * Index - 1) & "#"));
      end loop;
      return Bytes;
   end Red_Jpeg_8x8;

   function Minimal_Jpeg_With_Fill
     (Width  : Natural;
      Height : Natural)
      return String is
   begin
      return
        Byte (16#FF#) & Byte (16#D8#) &
        Byte (16#FF#) & Byte (16#FF#) & Byte (16#C0#) &
        Byte (0) & Byte (8) & Byte (8) &
        Byte ((Height / 16#100#) mod 256) &
        Byte (Height mod 256) &
        Byte ((Width / 16#100#) mod 256) &
        Byte (Width mod 256);
   end Minimal_Jpeg_With_Fill;

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

   function Sample_Items return Files.Items.Item_Vectors.Vector is
      Items : Files.Items.Item_Vectors.Vector;
   begin
      Items.Append (Files.File_System.Make_Item (Root, "Alpha.txt", Files.Types.Regular_File_Item, "text/plain"));
      Items.Append (Files.File_System.Make_Item (Root, "Beta.txt", Files.Types.Regular_File_Item, "text/plain"));
      Items.Append (Files.File_System.Make_Item (Root, "Gamma.md", Files.Types.Regular_File_Item, "text/markdown"));
      return Items;
   end Sample_Items;

   function Sample_Model return Files.Model.Window_Model is
      Model : Files.Model.Window_Model;
   begin
      Files.Model.Initialize
        (Model,
         Directory_Path    => Root,
         Items             => Sample_Items,
         Home_Path         => "/home/test",
         Default_View_Mode => Files.Types.Small_Icons);
      return Model;
   end Sample_Model;

   procedure Select_Name
     (Model : in out Files.Model.Window_Model;
      Name  : String)
   is
      Selected : constant Boolean := Files.Model.Selection.Select_By_Name (Model, Name);
      pragma Unreferenced (Selected);
   begin
      null;
   end Select_Name;

   procedure Save (Guard : in out Environment_Guard; Name : String) is
   begin
      if Guard.Count = Guard.Saved'Last then
         raise Program_Error with "Environment_Guard holds at most" & Guard.Saved'Last'Image & " variables";
      end if;
      Guard.Count := Guard.Count + 1;
      Guard.Saved (Guard.Count) :=
        (Name  => Ada.Strings.Unbounded.To_Unbounded_String (Name),
         Value => Ada.Strings.Unbounded.To_Unbounded_String (Ada.Environment_Variables.Value (Name, "")),
         Was   => Ada.Environment_Variables.Exists (Name));
   end Save;

   overriding procedure Finalize (Guard : in out Environment_Guard) is
   begin
      for Index in reverse 1 .. Guard.Count loop
         declare
            Item : Saved_Variable renames Guard.Saved (Index);
            Name : constant String := Ada.Strings.Unbounded.To_String (Item.Name);
         begin
            if Item.Was then
               Ada.Environment_Variables.Set (Name, Ada.Strings.Unbounded.To_String (Item.Value));
            else
               Ada.Environment_Variables.Clear (Name);
            end if;
         end;
      end loop;
      Guard.Count := 0;
   end Finalize;

   overriding procedure Finalize (Guard : in out Shortcut_Guard) is
      pragma Unreferenced (Guard);
   begin
      Files.Commands.Reset_Shortcut_Overrides;
   exception
      when Error : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Shortcut_Guard could not clear the shortcut overrides: " & Ada.Exceptions.Exception_Message (Error));
   end Finalize;

   procedure Release (Guard : in out Paste_Guard) is
   begin
      Files.Model.Pasting.Clear_Execution (Guard.Model.all);
      Files.Refresh_Jobs.Cancel (Guard.Model.all);
   end Release;

   overriding procedure Finalize (Guard : in out Paste_Guard) is
   begin
      Release (Guard);
   exception
      when Error : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Paste_Guard could not end the paste execution: " & Ada.Exceptions.Exception_Message (Error));
   end Finalize;

   procedure Remove_Transport_Fixture (Path : Files.Types.UString) is
   begin
      if Length (Path) > 0 and then Ada.Directories.Exists (To_String (Path)) then
         Project_Tools.Files.Delete_Tree (To_String (Path));
      end if;
   end Remove_Transport_Fixture;

   procedure Track (Guard : in out Process_Jobs_Guard; Path : Files.Types.UString) is
   begin
      Guard.Fixtures.Append (Path);
   end Track;

   procedure Release (Guard : in out Process_Jobs_Guard) is
   begin
      Files.Process_Jobs.Reset (Guard.Session.all);
      for Path of Guard.Fixtures loop
         Remove_Transport_Fixture (Path);
      end loop;
   end Release;

   overriding procedure Finalize (Guard : in out Process_Jobs_Guard) is
   begin
      Release (Guard);
   exception
      when Error : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Process_Jobs_Guard could not restore the job fixtures: " & Ada.Exceptions.Exception_Message (Error));
   end Finalize;

   function Finish_Paste
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Files.Operations.Operation_Result
   is
      Result : Files.Operations.Operation_Result;
   begin
      for Attempt in Polling (Limit => Seconds (Scaled (Poll_Limit))) loop
         Result := Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
         exit when not Files.Model.Pasting.Execution_Is_Active (Model);
      end loop;
      AUnit.Assertions.Assert
        (not Files.Model.Pasting.Execution_Is_Active (Model), "the paste execution finishes");
      return Result;
   end Finish_Paste;

   overriding procedure Initialize (Guard : in out Directory_Guard) is
   begin
      Guard.Saved := To_Unbounded_String (Ada.Directories.Current_Directory);
   end Initialize;

   overriding procedure Finalize (Guard : in out Directory_Guard) is
   begin
      if Length (Guard.Saved) > 0 then
         Ada.Directories.Set_Directory (To_String (Guard.Saved));
      end if;
   exception
      when Error : others =>
         Ada.Text_IO.Put_Line
           (Ada.Text_IO.Standard_Error,
            "Directory_Guard could not return to " & To_String (Guard.Saved) & ": "
            & Ada.Exceptions.Exception_Message (Error));
   end Finalize;

   function Saved_Directory (Guard : Directory_Guard) return String is (To_String (Guard.Saved));

   procedure Drain_Folder_Sizes (Model : in out Files.Model.Window_Model) is
   begin
      for Attempt in Polling (Limit => Seconds (Scaled (Poll_Limit))) loop
         Files.Operations.Poll_Folder_Sizes (Model);
         exit when not Files.Model.Testing.Folder_Scan_Is_Active (Model);
      end loop;
      Assert (not Files.Model.Testing.Folder_Scan_Is_Active (Model), "the background folder-size walks finish");
   end Drain_Folder_Sizes;

   function Process_State (Process_Id : Integer) return Character is
      Path : constant String :=
        "/proc/" & Ada.Strings.Fixed.Trim (Integer'Image (Process_Id), Ada.Strings.Both) & "/stat";
      File : Ada.Text_IO.File_Type;
   begin
      if not Ada.Directories.Exists (Path) then
         return ' ';
      end if;
      --  Text_IO, not a sized read: /proc files report a size of 0.
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      if Ada.Text_IO.End_Of_File (File) then
         Ada.Text_IO.Close (File);
         return ' ';
      end if;
      declare
         Line : constant String := Ada.Text_IO.Get_Line (File);
         --  "pid (comm) state ...": comm may itself hold spaces and
         --  parentheses, so the state follows the last ')'.
         Close_Paren : constant Natural := Ada.Strings.Fixed.Index (Line, ")", Ada.Strings.Backward);
      begin
         Ada.Text_IO.Close (File);
         return (if Close_Paren > 0 and then Close_Paren + 2 <= Line'Last then Line (Close_Paren + 2) else ' ');
      end;
   exception
      when others =>
         if Ada.Text_IO.Is_Open (File) then
            Ada.Text_IO.Close (File);
         end if;
         return ' ';
   end Process_State;

   procedure Assert_Equal (Actual, Expected : Integer; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Actual = Expected, Message & " (expected" & Expected'Image & ", got" & Actual'Image & ")");
   end Assert_Equal;

   procedure Assert_Equal (Actual, Expected : Long_Long_Integer; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Actual = Expected, Message & " (expected" & Expected'Image & ", got" & Actual'Image & ")");
   end Assert_Equal;

   procedure Assert_Equal (Actual, Expected : String; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Actual = Expected, Message & " (expected """ & Expected & """, got """ & Actual & """)");
   end Assert_Equal;

   procedure Assert_Equal (Actual, Expected : Boolean; Message : String) is
   begin
      AUnit.Assertions.Assert
        (Actual = Expected, Message & " (expected " & Expected'Image & ", got " & Actual'Image & ")");
   end Assert_Equal;

   procedure Assert_Inside
     (X, Y, Width, Height                         : Integer;
      Outer_X, Outer_Y, Outer_Width, Outer_Height : Integer;
      Message                                     : String) is
   begin
      AUnit.Assertions.Assert
        (X >= Outer_X, Message & " (left edge:" & X'Image & " <" & Outer_X'Image & ")");
      AUnit.Assertions.Assert
        (Y >= Outer_Y, Message & " (top edge:" & Y'Image & " <" & Outer_Y'Image & ")");
      AUnit.Assertions.Assert
        (X + Width <= Outer_X + Outer_Width,
         Message & " (right edge:" & Integer'Image (X + Width) & " >" & Integer'Image (Outer_X + Outer_Width) & ")");
      AUnit.Assertions.Assert
        (Y + Height <= Outer_Y + Outer_Height,
         Message & " (bottom edge:" & Integer'Image (Y + Height) & " >"
         & Integer'Image (Outer_Y + Outer_Height) & ")");
   end Assert_Inside;

   procedure Assert_Fits
     (X, Y, Width, Height       : Integer;
      Frame_Width, Frame_Height : Integer;
      Message                   : String) is
   begin
      AUnit.Assertions.Assert (Width > 0, Message & " (width:" & Width'Image & ")");
      AUnit.Assertions.Assert (Height > 0, Message & " (height:" & Height'Image & ")");
      AUnit.Assertions.Assert
        (X + Width <= Frame_Width,
         Message & " (right edge:" & Integer'Image (X + Width) & " >" & Frame_Width'Image & ")");
      AUnit.Assertions.Assert
        (Y + Height <= Frame_Height,
         Message & " (bottom edge:" & Integer'Image (Y + Height) & " >" & Frame_Height'Image & ")");
   end Assert_Fits;

   procedure Assert_Between (Value, Low, High : Float; Message : String) is
   begin
      AUnit.Assertions.Assert (Value >= Low, Message & " (below:" & Value'Image & " <" & Low'Image & ")");
      AUnit.Assertions.Assert (Value <= High, Message & " (above:" & Value'Image & " >" & High'Image & ")");
   end Assert_Between;

   Skipped : Natural := 0;

   Skipped_Names : Files.Types.String_Vectors.Vector;

   procedure Skip (Test : String; Reason : String) is
   begin
      Skipped := Skipped + 1;
      if not Skipped_Names.Contains (To_Unbounded_String (Test & ':' & ' ' & Reason)) then
         Skipped_Names.Append (To_Unbounded_String (Test & ':' & ' ' & Reason));
      end if;
      Ada.Text_IO.Put_Line ("SKIP" & ':' & ' ' & Test & ':' & ' ' & Reason);
   end Skip;

   function Skip_Count return Natural is (Skipped);

   function Has_Skipped (Skip : String) return Boolean is (Skipped_Names.Contains (To_Unbounded_String (Skip)));

   function Skips return Files.Types.String_Vectors.Vector is (Skipped_Names);
   function Describe (Extra : Files.Extra_Info.Info) return String is
      use Files.Extra_Info;
      V : constant String := Ada.Strings.Unbounded.To_String (Extra.Value);
      S : constant String := Ada.Strings.Unbounded.To_String (Extra.Subject);
      N : constant String := Files.Types.Natural_Text (Extra.Count) & (if Extra.Capped then "+" else "");
   begin
      case Extra.Of_Kind is
         when None              => return "";
         when Directory_Count   => return "directory.count|" & N;
         when Executable_Format => return "executable.format|" & V;
         when Symlink_Target    => return "symlink.target|" & V;
         when Text_Lines        => return S & ".lines_encoding|" & N & "|" & V;
         when Image_Dimensions  => return "image.dimensions|" & V;
         when Document_Kind     => return "document.kind|" & V;
         when Pdf_Pages         => return "document.pdf.pages|" & N;
         when Archive_Format    => return "archive.format|" & V;
         when Archive_Entries   => return "archive." & S & ".entries|" & N;
         when Office_Entries    => return "office." & S & ".entries|" & N;
         when Media_Kind        => return "media.kind|" & V;
      end case;
   end Describe;

end Files_Suite.Support;
