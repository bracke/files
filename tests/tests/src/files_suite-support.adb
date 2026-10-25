with Ada.Text_IO;
with Ada.Calendar;
with Ada.Characters.Handling;
with Ada.Command_Line;
with Ada.Directories;
with Ada.Environment_Variables;
with Interfaces;
with Ada.Strings;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with System;

with AUnit;
with AUnit.Assertions;
with AUnit.Test_Cases;

with Project_Tools.Files;

with Glfw;
with Glfw.Input.Mouse;

with GNAT.OS_Lib;
with GNAT.CRC32;
with Textrender.Fonts;

with Files.Accessibility;
with Files.Application;
with Files.Application.Windows;
with Files.Command_Palette;
with Files.Drop_Events;
with Files.File_Types;
with Files.Fonts;
with Files.Localization;
with Files.Platform;
with Guikit.Draw;
with Guikit.Vulkan;
with Files.UTF8;
with Files.UI;
with Hostkit.Fs;

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
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;
   use type Interfaces.Unsigned_32;
   use type Files.Commands.Command_Id;
   use type Files.Commands.Command_Placement;
   use type Files.Controller.Controller_Status;
   use type Files.Events.Input_Action_Kind;
   use type Files.Events.Scroll_Target;
   use type Files.File_System.Native_API_Binding_Status;
   use type Files.File_System.Native_Platform_Adapter;
   use type Files.File_System.Path_Status;
   use type Files.File_System.Drop_Import_Mode;
   use type Files.File_System.Root_Kind;
   use type Files.File_System.Root_Readiness;
   use type Files.File_System.Thumbnail_Status;
   use type Files.File_System.Trash_Backend;
   use type Files.Application.Run_Mode;
   use type Files.Operations.Open_Action_Lifecycle_State;
   use type Files.Operations.Operation_Status;
   use type Guikit.Draw.Accessibility_Role;
   use type Guikit.Draw.Icon_Asset_Color_Role;
   use type Guikit.Draw.Render_Color;
   use type Files.Rendering.Text_Render_Status;
   use type Guikit.Vulkan.Atlas_Texture_Format;
   use type Guikit.Vulkan.Texture_Source;
   use type Guikit.Vulkan.Vulkan_Status;
   use type Interfaces.Unsigned_8;
   use type Textrender.Fonts.Load_Result;
   use type Files.Model.Sort_Field;
   use type Files.Settings.Sort_Field;
   use type Files.Types.Focus_Target;
   use type Files.Types.Item_Kind;
   use type Guikit.Input.Key_Code;
   use type Guikit.Input.Modifier_Set;
   use type Guikit.Input.Navigation_Direction;
   use type Files.Types.View_Mode;
   use type Glfw.Input.Mouse.Coordinate;
   use type System.Address;

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
         Assert
           (Removed.Success
              or else not (Ada.Directories.Exists (Root) or else Hostkit.Fs.Is_Link (Root)),
            "test fixture cleanup removes links without following targets; cwd="
            & Ada.Directories.Current_Directory & "; root=" & Root
            & "; error=" & To_String (Removed.Error_Key));
      end if;
      Ada.Directories.Create_Path (Root);
   end Reset_Root;

   procedure Write_File (Path : String; Content : String := "x") is
   begin
      Project_Tools.Files.Write_Text_File (Path, Content);
   end Write_File;

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
      return Files.File_System.Join_Path (Parent, Name);
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
      return Files.File_System.Join_Path (Resolved, "files_aunit");

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
   begin
      return Files.Platform.Current_API_Profile.Adapter
               /= Files.File_System.Native_Adapter_Windows;
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

   function Sample_Items return Files.File_System.Item_Vectors.Vector is
      Items : Files.File_System.Item_Vectors.Vector;
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
      Selected : constant Boolean := Files.Model.Select_By_Name (Model, Name);
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

   Skipped : Natural := 0;

   procedure Skip (Test : String; Reason : String) is
   begin
      Skipped := Skipped + 1;
      Ada.Text_IO.Put_Line ("SKIP" & ':' & ' ' & Test & ':' & ' ' & Reason);
   end Skip;

   function Skip_Count return Natural is (Skipped);
end Files_Suite.Support;
