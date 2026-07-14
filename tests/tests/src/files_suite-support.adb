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
with Textrender.Fonts;

with Files.Accessibility;
with Files.Application;
with Files.Application.Windows;
with Files.Command_Palette;
with Files.Commands;
with Files.Controller;
with Files.Drop_Events;
with Files.Events;
with Files.File_System;
with Files.File_Types;
with Files.Features;
with Files.Fonts;
with Files.Localization;
with Files.Model;
with Files.Operations;
with Files.Platform;
with Guikit.Draw;
with Files.Rendering;
with Guikit.Vulkan;
with Files.Settings;
with Files.Types;
with Files.UTF8;
with Files.UI;
with Files.Platform.Symlinks;

package body Files_Suite.Support is

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
      return Files.Platform.Symlinks.Create (Target, Linkpath);
   end Create_Symlink;

   procedure Reset_Root is
   begin
      Project_Tools.Files.Delete_Tree (Root);
      Ada.Directories.Create_Path (Root);
   end Reset_Root;

   procedure Write_File (Path : String; Content : String := "x") is
   begin
      Project_Tools.Files.Write_Text_File (Path, Content);
   end Write_File;

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
      return String is
   begin
      return
        Byte ((Data'Length / 16#1000000#) mod 256) &
        Byte ((Data'Length / 16#10000#) mod 256) &
        Byte ((Data'Length / 16#100#) mod 256) &
        Byte (Data'Length mod 256) &
        Kind & Data &
        Byte (0) & Byte (0) & Byte (0) & Byte (0);
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

   function Can_Launch_Child_Processes return Boolean is
   begin
      return Files.Platform.Current_API_Profile.Adapter
               /= Files.File_System.Native_Adapter_Windows;
   end Can_Launch_Child_Processes;

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

end Files_Suite.Support;
