with Ada.Directories;
with Ada.Streams;
with Ada.Strings.Unbounded;
with GNAT.OS_Lib;
with Files.Diagnostics;
with Files.IO.Fs_Primitives;
with Files.Images;
with Hostkit.Fs;

package body Files.File_System.Content_Info is
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;
   use type Ada.Streams.Stream_Element_Array;
   use type GNAT.OS_Lib.File_Descriptor;

   function Stream_Byte (Value : Ada.Streams.Stream_Element) return Natural is separate;

   Extra_Line_Limit : constant Natural := 20_000;

   Extra_Scan_Byte_Limit : constant Long_Long_Integer := 8_388_608;

   Max_Directory_Count_Entries : constant Natural := 10_000;

   ELF_Magic    : constant Ada.Streams.Stream_Element_Array (1 .. 4) :=
     [16#7F#, 16#45#, 16#4C#, 16#46#];   --  7F 'E' 'L' 'F'

   PE_Magic     : constant Ada.Streams.Stream_Element_Array (1 .. 2) :=
     [16#4D#, 16#5A#];                   --  'M' 'Z'

   Script_Magic : constant Ada.Streams.Stream_Element_Array (1 .. 2) :=
     [16#23#, 16#21#];                   --  '#' '!'

   --  Path's line count, stopped at Extra_Line_Limit lines or
   --  Extra_Scan_Byte_Limit bytes; Capped when it stopped there with more
   --  of the file left.
   procedure Count_Text_Lines
     (Path   : String;
      Count  : out Natural;
      Capped : out Boolean);

   function Text_Encoding_Name (Path : String) return String;

   function Text_Metadata_Info
     (Prefix : String;
      Path   : String)
      return Files.Extra_Info.Info;

   function Pdf_Page_Count_Info (Path : String) return Files.Extra_Info.Info;

   function Zip_Entry_Count_Info
     (Path    : String;
      Of_Kind : Files.Extra_Info.Kind;
      Subject : String)
      return Files.Extra_Info.Info;

   function Matches_Signature
     (Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset;
      Pattern : Ada.Streams.Stream_Element_Array)
      return Boolean;

   function Executable_Format_Info (Path : String) return Files.Extra_Info.Info;

   --  Path's direct entries, hidden ones only when Show_Hidden.
   function Directory_Count_Info
     (Path        : String;
      Show_Hidden : Boolean)
      return Files.Extra_Info.Info;

   --  The detail line's symlink entry: the target as stored, read no-follow.
   function Symlink_Target_Info (Path : String) return Files.Extra_Info.Info;

   function U16_BE
     (Buffer : Ada.Streams.Stream_Element_Array;
      Start  : Ada.Streams.Stream_Element_Offset)
      return Natural;

   function Image_Dimensions_Info
     (Path     : String;
      Filetype : String)
      return Files.Extra_Info.Info;

   procedure Close_Read_Descriptor
     (File : in out GNAT.OS_Lib.File_Descriptor)
   is separate;

   procedure Read_Descriptor
     (File   : GNAT.OS_Lib.File_Descriptor;
      Buffer : out Ada.Streams.Stream_Element_Array;
      Last   : out Ada.Streams.Stream_Element_Offset)
   is separate;

   procedure Count_Text_Lines
     (Path   : String;
      Count  : out Natural;
      Capped : out Boolean)
   is separate;

   function Text_Encoding_Name (Path : String) return String is separate;

   function Text_Metadata_Info
     (Prefix : String;
      Path   : String)
      return Files.Extra_Info.Info is separate;

   function Pdf_Page_Count_Info (Path : String) return Files.Extra_Info.Info is separate;

   function Zip_Entry_Count_Info
     (Path    : String;
      Of_Kind : Files.Extra_Info.Kind;
      Subject : String)
      return Files.Extra_Info.Info
   is separate;

   function Matches_Signature
     (Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset;
      Pattern : Ada.Streams.Stream_Element_Array)
      return Boolean
   is separate;

   function Executable_Format_Info (Path : String) return Files.Extra_Info.Info is separate;

   function Symlink_Target_Info (Path : String) return Files.Extra_Info.Info is separate;

   function Directory_Count_Info
     (Path        : String;
      Show_Hidden : Boolean)
      return Files.Extra_Info.Info
   is separate;

   function U16_BE
     (Buffer : Ada.Streams.Stream_Element_Array;
      Start  : Ada.Streams.Stream_Element_Offset)
      return Natural is separate;

   function Image_Dimensions_Info
     (Path     : String;
      Filetype : String)
      return Files.Extra_Info.Info
   is separate;

   function Extra_Info_Of
     (Path        : String;
      Kind        : Files.Types.Item_Kind;
      Filetype    : String;
      Show_Hidden : Boolean := True)
      return Files.Extra_Info.Info is separate;

end Files.File_System.Content_Info;
