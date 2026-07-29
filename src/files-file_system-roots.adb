with Files.File_System.Support;
with Ada.Strings.Unbounded;
with Ada.Directories;
with Ada.Text_IO;
with Ada.Strings.Fixed;
with Files.Fs;
with Files_Config;
with Files.Platform.Macos;
with Files.Platform.Metadata;
with Files.Platform.Windows;

package body Files.File_System.Roots is
   use Files.File_System.Support;
   use Ada.Strings.Unbounded;

   use type Ada.Directories.File_Kind;
   type Volume_Size_Info is record
      Capacity_Bytes   : Long_Long_Integer := 0;
      Free_Bytes       : Long_Long_Integer := 0;
      Inode_Count      : Long_Long_Integer := 0;
      Free_Inode_Count : Long_Long_Integer := 0;
      Name_Max         : Natural := 0;
      Read_Only        : Boolean := False;
      Known            : Boolean := False;
      Inodes_Known     : Boolean := False;
      Name_Max_Known   : Boolean := False;
      Read_Only_Known  : Boolean := False;
   end record;

   type Mount_Metadata is record
      Source_Device   : Unbounded_String;
      Filesystem_Type : Unbounded_String;
      Mount_Options   : Unbounded_String;
      Removable       : Boolean := False;
      Removable_Known : Boolean := False;
      Found           : Boolean := False;
   end record;

   procedure Volume_Size_For
     (Path : String;
      Info : out Volume_Size_Info);

   function Mount_Field
     (Line  : String;
      Index : Positive)
      return String;

   function Simple_Device_Name (Source : String) return String;

   function Parent_Block_Device_Name (Device : String) return String;

   function Read_First_Line (Path : String) return String;

   function Removable_Status_For
     (Source : String;
      Known  : out Boolean)
      return Boolean;

   function Mount_Metadata_For_Root (Path : String) return Mount_Metadata;

   function Root_Label (Path : String; Kind : Root_Kind) return String is
   begin
      case Kind is
         when Root_Filesystem =>
            return (if Path = "/" then "root.filesystem" else Path);
         when Root_Home =>
            return "root.home";
         when Root_Current =>
            return "root.current";
         when Root_Mount =>
            return "root.mount|" & Ada.Directories.Simple_Name (Path);
         when Root_User_Mount =>
            return "root.user_mount|" & Ada.Directories.Simple_Name (Path);
         when Root_Network_Mount =>
            return "root.network_mount|" & Ada.Directories.Simple_Name (Path);
         when Root_Windows_Drive =>
            return "root.drive|" & Path;
         when Root_Favorite =>
            return "root.favorite|" & Ada.Directories.Simple_Name (Path);
      end case;
   exception
      when others =>
         return Path;
   end Root_Label;

   function Available_Root_Entries return Root_Entry_Vectors.Vector is separate;

   function Available_Roots return Files.Types.String_Vectors.Vector is
      Entries : constant Root_Entry_Vectors.Vector := Available_Root_Entries;
      Roots   : Files.Types.String_Vectors.Vector;
   begin
      for Root of Entries loop
         Roots.Append (Root.Path);
      end loop;

      return Roots;
   end Available_Roots;

   function Root_Discovery_Status return Root_Discovery_Diagnostics is separate;

   function Root_Volume_Capabilities_Of_Current_Environment
      return Root_Volume_Capabilities is separate;

   function Filesystem_Edge_Case_Profile_Of_Current_Environment
      return Filesystem_Edge_Case_Profile is
   begin
      return
        (Permission_Errors_Recoverable => True,
         Symlink_Items_Represented     => True,
         Special_File_Items_Represented => True,
         Cross_Device_Rename_Recoverable => True,
         Trash_Preflight               => True,
         Metadata_Partial_Items        => True,
         Removable_Root_Metadata       => True,
         Native_Root_Volume_Details    => True);
   end Filesystem_Edge_Case_Profile_Of_Current_Environment;

   function Native_Platform_API_Profile_For
     (Adapter : Native_Platform_Adapter)
      return Native_Platform_API_Profile
 is separate;

   procedure Volume_Size_For
     (Path : String;
      Info : out Volume_Size_Info)
   is
      Capacity : constant Files.Platform.Metadata.Volume_Capacity :=
        Files.Platform.Metadata.Volume_Capacity_Of (Path);
   begin
      Info :=
        (Capacity_Bytes   => Capacity.Capacity_Bytes,
         Free_Bytes       => Capacity.Free_Bytes,
         Inode_Count      => Capacity.Inode_Count,
         Free_Inode_Count => Capacity.Free_Inode_Count,
         Name_Max         => Capacity.Name_Max,
         Read_Only        => Capacity.Read_Only,
         Known            => Capacity.Available,
         Inodes_Known     => Capacity.Inodes_Known,
         Name_Max_Known   => Capacity.Name_Max_Known,
         Read_Only_Known  => Capacity.Read_Only_Known);
   end Volume_Size_For;

   function Mount_Field
     (Line  : String;
      Index : Positive)
      return String
 is separate;

   function Simple_Device_Name (Source : String) return String is
      Start : Natural := Source'First;
   begin
      for Index in reverse Source'Range loop
         if Source (Index) = '/' then
            Start := Index + 1;
            exit;
         end if;
      end loop;

      if Start > Source'Last then
         return "";
      end if;

      return Source (Start .. Source'Last);
   end Simple_Device_Name;

   function Parent_Block_Device_Name (Device : String) return String is
      Last : Natural := Device'Last;
   begin
      if Device = "" then
         return "";
      end if;

      while Last >= Device'First and then Device (Last) in '0' .. '9' loop
         Last := Last - 1;
      end loop;

      if Last >= Device'First and then Device (Last) = 'p' then
         Last := Last - 1;
      end if;

      if Last < Device'First then
         return Device;
      end if;

      return Device (Device'First .. Last);
   end Parent_Block_Device_Name;

   function Read_First_Line (Path : String) return String is
      File   : Ada.Text_IO.File_Type;
      Buffer : String (1 .. 256);
      Last   : Natural;
   begin
      if not Ada.Directories.Exists (Path) then
         return "";
      end if;

      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      Ada.Text_IO.Get_Line (File, Buffer, Last);
      Ada.Text_IO.Close (File);
      return Buffer (1 .. Last);
   exception
      when others =>
         Safe_Close (File);
         return "";
   end Read_First_Line;

   function Removable_Status_For
     (Source : String;
      Known  : out Boolean)
      return Boolean
 is separate;

   function Mount_Metadata_For_Root (Path : String) return Mount_Metadata is separate;

   function Root_Volume_Details_For
     (Root : Root_Entry)
      return Root_Volume_Details
 is separate;

   function Filetype_Metadata_Policy_Of_Current_Implementation
      return Filetype_Metadata_Policy is
   begin
      return
        (Uses_Extension_Mapping     => True,
         Uses_Mime_Sniffing         => False,
         Parses_Image_Dimensions    => True,
         Parses_Text_Encoding       => True,
         Parses_Archive_Entry_Count => True,
         Parses_Pdf_Page_Markers    => True,
         Parses_Media_Codecs        => False,
         Parses_Office_Package_Info => True);
   end Filetype_Metadata_Policy_Of_Current_Implementation;

end Files.File_System.Roots;
