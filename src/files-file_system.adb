with Ada.Characters.Handling;
with Ada.Containers.Ordered_Maps;
with Ada.Directories;
with Ada.Environment_Variables;
with Ada.Streams;
with Ada.Streams.Stream_IO;
with Ada.Strings.Fixed;
with Ada.Strings.Unbounded;
with Ada.Text_IO;

with Interfaces.C;
with Interfaces.C.Strings;

with System;
with System.Address_To_Access_Conversions;

with GNAT.OS_Lib;

with Zlib;

with Files.File_Types;
with Files.Fs;
with Files_Config;

with Files.Platform.Macos;
with Files.Platform.Metadata;
with Hostkit.Fs;
with Files.Platform.Macos.Trash;
with Files.Platform.Windows.Trash;
with Files.Platform.Windows;
with Files.UTF8;
with Files.File_System.Path;
with Files.File_System.Permissions;
with Files.File_System.Support;
with Files.File_System.Search;
with Files.File_System.Create;
with Files.File_System.Trash;
with Files.File_System.Roots;
with Files.File_System.Copy_Move;

package body Files.File_System is

   use Files.File_System.Support;
   use Ada.Strings.Unbounded;
   use type Interfaces.C.int;
   use type Interfaces.C.long;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.unsigned_long;
   use type Interfaces.C.Strings.chars_ptr;
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;

   use type System.Address;
   use type Files.Settings.Sort_Field;
   use type Files.Types.Item_Kind;


   function Gdk_Pixbuf_New_From_File_At_Size
     (Filename : Interfaces.C.Strings.chars_ptr;
      Width    : C_Int;
      Height   : C_Int;
      Error    : System.Address)
      return System.Address
   with Import, Convention => C, External_Name => "gdk_pixbuf_new_from_file_at_size";

   function Gdk_Pixbuf_Get_Width
     (Pixbuf : System.Address)
      return C_Int
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_width";

   function Gdk_Pixbuf_Get_Height
     (Pixbuf : System.Address)
      return C_Int
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_height";

   function Gdk_Pixbuf_Get_N_Channels
     (Pixbuf : System.Address)
      return C_Int
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_n_channels";

   function Gdk_Pixbuf_Get_Rowstride
     (Pixbuf : System.Address)
      return C_Int
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_rowstride";

   function Gdk_Pixbuf_Get_Pixels
     (Pixbuf : System.Address)
      return System.Address
   with Import, Convention => C, External_Name => "gdk_pixbuf_get_pixels";

   procedure G_Object_Unref
     (Object : System.Address)
   with Import, Convention => C, External_Name => "g_object_unref";


   Extra_Line_Limit : constant Natural := 20_000;

   procedure Safe_Free
     (Pointer : in out Interfaces.C.Strings.chars_ptr);

   procedure Safe_Free
     (Pointer : in out Interfaces.C.Strings.chars_ptr) is
   begin
      if Pointer /= Interfaces.C.Strings.Null_Ptr then
         begin
            Interfaces.C.Strings.Free (Pointer);
         exception
            when others =>
               null;
         end;
      end if;
   end Safe_Free;

   function Thumbnail_Extension
     (Source_Path : String)
      return String
   is
      Name : constant String := Ada.Directories.Simple_Name (Source_Path);
   begin
      for Index in reverse Name'Range loop
         if Name (Index) = '.' and then Index < Name'Last then
            return Files.Types.To_Lower (Name (Index + 1 .. Name'Last));
         end if;
      end loop;

      return "file";
   exception
      when others =>
         return "file";
   end Thumbnail_Extension;

   function Sanitized_Thumbnail_Extension
     (Source_Path : String)
      return String
   is
      Extension : constant String := Thumbnail_Extension (Source_Path);
      Result    : Unbounded_String;
   begin
      for Value of Extension loop
         if Ada.Characters.Handling.Is_Alphanumeric (Value) then
            Append (Result, Value);
         else
            Append (Result, '_');
         end if;
      end loop;

      if Length (Result) = 0 then
         return "file";
      end if;

      return To_String (Result);
   end Sanitized_Thumbnail_Extension;

   function Thumbnail_Path_Checksum
     (Source_Path : String)
      return Natural
   is
      Modulus : constant Long_Long_Integer := 1_000_000_007;
      Result  : Long_Long_Integer := 0;
   begin
      for Value of Source_Path loop
         Result := (Result * 33 + Long_Long_Integer (Character'Pos (Value))) mod Modulus;
      end loop;

      return Natural (Result);
   end Thumbnail_Path_Checksum;

   function Default_Thumbnail_Cache_Directory
     (Fallback_Directory : String)
      return String
   is
      Xdg_Cache : constant String := Safe_Environment_Value ("XDG_CACHE_HOME");
      Home      : constant String := Safe_Environment_Value ("HOME");
   begin
      if Xdg_Cache /= "" then
         return Join_Path (Join_Path (Xdg_Cache, "files"), "thumbnails");
      elsif Home /= "" then
         return Join_Path (Join_Path (Join_Path (Home, ".cache"), "files"), "thumbnails");
      else
         return Join_Path (Fallback_Directory, ".files-thumbnails");
      end if;
   end Default_Thumbnail_Cache_Directory;

   function Thumbnail_Path_For
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return String is
   begin
      return
        Join_Path
          (Cache_Directory,
           "thumb_"
           & Sanitized_Thumbnail_Extension (Source_Path)
           & "_"
           & Image_No_Space (Size)
           & "_"
           & Image_No_Space (Thumbnail_Path_Checksum (Source_Path))
           & ".ppm");
   end Thumbnail_Path_For;

   type Cached_Thumbnail is record
      Loaded : Boolean := False;
      Width  : Natural := 0;
      Height : Natural := 0;
      Pixels : Files.Types.Byte_Vectors.Vector;
   end record;

   function Load_Cached_Thumbnail
     (Path : String)
      return Cached_Thumbnail
   is
      Content : Unbounded_String;
      Token   : Unbounded_String;
      Cursor  : Positive := 1;
      Result  : Cached_Thumbnail;

      procedure Flush_Token
        (Tokens : in out Files.Types.String_Vectors.Vector)
      is
      begin
         if Length (Token) > 0 then
            Tokens.Append (Token);
            Token := Null_Unbounded_String;
         end if;
      end Flush_Token;

      function Tokens return Files.Types.String_Vectors.Vector is
         Values     : Files.Types.String_Vectors.Vector;
         In_Comment : Boolean := False;
      begin
         for Value of To_String (Content) loop
            if In_Comment then
               if Value = ASCII.LF or else Value = ASCII.CR then
                  In_Comment := False;
               end if;
            elsif Value = '#' then
               Flush_Token (Values);
               In_Comment := True;
            elsif Value = ' ' or else Value = ASCII.HT or else Value = ASCII.LF or else Value = ASCII.CR then
               Flush_Token (Values);
            else
               Append (Token, Value);
            end if;
         end loop;

         Flush_Token (Values);
         return Values;
      end Tokens;

      function Natural_Value
        (Text : String;
         Value : out Natural)
         return Boolean
      is
      begin
         Value := 0;
         if Text = "" then
            return False;
         end if;

         for Character_Value of Text loop
            if Character_Value not in '0' .. '9'
              or else Value > (Natural'Last - Character'Pos (Character_Value) + Character'Pos ('0')) / 10
            then
               return False;
            end if;
            Value := Value * 10 + Character'Pos (Character_Value) - Character'Pos ('0');
         end loop;

         return True;
      end Natural_Value;

      function Channel
        (Value     : Natural;
         Max_Value : Natural)
         return Interfaces.Unsigned_8 is
      begin
         if Max_Value = 0 then
            return 0;
         elsif Max_Value = 255 then
            return Interfaces.Unsigned_8 (Natural'Min (Value, 255));
         else
            return Interfaces.Unsigned_8 (Natural'Min ((Value * 255) / Max_Value, 255));
         end if;
      end Channel;
   begin
      if Path = ""
        or else not Files.Fs.File_Exists (Path)
      then
         return Result;
      end if;

      Content := Files.Fs.Read_Text_File (Path);

      declare
         Values    : constant Files.Types.String_Vectors.Vector := Tokens;
         Width     : Natural;
         Height    : Natural;
         Max_Value : Natural;
      begin
         if Natural (Values.Length) < 4
           or else To_String (Values.Element (1)) /= "P3"
           or else not Natural_Value (To_String (Values.Element (2)), Width)
           or else not Natural_Value (To_String (Values.Element (3)), Height)
           or else not Natural_Value (To_String (Values.Element (4)), Max_Value)
           or else Width = 0
           or else Height = 0
           or else Max_Value = 0
           or else Natural (Values.Length) < 4 + Width * Height * 3
         then
            return Result;
         end if;

         Cursor := 5;
         for Pixel in 1 .. Width * Height loop
            declare
               R : Natural;
               G : Natural;
               B : Natural;
            begin
               if not Natural_Value (To_String (Values.Element (Cursor)), R)
                 or else not Natural_Value (To_String (Values.Element (Cursor + 1)), G)
                 or else not Natural_Value (To_String (Values.Element (Cursor + 2)), B)
               then
                  return Result;
               end if;

               Result.Pixels.Append (Channel (R, Max_Value));
               Result.Pixels.Append (Channel (G, Max_Value));
               Result.Pixels.Append (Channel (B, Max_Value));
               Result.Pixels.Append (255);
               Cursor := Cursor + 3;
            end;
         end loop;

         Result.Loaded := True;
         Result.Width := Width;
         Result.Height := Height;
         return Result;
      end;
   exception
      when others =>
         return (Loaded => False, Width => 0, Height => 0, Pixels => Files.Types.Byte_Vectors.Empty_Vector);
   end Load_Cached_Thumbnail;

   function Is_Image_Item
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean
   is
      Extension : constant String := Files.File_Types.Extension_Of (Name);
   begin
      if Kind = Files.Types.Directory_Item
        or else Kind = Files.Types.Symlink_Item
      then
         return False;
      end if;

      return Starts_With (Files.Types.To_Lower (Filetype), "image/")
        or else Files.Types.To_Lower (Icon_Id) = "image"
        or else Extension = "png"
        or else Extension = "jpg"
        or else Extension = "jpeg"
        or else Extension = "gif"
        or else Extension = "bmp"
        or else Extension = "webp"
        or else Extension = "tif"
        or else Extension = "tiff"
        or else Extension = "ppm";
   end Is_Image_Item;

   function Should_Auto_Generate_Thumbnail
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean is
   begin
      return Is_Image_Item (Kind, Filetype, Name, Icon_Id);
   end Should_Auto_Generate_Thumbnail;

   function Read_Preview_Text
     (Path      : String;
      Max_Bytes : Natural)
      return String
   is
      package Stream_IO renames Ada.Streams.Stream_IO;

      File   : Stream_IO.File_Type;
      Result : Ada.Strings.Unbounded.Unbounded_String;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last   : Ada.Streams.Stream_Element_Offset;
      Total  : Natural := 0;
   begin
      if Max_Bytes = 0 then
         return "";
      end if;

      Stream_IO.Open (File, Stream_IO.In_File, Path);
      while not Stream_IO.End_Of_File (File) and then Total < Max_Bytes loop
         Stream_IO.Read (File, Buffer, Last);
         for Index in Buffer'First .. Last loop
            exit when Total >= Max_Bytes;
            Ada.Strings.Unbounded.Append
              (Result, Character'Val (Natural (Buffer (Index))));
            Total := Total + 1;
         end loop;
      end loop;

      Stream_IO.Close (File);
      return Ada.Strings.Unbounded.To_String (Result);
   exception
      when others =>
         Safe_Close (File);
         return Ada.Strings.Unbounded.To_String (Result);
   end Read_Preview_Text;

   function Thumbnail_For_Item
     (Full_Path       : String;
      Kind            : Files.Types.Item_Kind;
      Filetype        : String;
      Name            : String;
      Icon_Id         : String;
      Cache_Directory : String;
      Thumbnail_Path  : String)
      return Cached_Thumbnail
   is
      Loaded : Cached_Thumbnail := Load_Cached_Thumbnail (Thumbnail_Path);
   begin
      if Loaded.Loaded
        or else not Should_Auto_Generate_Thumbnail (Kind, Filetype, Name, Icon_Id)
      then
         return Loaded;
      end if;

      declare
         Generated : constant Thumbnail_Result :=
           Generate_Thumbnail (Full_Path, Cache_Directory);
      begin
         if Generated.Status = Thumbnail_Generated then
            Loaded := Load_Cached_Thumbnail (To_String (Generated.Thumbnail_Path));
         end if;
      end;

      return Loaded;
   exception
      when others =>
         return Loaded;
   end Thumbnail_For_Item;


   function Is_Directory (Item : Directory_Item) return Boolean is
   begin
      return Item.Kind = Files.Types.Directory_Item;
   end Is_Directory;

   --  The trash operations now live in the
   --  Files.File_System.Trash child; these renamings keep them on the public API.
   function Trash_Is_Available return Boolean
     renames Files.File_System.Trash.Trash_Is_Available;

   function Trash_Backend_Of_Current_Environment return Trash_Backend
     renames Files.File_System.Trash.Trash_Backend_Of_Current_Environment;

   function Trash_Capabilities_Of_Current_Environment return Trash_Capabilities
     renames Files.File_System.Trash.Trash_Capabilities_Of_Current_Environment;

   function Native_Trash_Request_For
     (Path : String)
      return Native_Trash_Request
     renames Files.File_System.Trash.Native_Trash_Request_For;

   function Evaluate_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result
     renames Files.File_System.Trash.Evaluate_Native_Trash;

   function Execute_Native_Trash
     (Request : Native_Trash_Request)
      return Native_Trash_Result
     renames Files.File_System.Trash.Execute_Native_Trash;

   function Move_To_Trash_Preflight
     (Path : String)
      return Mutation_Result
     renames Files.File_System.Trash.Move_To_Trash_Preflight;

   function Trash_Deletion_Date
     (Value : Ada.Calendar.Time)
      return String
     renames Files.File_System.Trash.Trash_Deletion_Date;

   function Trash_Files_Directory return String
     renames Files.File_System.Trash.Trash_Files_Directory;

   function Restore_From_Trash
     (Trashed_Path : String)
      return Mutation_Result
     renames Files.File_System.Trash.Restore_From_Trash;

   function Move_To_Trash
     (Path : String)
      return Mutation_Result
     renames Files.File_System.Trash.Move_To_Trash;

   function Move_To_Trash
     (Path         : String;
      Trashed_Path : out Files.Types.UString)
      return Mutation_Result
     renames Files.File_System.Trash.Move_To_Trash;

   function Delete_Trashed_Item
     (Trashed_Path : String)
      return Mutation_Result
     renames Files.File_System.Trash.Delete_Trashed_Item;

   --  The path operations now live in the
   --  Files.File_System.Path child; these renamings keep them on the public API.
   function Normalize_Path
     (Path : String)
      return Path_Result
     renames Files.File_System.Path.Normalize_Path;

   function Parent_Directory
     (Path : String)
      return String
     renames Files.File_System.Path.Parent_Directory;

   function Join_Path
     (Parent_Path : String;
      Name        : String)
      return String
     renames Files.File_System.Path.Join_Path;

   function Valid_Leaf_Name
     (Name : String)
      return Boolean
     renames Files.File_System.Path.Valid_Leaf_Name;

   function Next_Untitled_Name
     (Directory_Path : String)
      return String
     renames Files.File_System.Path.Next_Untitled_Name;

   procedure Sort_Items
     (Items     : in out Item_Vectors.Vector;
      Field     : Files.Settings.Sort_Field;
      Ascending : Boolean)
   is
      Count : constant Natural := Natural (Items.Length);
   begin
      if Count <= 1 then
         return;
      end if;

      declare
         --  Decorate-sort: the case-insensitive comparison recomputed To_Lower
         --  on both names for every one of the sort's O(N log N) comparisons.
         --  Here each item's lowercase keys are built once (N times), the sort
         --  reorders a cheap index permutation reading those keys, and the
         --  items are moved into place a single time at the end.
         type Sort_Key is record
            Name_Lower     : Unbounded_String;
            Filetype_Lower : Unbounded_String;
         end record;

         package Key_Vectors is new Ada.Containers.Vectors
           (Index_Type => Positive, Element_Type => Sort_Key);
         package Index_Vectors is new Ada.Containers.Vectors
           (Index_Type => Positive, Element_Type => Positive);

         --  Name_Lower is always needed -- it is the final tie-break for every
         --  field; Filetype_Lower only when sorting by filetype.
         Keys  : Key_Vectors.Vector;
         Order : Index_Vectors.Vector;

         function Name_Less (Left, Right : Positive) return Boolean is
         begin
            if Keys (Left).Name_Lower /= Keys (Right).Name_Lower then
               return Keys (Left).Name_Lower < Keys (Right).Name_Lower;
            else
               return Items (Left).Name < Items (Right).Name;
            end if;
         end Name_Less;

         function Text_Less (Left, Right : Positive) return Boolean is
         begin
            if Keys (Left).Filetype_Lower /= Keys (Right).Filetype_Lower then
               return Keys (Left).Filetype_Lower < Keys (Right).Filetype_Lower;
            else
               return Items (Left).Filetype < Items (Right).Filetype;
            end if;
         end Text_Less;

         function Less (Left, Right : Positive) return Boolean is
            Forward_Order : Boolean := False;
            Reverse_Order : Boolean := False;
         begin
            case Field is
               when Files.Settings.Sort_By_Name =>
                  Forward_Order := Name_Less (Left => Left, Right => Right);
                  Reverse_Order := Name_Less (Left => Right, Right => Left);
               when Files.Settings.Sort_By_Filetype =>
                  Forward_Order := Text_Less (Left => Left, Right => Right);
                  Reverse_Order := Text_Less (Left => Right, Right => Left);
               when Files.Settings.Sort_By_Size =>
                  if Items (Left).Size_Available /= Items (Right).Size_Available then
                     return Items (Left).Size_Available;
                  elsif Items (Left).Size /= Items (Right).Size then
                     Forward_Order := Items (Left).Size < Items (Right).Size;
                     Reverse_Order := Items (Right).Size < Items (Left).Size;
                  end if;
               when Files.Settings.Sort_By_Created =>
                  if Items (Left).Creation_Available /= Items (Right).Creation_Available then
                     return Items (Left).Creation_Available;
                  elsif Items (Left).Creation_Time /= Items (Right).Creation_Time then
                     Forward_Order := Items (Left).Creation_Time < Items (Right).Creation_Time;
                     Reverse_Order := Items (Right).Creation_Time < Items (Left).Creation_Time;
                  end if;
               when Files.Settings.Sort_By_Modified =>
                  if Items (Left).Modified_Available /= Items (Right).Modified_Available then
                     return Items (Left).Modified_Available;
                  elsif Items (Left).Modified_Time /= Items (Right).Modified_Time then
                     Forward_Order := Items (Left).Modified_Time < Items (Right).Modified_Time;
                     Reverse_Order := Items (Right).Modified_Time < Items (Left).Modified_Time;
                  end if;
            end case;

            if Field /= Files.Settings.Sort_By_Name
              and then not Forward_Order
              and then not Reverse_Order
            then
               return Name_Less (Left, Right);
            elsif Ascending then
               return Forward_Order;
            else
               return Reverse_Order;
            end if;
         end Less;

         package Sorting is new Index_Vectors.Generic_Sorting ("<" => Less);

         Sorted : Item_Vectors.Vector;
      begin
         Keys.Reserve_Capacity (Ada.Containers.Count_Type (Count));
         Order.Reserve_Capacity (Ada.Containers.Count_Type (Count));
         for Index in 1 .. Count loop
            declare
               Key : Sort_Key;
            begin
               Key.Name_Lower :=
                 To_Unbounded_String (Files.Types.To_Lower (To_String (Items (Index).Name)));
               if Field = Files.Settings.Sort_By_Filetype then
                  Key.Filetype_Lower :=
                    To_Unbounded_String (Files.Types.To_Lower (To_String (Items (Index).Filetype)));
               end if;
               Keys.Append (Key);
            end;
            Order.Append (Index);
         end loop;

         --  Generic_Sorting is stable and Order starts ascending, so items that
         --  compare equal keep their original relative order -- matching the old
         --  in-place sort of Items exactly.
         Sorting.Sort (Order);

         Sorted.Reserve_Capacity (Ada.Containers.Count_Type (Count));
         for Index of Order loop
            Sorted.Append (Items (Index));
         end loop;

         Item_Vectors.Move (Target => Items, Source => Sorted);
      end;
   end Sort_Items;

   function Permission_String (Path : String) return String is
      Result : String (1 .. 3) := "---";
   begin
      if GNAT.OS_Lib.Is_Owner_Readable_File (Path) then
         Result (1) := 'r';
      end if;
      if GNAT.OS_Lib.Is_Owner_Writable_File (Path) then
         Result (2) := 'w';
      end if;
      if Hostkit.Fs.Is_Executable (Path) then
         Result (3) := 'x';
      end if;

      return Result;
   exception
      when others =>
         return "";
   end Permission_String;

   function Count_Text_Lines (Path : String) return Natural is
      package Stream_IO renames Ada.Streams.Stream_IO;

      File        : Stream_IO.File_Type;
      Buffer      : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last        : Ada.Streams.Stream_Element_Offset;
      Count       : Natural := 0;
      Saw_Byte    : Boolean := False;
      Last_Was_LF : Boolean := False;
   begin
      Stream_IO.Open (File, Stream_IO.In_File, Path);
      while not Stream_IO.End_Of_File (File) and then Count < Extra_Line_Limit loop
         Stream_IO.Read (File, Buffer, Last);
         if Last >= Buffer'First then
            for Index in Buffer'First .. Last loop
               Saw_Byte := True;
               Last_Was_LF := Buffer (Index) = Ada.Streams.Stream_Element (Character'Pos (ASCII.LF));
               if Last_Was_LF then
                  Count := Count + 1;
                  exit when Count >= Extra_Line_Limit;
               end if;
            end loop;
         end if;
      end loop;

      if Count < Extra_Line_Limit and then Saw_Byte and then not Last_Was_LF then
         Count := Count + 1;
      end if;

      Stream_IO.Close (File);
      return Count;
   exception
      when others =>
         Safe_Close (File);
         return 0;
   end Count_Text_Lines;

   function Text_Encoding_Name (Path : String) return String is
      File       : Ada.Streams.Stream_IO.File_Type;
      Buffer     : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last       : Ada.Streams.Stream_Element_Offset;
      Byte_Value : Natural;
      Ascii_Only : Boolean := True;
      Pending    : Natural := 0;
      First_Byte : Natural := 0;
      Step       : Natural := 0;

      function Valid_First_Continuation
        (Byte_Value : Natural;
         Second     : Natural)
         return Boolean is
      begin
         if Byte_Value = 16#E0# and then Second < 16#A0# then
            return False;
         elsif Byte_Value = 16#ED# and then Second > 16#9F# then
            return False;
         elsif Byte_Value = 16#F0# and then Second < 16#90# then
            return False;
         elsif Byte_Value = 16#F4# and then Second > 16#8F# then
            return False;
         end if;

         return True;
      end Valid_First_Continuation;

      function Is_Continuation (Value : Natural) return Boolean is
      begin
         return Value >= 16#80# and then Value <= 16#BF#;
      end Is_Continuation;
   begin
      Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Path);

      while not Ada.Streams.Stream_IO.End_Of_File (File) loop
         Ada.Streams.Stream_IO.Read (File, Buffer, Last);
         if Last >= Buffer'First then
            for Index in Buffer'First .. Last loop
               Byte_Value := Natural (Buffer (Index));

               if Pending > 0 then
                  if not Is_Continuation (Byte_Value) then
                     Ada.Streams.Stream_IO.Close (File);
                     return "binary";
                  elsif Step = 1 and then not Valid_First_Continuation (First_Byte, Byte_Value) then
                     Ada.Streams.Stream_IO.Close (File);
                     return "binary";
                  end if;

                  Pending := Pending - 1;
                  Step := Step + 1;
               elsif Byte_Value = 0 then
                  Ada.Streams.Stream_IO.Close (File);
                  return "binary";
               elsif Byte_Value <= 16#7F# then
                  null;
               elsif Byte_Value in 16#C2# .. 16#DF# then
                  Ascii_Only := False;
                  First_Byte := Byte_Value;
                  Pending := 1;
                  Step := 1;
               elsif Byte_Value in 16#E0# .. 16#EF# then
                  Ascii_Only := False;
                  First_Byte := Byte_Value;
                  Pending := 2;
                  Step := 1;
               elsif Byte_Value in 16#F0# .. 16#F4# then
                  Ascii_Only := False;
                  First_Byte := Byte_Value;
                  Pending := 3;
                  Step := 1;
               else
                  Ada.Streams.Stream_IO.Close (File);
                  return "binary";
               end if;
            end loop;
         end if;
      end loop;
      Ada.Streams.Stream_IO.Close (File);

      if Pending > 0 then
         return "binary";
      end if;

      return (if Ascii_Only then "ascii" else "utf8");
   exception
      when others =>
         Safe_Close (File);
         return "binary";
   end Text_Encoding_Name;

   function Text_Metadata_Token
     (Prefix : String;
      Path   : String)
      return String is
   begin
      return Prefix & ".lines_encoding|" & Natural_Text (Count_Text_Lines (Path)) & "|" & Text_Encoding_Name (Path);
   end Text_Metadata_Token;

   function Pdf_Page_Count_Token (Path : String) return String is
      File   : Ada.Text_IO.File_Type;
      Buffer : String (1 .. 4096);
      Last   : Natural;
      Count  : Natural := 0;

      function Page_Marker_At
        (Line : String;
         Pos  : Positive)
         return Boolean
      is
         Marker_Last : constant Natural := Pos + String'("/Type /Page")'Length - 1;
      begin
         if Marker_Last > Line'Last then
            return False;
         elsif Line (Pos .. Marker_Last) /= "/Type /Page" then
            return False;
         elsif Marker_Last = Line'Last then
            return True;
         end if;

         declare
            Next : constant Character := Line (Marker_Last + 1);
         begin
            return Next = ' '
              or else Next = ASCII.HT
              or else Next = ASCII.LF
              or else Next = ASCII.CR
              or else Next = ASCII.VT
              or else Next = ASCII.FF
              or else Next = '/'
              or else Next = '>'
              or else Next = '<'
              or else Next = ']'
              or else Next = '[';
         end;
      end Page_Marker_At;
   begin
      Ada.Text_IO.Open (File, Ada.Text_IO.In_File, Path);
      while not Ada.Text_IO.End_Of_File (File) loop
         Ada.Text_IO.Get_Line (File, Buffer, Last);
         if Last > 0 then
            declare
               Line : constant String := Buffer (1 .. Last);
               Pos  : Natural := Ada.Strings.Fixed.Index (Line, "/Type /Page");
            begin
               while Pos > 0 loop
                  if Page_Marker_At (Line, Pos) then
                     Count := Count + 1;
                  end if;
                  exit when Pos + 10 > Line'Last;
                  Pos := Ada.Strings.Fixed.Index (Line (Pos + 10 .. Line'Last), "/Type /Page");
               end loop;
            end;
         end if;
      end loop;
      Ada.Text_IO.Close (File);
      return "document.pdf.pages|" & Natural_Text (Count);
   exception
      when others =>
         Safe_Close (File);
         return "document.kind|pdf";
   end Pdf_Page_Count_Token;

   function Zip_Entry_Count_Token
     (Path   : String;
      Prefix : String)
      return String
   is
      package Stream_IO renames Ada.Streams.Stream_IO;

      File   : Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last   : Ada.Streams.Stream_Element_Offset;
      Count  : Natural := 0;
      Byte_0 : Ada.Streams.Stream_Element := 0;
      Byte_1 : Ada.Streams.Stream_Element := 0;
      Byte_2 : Ada.Streams.Stream_Element := 0;
      Byte_3 : Ada.Streams.Stream_Element := 0;
      Seen   : Natural := 0;
   begin
      Stream_IO.Open (File, Stream_IO.In_File, Path);
      while not Stream_IO.End_Of_File (File) loop
         Stream_IO.Read (File, Buffer, Last);
         if Last >= Buffer'First then
            for Index in Buffer'First .. Last loop
               Byte_0 := Byte_1;
               Byte_1 := Byte_2;
               Byte_2 := Byte_3;
               Byte_3 := Buffer (Index);
               if Seen < 4 then
                  Seen := Seen + 1;
               end if;

               if Seen = 4
                 and then Byte_0 = 16#50#
                 and then Byte_1 = 16#4B#
                 and then Byte_2 = 16#01#
                 and then Byte_3 = 16#02#
               then
                  Count := Count + 1;
               end if;
            end loop;
         end if;
      end loop;
      Stream_IO.Close (File);
      return Prefix & ".entries|" & Natural_Text (Count);
   exception
      when others =>
         Safe_Close (File);
         return Prefix & ".entries|0";
   end Zip_Entry_Count_Token;

   --  Leading magic bytes that identify a file format, one per row.
   ELF_Magic    : constant Ada.Streams.Stream_Element_Array (1 .. 4) :=
     [16#7F#, 16#45#, 16#4C#, 16#46#];   --  7F 'E' 'L' 'F'
   PE_Magic     : constant Ada.Streams.Stream_Element_Array (1 .. 2) :=
     [16#4D#, 16#5A#];                   --  'M' 'Z'
   Script_Magic : constant Ada.Streams.Stream_Element_Array (1 .. 2) :=
     [16#23#, 16#21#];                   --  '#' '!'
   PNG_Magic    : constant Ada.Streams.Stream_Element_Array (1 .. 8) :=
     [16#89#, 16#50#, 16#4E#, 16#47#, 16#0D#, 16#0A#, 16#1A#, 16#0A#];
                                         --  89 'P' 'N' 'G' CR LF 1A LF

   --  True when the first Pattern'Length bytes read into Buffer (of which Last
   --  were read) equal Pattern. Buffer and Pattern are both 1-based.
   function Matches_Signature
     (Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset;
      Pattern : Ada.Streams.Stream_Element_Array)
      return Boolean
   is
      use type Ada.Streams.Stream_Element_Array;
   begin
      return Last >= Pattern'Last and then Buffer (Pattern'Range) = Pattern;
   end Matches_Signature;

   function Executable_Format_Token (Path : String) return String is
      package Stream_IO renames Ada.Streams.Stream_IO;

      File   : Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 4);
      Last   : Ada.Streams.Stream_Element_Offset;
   begin
      Stream_IO.Open (File, Stream_IO.In_File, Path);
      Stream_IO.Read (File, Buffer, Last);
      Stream_IO.Close (File);

      if Matches_Signature (Buffer, Last, ELF_Magic) then
         return "executable.format|elf";
      elsif Matches_Signature (Buffer, Last, PE_Magic) then
         return "executable.format|pe";
      elsif Matches_Signature (Buffer, Last, Script_Magic) then
         return "executable.format|script";
      else
         return "executable.format|unknown";
      end if;
   exception
      when others =>
         Safe_Close (File);
         return "";
   end Executable_Format_Token;

   function Directory_Count_Token (Path : String) return String is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Count     : Natural := 0;
      Started   : Boolean := False;
   begin
      if not Files.Fs.Directory_Exists (Path)
      then
         return "";
      end if;

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
            Ada.Directories.Directory     => True,
            Ada.Directories.Special_File  => True]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
         begin
            if Name /= "." and then Name /= ".." then
               Count := Count + 1;
            end if;
         end;
      end loop;

      Safe_End_Search (Search, Started);
      return "directory.count|" & Natural_Text (Count);
   exception
      when others =>
         Safe_End_Search (Search, Started);
         return "";
   end Directory_Count_Token;

   function Stream_Byte (Value : Ada.Streams.Stream_Element) return Natural is
   begin
      return Natural (Value);
   end Stream_Byte;

   function U16_BE
     (Buffer : Ada.Streams.Stream_Element_Array;
      Start  : Ada.Streams.Stream_Element_Offset)
      return Natural is
   begin
      return Stream_Byte (Buffer (Start)) * 256 + Stream_Byte (Buffer (Start + 1));
   end U16_BE;

   function U32_BE
     (Buffer : Ada.Streams.Stream_Element_Array;
      Start  : Ada.Streams.Stream_Element_Offset)
      return Natural is
   begin
      return
        Stream_Byte (Buffer (Start)) * 16#1000000#
        + Stream_Byte (Buffer (Start + 1)) * 16#10000#
        + Stream_Byte (Buffer (Start + 2)) * 16#100#
        + Stream_Byte (Buffer (Start + 3));
   end U32_BE;

   function Dimensions_Text
     (Width  : Natural;
      Height : Natural)
      return String is
   begin
      if Width = 0 or else Height = 0 then
         return "";
      end if;

      return Natural_Text (Width) & "x" & Natural_Text (Height);
   end Dimensions_Text;

   function Image_Dimensions_Token
     (Path     : String;
      Filetype : String)
      return String
   is
      package Stream_IO renames Ada.Streams.Stream_IO;
      use type Stream_IO.Count;

      File   : Stream_IO.File_Type;
      Buffer : Ada.Streams.Stream_Element_Array (1 .. 32);
      Last   : Ada.Streams.Stream_Element_Offset;

      function Is_PNG return Boolean is
      begin
         --  Also require the 24 bytes the IHDR width/height are read from below.
         return Last >= 24 and then Matches_Signature (Buffer, Last, PNG_Magic);
      end Is_PNG;

      function JPEG_Token return String is
         Segment_Buffer : Ada.Streams.Stream_Element_Array (1 .. 9);
         Segment_Last   : Ada.Streams.Stream_Element_Offset;
         Marker         : Ada.Streams.Stream_Element;
         Length_Value   : Natural;
         Remaining      : Natural;
      begin
         Stream_IO.Set_Index (File, 3);
         while not Stream_IO.End_Of_File (File) loop
            Stream_IO.Read (File, Segment_Buffer (1 .. 1), Segment_Last);
            exit when Segment_Last < 1 or else Segment_Buffer (1) /= 16#FF#;

            loop
               Stream_IO.Read (File, Segment_Buffer (1 .. 1), Segment_Last);
               exit when Segment_Last < 1 or else Segment_Buffer (1) /= 16#FF#;
            end loop;

            exit when Segment_Last < 1;
            Marker := Segment_Buffer (1);

            if Marker = 16#00# then
               null;
            elsif Marker in 16#D0# .. 16#D7# or else Marker = 16#01# then
               null;
            else
               exit when Marker = 16#D9# or else Marker = 16#DA#;
               Stream_IO.Read (File, Segment_Buffer (1 .. 2), Segment_Last);
               exit when Segment_Last < 2;
               Length_Value := U16_BE (Segment_Buffer, 1);
               exit when Length_Value < 2;

               if Marker in 16#C0# .. 16#C3# or else Marker in 16#C5# .. 16#C7#
                 or else Marker in 16#C9# .. 16#CB# or else Marker in 16#CD# .. 16#CF#
               then
                  Stream_IO.Read (File, Segment_Buffer (1 .. 5), Segment_Last);
                  if Segment_Last >= 5 then
                     return "image.dimensions|" &
                       Dimensions_Text (U16_BE (Segment_Buffer, 4), U16_BE (Segment_Buffer, 2));
                  end if;
                  return "";
               end if;

               Remaining := Length_Value - 2;
               if Remaining > 0 then
                  Stream_IO.Set_Index
                    (File,
                     Stream_IO.Positive_Count (Stream_IO.Count (Stream_IO.Index (File)) + Stream_IO.Count (Remaining)));
               end if;
            end if;
         end loop;

         return "";
      end JPEG_Token;
   begin
      if Filetype /= "image/png" and then Filetype /= "image/jpeg" then
         return "";
      end if;

      Stream_IO.Open (File, Stream_IO.In_File, Path);
      Stream_IO.Read (File, Buffer, Last);

      if Filetype = "image/png" and then Is_PNG then
         declare
            Token : constant String := "image.dimensions|" & Dimensions_Text (U32_BE (Buffer, 17), U32_BE (Buffer, 21));
         begin
            Stream_IO.Close (File);
            return Token;
         end;
      elsif Filetype = "image/jpeg"
        and then Last >= 2
        and then Buffer (1) = 16#FF#
        and then Buffer (2) = 16#D8#
      then
         declare
            Token : constant String := JPEG_Token;
         begin
            Stream_IO.Close (File);
            return Token;
         end;
      end if;

      Stream_IO.Close (File);
      return "";
   exception
      when others =>
         Safe_Close (File);
         return "";
   end Image_Dimensions_Token;

   function Extra_Info_Token
     (Path     : String;
      Kind     : Files.Types.Item_Kind;
      Filetype : String)
      return String is
   begin
      case Kind is
         when Files.Types.Directory_Item =>
            return Directory_Count_Token (Path);
         when Files.Types.Executable_Item =>
            return Executable_Format_Token (Path);
         when Files.Types.Symlink_Item =>
            return Files.Platform.Metadata.Symlink_Target_Token (Path);
         when Files.Types.Regular_File_Item =>
            if Filetype = "text/plain" then
               return Text_Metadata_Token ("text", Path);
            elsif Filetype = "text/x-ada" then
               return Text_Metadata_Token ("source.ada", Path);
            elsif Filetype = "application/json" then
               return Text_Metadata_Token ("source.json", Path);
            elsif Filetype = "application/xml" then
               return Text_Metadata_Token ("source.xml", Path);
            elsif Filetype = "text/markdown" then
               return Text_Metadata_Token ("markdown", Path);
            elsif Filetype = "image/png" or else Filetype = "image/jpeg" then
               return Image_Dimensions_Token (Path, Filetype);
            elsif Filetype = "application/pdf" then
               return Pdf_Page_Count_Token (Path);
            elsif Filetype = "application/zip" then
               return Zip_Entry_Count_Token (Path, "archive.zip");
            elsif Filetype = "application/gzip-tar" then
               return "archive.format|gzip";
            elsif Filetype = "application/vnd.openxmlformats-officedocument.wordprocessingml.document" then
               return Zip_Entry_Count_Token (Path, "office.docx");
            elsif Filetype = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet" then
               return Zip_Entry_Count_Token (Path, "office.xlsx");
            elsif Filetype = "application/x-tar" then
               return "archive.format|tar";
            elsif Filetype = "application/gzip" then
               return "archive.format|gzip";
            elsif Filetype = "audio/mpeg" or else Filetype = "audio/wav" then
               return "media.kind|audio";
            elsif Filetype = "video/mp4" then
               return "media.kind|video";
            end if;
         when others =>
            null;
      end case;

      return "";
   end Extra_Info_Token;

   function Kind_From_Directory_Entry
     (Dir_Entry : Ada.Directories.Directory_Entry_Type)
      return Files.Types.Item_Kind
   is
      Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
   begin
      if Hostkit.Fs.Is_Link (Full) then
         return Files.Types.Symlink_Item;
      end if;

      case Ada.Directories.Kind (Dir_Entry) is
         when Ada.Directories.Directory =>
            return Files.Types.Directory_Item;
         when Ada.Directories.Ordinary_File =>
            if Hostkit.Fs.Is_Executable (Full) then
               return Files.Types.Executable_Item;
            end if;
            return Files.Types.Regular_File_Item;
         when Ada.Directories.Special_File =>
            return Files.Types.Other_Item;
      end case;
   exception
      when others =>
         return Files.Types.Unknown_Item;
   end Kind_From_Directory_Entry;

   --  Build a fully-classified directory item for a single filesystem entry.
   --  Shared by directory loading and single-path stat so both populate size,
   --  timestamps, permissions, ownership, thumbnails, and filetype extras
   --  identically. Metadata failures are captured on the item rather than
   --  raised, matching the per-entry behaviour of directory loading.
   function Item_For_Path
     (Full        : String;
      Name        : String;
      Parent_Path : String;
      Kind        : Files.Types.Item_Kind;
      Settings    : Files.Settings.Settings_Model)
      return Directory_Item
   is
      Filetype : constant String := Files.File_Types.Detect_Filetype (Settings, Kind, Name);
      Icon_Id  : constant String := Files.File_Types.Icon_Id_For (Settings, Kind, Filetype);
      Thumbnail_Cache : constant String := Default_Thumbnail_Cache_Directory (Parent_Path);
      Thumbnail_Path  : constant String := Thumbnail_Path_For (Full, Thumbnail_Cache);
      Thumbnail : constant Cached_Thumbnail :=
        Thumbnail_For_Item
          (Full_Path       => Full,
           Kind            => Kind,
           Filetype        => Filetype,
           Name            => Name,
           Icon_Id         => Icon_Id,
           Cache_Directory => Thumbnail_Cache,
           Thumbnail_Path  => Thumbnail_Path);
      Item : Directory_Item :=
        (Name               => To_Unbounded_String (Name),
         Full_Path          => To_Unbounded_String (Full),
         Parent_Path        => To_Unbounded_String (Parent_Path),
         Kind               => Kind,
         Filetype           => To_Unbounded_String (Filetype),
         Icon_Id            => To_Unbounded_String (Icon_Id),
         Size_Available     => False,
         Size               => 0,
         Creation_Available => False,
         Creation_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
         Modified_Available => False,
         Modified_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
         Permissions        => Null_Unbounded_String,
         Mode_Available     => False,
         Mode_Bits          => 0,
         Ownership_Available => False,
         Owner_Id           => 0,
         Group_Id           => 0,
         Filetype_Extra     => Null_Unbounded_String,
         Thumbnail_Available => False,
         Thumbnail_Path      => Null_Unbounded_String,
         Thumbnail_Width     => 0,
         Thumbnail_Height    => 0,
         Thumbnail_Pixels    => Files.Types.Byte_Vectors.Empty_Vector,
         Metadata_Error     => False,
         Error_Key          => Null_Unbounded_String);
   begin
      --  Filetype_Extra (folder item counts, document page/entry/line counts,
      --  symlink targets) is computed lazily for the selected item when the info
      --  pane needs it -- see Files.Model.Ensure_Selected_Item_Extra -- rather
      --  than here, where it would open every subfolder and read every document
      --  on load, making navigation slow. It stays empty at load time.
      begin
         if Kind /= Files.Types.Directory_Item then
            Item.Size := Long_Long_Integer (Ada.Directories.Size (Full));
            Item.Size_Available := True;
            if Thumbnail.Loaded then
               Item.Thumbnail_Available := True;
               Item.Thumbnail_Path := To_Unbounded_String (Thumbnail_Path);
               Item.Thumbnail_Width := Thumbnail.Width;
               Item.Thumbnail_Height := Thumbnail.Height;
               Item.Thumbnail_Pixels := Thumbnail.Pixels;
            end if;
         end if;
         Item.Creation_Time :=
           Files.Platform.Metadata.File_Creation_Time (Full, Item.Creation_Available);
         Item.Modified_Time := Ada.Directories.Modification_Time (Full);
         Item.Modified_Available := True;
         Item.Permissions := To_Unbounded_String (Permission_String (Full));
         Files.Platform.Metadata.File_Mode_And_Ownership
           (Full,
            Item.Mode_Bits, Item.Mode_Available,
            Item.Owner_Id, Item.Group_Id, Item.Ownership_Available);
      exception
         when others =>
            Item.Metadata_Error := True;
            Item.Error_Key := To_Unbounded_String ("error.metadata.read");
      end;

      return Item;
   end Item_For_Path;

   function Load_Directory
     (Path     : String;
      Settings : Files.Settings.Settings_Model)
      return Directory_Load_Result
   is
      Search : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Items  : Item_Vectors.Vector;
      Normalized_Path : Unbounded_String;
      Started : Boolean := False;
   begin
      if not Files.Fs.Directory_Exists (Path)
      then
         return
           (Success   => False,
            Path      => To_Unbounded_String (Path),
            Items     => Items,
            Error_Key => To_Unbounded_String ("error.directory.load"));
      end if;

      Normalized_Path := To_Unbounded_String (Ada.Directories.Full_Name (Path));

      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
            Ada.Directories.Directory     => True,
            Ada.Directories.Special_File  => True]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         begin
            Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         exception
            when others =>
               --  The enumeration itself failed, not one entry within it -- a file
               --  that vanished mid-scan, typically. There is no way to step past
               --  that and be sure of advancing, so stop and keep what we have: a
               --  directory listed as far as we got beats one that will not open.
               exit;
         end;

         --  An entry we cannot even name is skipped, not fatal. Naming it sits
         --  outside the guard below, so it used to fall through to the handler at
         --  the bottom and fail the whole load -- which is why C:\ loaded only when
         --  nothing in it happened to be unreadable at that moment.
         begin
            declare
               Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
            begin
               if Name /= "."
                 and then Name /= ".."
                 and then (Settings.Show_Hidden_Files or else Name (Name'First) /= '.')
               then
                  --  One entry we cannot inspect must not cost us the directory. It
                  --  used to: anything raised here fell through to the handler below
                  --  and the whole load failed, so a single locked entry made the
                  --  directory unopenable. On Linux you rarely meet one; C:\ has
                  --  several -- System Volume Information, pagefile.sys, DumpStack.log
                  --  -- so the drive root, the one directory a Windows user starts
                  --  from, could not be listed at all.
                  --
                  --  An entry whose kind we cannot read is still an entry the user can
                  --  see, so keep it and say only what we know, rather than hiding it.
                  begin
                     declare
                        Full : constant String := Ada.Directories.Full_Name (Dir_Entry);
                        Kind : constant Files.Types.Item_Kind := Kind_From_Directory_Entry (Dir_Entry);
                     begin
                        Items.Append
                          (Item_For_Path (Full, Name, To_String (Normalized_Path), Kind, Settings));
                     end;
                  exception
                     when others =>
                        begin
                           Items.Append
                             (Item_For_Path
                                (Join_Path (To_String (Normalized_Path), Name),
                                 Name,
                                 To_String (Normalized_Path),
                                 Files.Types.Other_Item,
                                 Settings));
                        exception
                           when others =>
                              null;
                        end;
                  end;
               end if;
            end;
            exception
               when others =>
                  null;
         end;
      end loop;

         Safe_End_Search (Search, Started);

         Sort_Items (Items, Settings.Sort_Field_Value, Settings.Sort_Ascending);

         return
           (Success   => True,
            Path      => Normalized_Path,
            Items     => Items,
            Error_Key => Null_Unbounded_String);
      exception
         when others =>
            Safe_End_Search (Search, Started);
            return
              (Success   => False,
               Path      => To_Unbounded_String (Path),
               Items     => Items,
               Error_Key => To_Unbounded_String ("error.directory.load"));
   end Load_Directory;

   function Load_Item
     (Full_Path : String;
      Settings  : Files.Settings.Settings_Model)
      return Item_Load_Result
   is
      Empty : Directory_Item;
   begin
      if Full_Path = "" or else not Ada.Directories.Exists (Full_Path) then
         return
           (Success   => False,
            Item      => Empty,
            Error_Key => To_Unbounded_String ("error.path.missing"));
      end if;

      declare
         Full   : constant String := Ada.Directories.Full_Name (Full_Path);
         Name   : constant String := Ada.Directories.Simple_Name (Full);
         Parent : constant String := Ada.Directories.Containing_Directory (Full);
         Kind   : Files.Types.Item_Kind;
      begin
         if Hostkit.Fs.Is_Link (Full) then
            Kind := Files.Types.Symlink_Item;
         else
            case Ada.Directories.Kind (Full) is
               when Ada.Directories.Directory =>
                  Kind := Files.Types.Directory_Item;
               when Ada.Directories.Ordinary_File =>
                  if Hostkit.Fs.Is_Executable (Full) then
                     Kind := Files.Types.Executable_Item;
                  else
                     Kind := Files.Types.Regular_File_Item;
                  end if;
               when Ada.Directories.Special_File =>
                  Kind := Files.Types.Other_Item;
            end case;
         end if;

         return
           (Success   => True,
            Item      => Item_For_Path (Full, Name, Parent, Kind, Settings),
            Error_Key => Null_Unbounded_String);
      end;
   exception
      when others =>
         return
           (Success   => False,
            Item      => Empty,
            Error_Key => To_Unbounded_String ("error.path.inaccessible"));
   end Load_Item;

   --  The search operations now live in the
   --  Files.File_System.Search child; these renamings keep them on the public API.
   function Search_Recursive
     (Root_Path : String;
      Query     : String;
      Settings  : Files.Settings.Settings_Model;
      Max_Items : Natural := 1_000)
      return Recursive_Search_Result
     renames Files.File_System.Search.Search_Recursive;

   function Directory_State
     (Path : String)
      return Directory_Signature
   is
      Search    : Ada.Directories.Search_Type;
      Dir_Entry : Ada.Directories.Directory_Entry_Type;
      Started   : Boolean := False;
      Result    : Directory_Signature :=
        (Path                  => To_Unbounded_String (Path),
         Exists                => False,
         Entry_Count           => 0,
         Entry_State_Checksum  => 0,
         Latest_Modified       => Ada.Calendar.Time_Of (1901, 1, 1),
         Latest_Modified_Known => False);

      function Entry_Checksum
        (Name : String;
         Kind : Ada.Directories.File_Kind;
         Size : Long_Long_Integer)
         return Natural
      is
         Modulus : constant Long_Long_Integer := 1_000_000_007;
         Value   : Long_Long_Integer := Long_Long_Integer (Ada.Directories.File_Kind'Pos (Kind) + 1);
      begin
         for Character_Value of Name loop
            Value :=
              (Value * 131 + Long_Long_Integer (Character'Pos (Character_Value))) mod Modulus;
         end loop;

         Value := (Value * 131 + Long_Long_Integer'Max (0, Size)) mod Modulus;
         return Natural (Value);
      end Entry_Checksum;
   begin
      if not Files.Fs.Directory_Exists (Path)
      then
         return Result;
      end if;

      Result.Path := To_Unbounded_String (Ada.Directories.Full_Name (Path));
      Result.Exists := True;
      Ada.Directories.Start_Search
        (Search,
         Directory => Path,
         Pattern   => "*",
         Filter    =>
           [Ada.Directories.Ordinary_File => True,
            Ada.Directories.Directory     => True,
            Ada.Directories.Special_File  => True]);
      Started := True;

      while Ada.Directories.More_Entries (Search) loop
         Ada.Directories.Get_Next_Entry (Search, Dir_Entry);
         declare
            Name : constant String := Ada.Directories.Simple_Name (Dir_Entry);
         begin
            if Name /= "." and then Name /= ".." then
               Result.Entry_Count := Result.Entry_Count + 1;
               declare
                  Full     : constant String := Ada.Directories.Full_Name (Dir_Entry);
                  Kind     : Ada.Directories.File_Kind := Ada.Directories.Special_File;
                  Size     : Long_Long_Integer := 0;
                  Modified : Ada.Calendar.Time := Ada.Calendar.Time_Of (1901, 1, 1);
               begin
                  begin
                     Kind := Ada.Directories.Kind (Dir_Entry);
                  exception
                     when others =>
                        null;
                  end;

                  if Kind = Ada.Directories.Ordinary_File then
                     begin
                        Size := Long_Long_Integer (Ada.Directories.Size (Full));
                     exception
                        when others =>
                           Size := 0;
                     end;
                  end if;

                  Result.Entry_State_Checksum :=
                    (Result.Entry_State_Checksum + Entry_Checksum (Name, Kind, Size)) mod 1_000_000_007;

                  begin
                     Modified := Ada.Directories.Modification_Time (Full);
                     if not Result.Latest_Modified_Known
                       or else Modified > Result.Latest_Modified
                     then
                        Result.Latest_Modified := Modified;
                        Result.Latest_Modified_Known := True;
                     end if;
                  exception
                     when others =>
                        null;
                  end;
               exception
                  when others =>
                     Result.Entry_State_Checksum :=
                       (Result.Entry_State_Checksum
                        + Entry_Checksum (Name, Ada.Directories.Special_File, 0)) mod 1_000_000_007;
               end;
            end if;
         end;
      end loop;

      Safe_End_Search (Search, Started);
      return Result;
   exception
      when others =>
         Safe_End_Search (Search, Started);
         return Result;
   end Directory_State;

   function Detect_Directory_Change
     (Before_State : Directory_Signature;
      Path         : String)
      return Directory_Change_Result
   is
      After_State : constant Directory_Signature := Directory_State (Path);
      Changed     : constant Boolean :=
        Before_State.Exists /= After_State.Exists
        or else Before_State.Entry_Count /= After_State.Entry_Count
        or else Before_State.Entry_State_Checksum /= After_State.Entry_State_Checksum
        or else Before_State.Latest_Modified_Known /= After_State.Latest_Modified_Known
        or else
          (Before_State.Latest_Modified_Known
           and then After_State.Latest_Modified_Known
           and then Before_State.Latest_Modified /= After_State.Latest_Modified);
   begin
      return
        (Changed      => Changed,
         Before_State => Before_State,
         After_State  => After_State,
         Error_Key    =>
           (if After_State.Exists then Null_Unbounded_String else To_Unbounded_String ("error.directory.load")));
   end Detect_Directory_Change;

   --  The roots operations now live in the
   --  Files.File_System.Roots child; these renamings keep them on the public API.
   function Available_Roots return Files.Types.String_Vectors.Vector
     renames Files.File_System.Roots.Available_Roots;

   function Available_Root_Entries return Root_Entry_Vectors.Vector
     renames Files.File_System.Roots.Available_Root_Entries;

   function Root_Label (Path : String; Kind : Root_Kind) return String
     renames Files.File_System.Roots.Root_Label;

   function Root_Discovery_Status return Root_Discovery_Diagnostics
     renames Files.File_System.Roots.Root_Discovery_Status;

   function Root_Volume_Capabilities_Of_Current_Environment
      return Root_Volume_Capabilities
     renames Files.File_System.Roots.Root_Volume_Capabilities_Of_Current_Environment;

   function Filesystem_Edge_Case_Profile_Of_Current_Environment
      return Filesystem_Edge_Case_Profile
     renames Files.File_System.Roots.Filesystem_Edge_Case_Profile_Of_Current_Environment;

   function Native_Platform_API_Profile_For
     (Adapter : Native_Platform_Adapter)
      return Native_Platform_API_Profile
     renames Files.File_System.Roots.Native_Platform_API_Profile_For;

   function Root_Volume_Details_For
     (Root : Root_Entry)
      return Root_Volume_Details
     renames Files.File_System.Roots.Root_Volume_Details_For;

   function Filetype_Metadata_Policy_Of_Current_Implementation
      return Filetype_Metadata_Policy
     renames Files.File_System.Roots.Filetype_Metadata_Policy_Of_Current_Implementation;

   function Make_Item
     (Parent_Path : String;
      Name        : String;
      Kind        : Files.Types.Item_Kind;
      Filetype    : String := "")
      return Directory_Item
   is
      Settings  : constant Files.Settings.Settings_Model := Files.Settings.Default_Settings;
      Type_Name : constant String :=
        (if Filetype /= "" then Filetype else Files.File_Types.Detect_Filetype (Settings, Kind, Name));
   begin
      return
        (Name               => To_Unbounded_String (Name),
         Full_Path          => To_Unbounded_String (Join_Path (Parent_Path, Name)),
         Parent_Path        => To_Unbounded_String (Parent_Path),
         Kind               => Kind,
         Filetype           => To_Unbounded_String (Type_Name),
         Icon_Id            => To_Unbounded_String (Files.File_Types.Icon_Id_For (Settings, Kind, Type_Name)),
         Size_Available     => False,
         Size               => 0,
         Creation_Available => False,
         Creation_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
         Modified_Available => False,
         Modified_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
         Permissions        => Null_Unbounded_String,
         Mode_Available     => False,
         Mode_Bits          => 0,
         Ownership_Available => False,
         Owner_Id           => 0,
         Group_Id           => 0,
         Filetype_Extra     => Null_Unbounded_String,
         Thumbnail_Available => False,
         Thumbnail_Path      => Null_Unbounded_String,
         Thumbnail_Width     => 0,
         Thumbnail_Height    => 0,
         Thumbnail_Pixels    => Files.Types.Byte_Vectors.Empty_Vector,
         Metadata_Error     => False,
         Error_Key          => Null_Unbounded_String);
   end Make_Item;

   function Make_Item
     (Parent_Path : String;
      Name        : String;
      Kind        : Files.Types.Item_Kind;
      Settings    : Files.Settings.Settings_Model)
      return Directory_Item
   is
      Filetype : constant String := Files.File_Types.Detect_Filetype (Settings, Kind, Name);
   begin
      return
        (Name               => To_Unbounded_String (Name),
         Full_Path          => To_Unbounded_String (Join_Path (Parent_Path, Name)),
         Parent_Path        => To_Unbounded_String (Parent_Path),
         Kind               => Kind,
         Filetype           => To_Unbounded_String (Filetype),
         Icon_Id            => To_Unbounded_String (Files.File_Types.Icon_Id_For (Settings, Kind, Filetype)),
         Size_Available     => False,
         Size               => 0,
         Creation_Available => False,
         Creation_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
         Modified_Available => False,
         Modified_Time      => Ada.Calendar.Time_Of (1901, 1, 1),
         Permissions        => Null_Unbounded_String,
         Mode_Available     => False,
         Mode_Bits          => 0,
         Ownership_Available => False,
         Owner_Id           => 0,
         Group_Id           => 0,
         Filetype_Extra     => Null_Unbounded_String,
         Thumbnail_Available => False,
         Thumbnail_Path      => Null_Unbounded_String,
         Thumbnail_Width     => 0,
         Thumbnail_Height    => 0,
         Thumbnail_Pixels    => Files.Types.Byte_Vectors.Empty_Vector,
         Metadata_Error     => False,
         Error_Key          => Null_Unbounded_String);
   end Make_Item;

   --  The create operations now live in the
   --  Files.File_System.Create child; these renamings keep them on the public API.
   function Create_Empty_File
     (Path : String)
      return Mutation_Result
     renames Files.File_System.Create.Create_Empty_File;

   function Create_Directory
     (Path : String)
      return Mutation_Result
     renames Files.File_System.Create.Create_Directory;

   function Rename_Item
     (From_Path : String;
      To_Path   : String)
      return Mutation_Result
     renames Files.File_System.Create.Rename_Item;

   function Create_Symbolic_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result
     renames Files.File_System.Create.Create_Symbolic_Link;

   function Create_Hard_Link
     (Source_Path : String;
      Link_Path   : String)
      return Mutation_Result
     renames Files.File_System.Create.Create_Hard_Link;

   --  The permissions operations now live in the
   --  Files.File_System.Permissions child; these renamings keep them on the public API.
   function Supports_Permissions return Boolean
     renames Files.File_System.Permissions.Supports_Permissions;

   function Permission_Bits_Of
     (Path      : String;
      Available : out Boolean)
      return Natural
     renames Files.File_System.Permissions.Permission_Bits_Of;

   function Set_Permissions
     (Path : String;
      Mode : Natural)
      return Mutation_Result
     renames Files.File_System.Permissions.Set_Permissions;

   function Supports_Ownership return Boolean
     renames Files.File_System.Permissions.Supports_Ownership;

   procedure Ownership_Of
     (Path      : String;
      User_Id   : out Natural;
      Group_Id  : out Natural;
      Available : out Boolean)
     renames Files.File_System.Permissions.Ownership_Of;

   function Set_Ownership
     (Path     : String;
      User_Id  : Natural;
      Group_Id : Natural)
      return Mutation_Result
     renames Files.File_System.Permissions.Set_Ownership;

   function User_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural
     renames Files.File_System.Permissions.User_Id_For_Name;

   function Group_Id_For_Name
     (Name  : String;
      Found : out Boolean)
      return Natural
     renames Files.File_System.Permissions.Group_Id_For_Name;

   function User_Name_For_Id (Id : Natural) return String
     renames Files.File_System.Permissions.User_Name_For_Id;

   function Group_Name_For_Id (Id : Natural) return String
     renames Files.File_System.Permissions.Group_Name_For_Id;

   function Directory_Size
     (Path        : String;
      Max_Entries : Natural := 50_000;
      Max_Depth   : Natural := 64)
      return Directory_Size_Result
   is
      Result  : Directory_Size_Result;
      Visited : Natural := 0;

      function Saturating_Long_Add
        (Left  : Long_Long_Integer;
         Right : Long_Long_Integer)
         return Long_Long_Integer is
      begin
         if Right > 0 and then Left > Long_Long_Integer'Last - Right then
            return Long_Long_Integer'Last;
         else
            return Left + Right;
         end if;
      end Saturating_Long_Add;

      function Is_Symlink (Candidate : String) return Boolean is
      begin
         return Files.Platform.Metadata.Symlink_Target_Token (Candidate) /= "";
      exception
         when others =>
            return False;
      end Is_Symlink;

      procedure Walk (Directory : String; Depth : Natural) is
         Search : Ada.Directories.Search_Type;
         Item   : Ada.Directories.Directory_Entry_Type;
      begin
         if Depth > Max_Depth then
            Result.Capped := True;
            return;
         end if;

         Ada.Directories.Start_Search
           (Search    => Search,
            Directory => Directory,
            Pattern   => "",
            Filter    =>
              [Ada.Directories.Ordinary_File => True,
               Ada.Directories.Directory     => True,
               Ada.Directories.Special_File  => True]);

         while Ada.Directories.More_Entries (Search) loop
            Ada.Directories.Get_Next_Entry (Search, Item);
            declare
               Name : constant String := Ada.Directories.Simple_Name (Item);
               Full : constant String := Ada.Directories.Full_Name (Item);
            begin
               if Name /= "." and then Name /= ".." then
                  Visited := Visited + 1;
                  if Visited > Max_Entries then
                     Result.Capped := True;
                     Ada.Directories.End_Search (Search);
                     return;
                  end if;

                  Result.Item_Count := Result.Item_Count + 1;

                  if Is_Symlink (Full) then
                     null;
                  elsif Ada.Directories.Kind (Item) = Ada.Directories.Directory then
                     Walk (Full, Depth + 1);
                     exit when Result.Capped;
                  elsif Ada.Directories.Kind (Item) = Ada.Directories.Ordinary_File then
                     Result.File_Count := Result.File_Count + 1;
                     Result.Total_Bytes :=
                       Saturating_Long_Add
                         (Result.Total_Bytes,
                          Long_Long_Integer (Ada.Directories.Size (Item)));
                  end if;
               end if;
            exception
               when others =>
                  --  Skip individual entries that cannot be classified or sized
                  --  (races, permission denials) without aborting the walk.
                  null;
            end;
         end loop;

         Ada.Directories.End_Search (Search);
      exception
         when others =>
            --  An unreadable subdirectory is skipped rather than failing the
            --  whole measurement.
            null;
      end Walk;
   begin
      if Path = ""
        or else not Ada.Directories.Exists (Path)
        or else Ada.Directories.Kind (Path) /= Ada.Directories.Directory
      then
         return Result;
      end if;

      Walk (Path, 0);
      Result.Available := True;
      return Result;
   exception
      when others =>
         return Result;
   end Directory_Size;

   --  The copy move operations now live in the
   --  Files.File_System.Copy_Move child; these renamings keep them on the public API.
   function Copy_Tree
     (Source_Path      : String;
      Destination_Path : String)
      return Mutation_Result
     renames Files.File_System.Copy_Move.Copy_Tree;

   function Delete_Permanently
     (Path : String)
      return Mutation_Result
     renames Files.File_System.Copy_Move.Delete_Permanently;

   function Plan_Drop_Import
     (Source_Paths          : Files.Types.String_Vectors.Vector;
      Destination_Directory : String;
      Mode                  : Drop_Import_Mode := Drop_Copy)
      return Drop_Import_Result
     renames Files.File_System.Copy_Move.Plan_Drop_Import;

   function Execute_Drop_Import
     (Plans : Drop_Import_Plan_Vectors.Vector)
      return Mutation_Result
     renames Files.File_System.Copy_Move.Execute_Drop_Import;

   function Decode_Image_To_Pixels
     (Path     : String;
      Max_Size : Positive)
      return Decoded_Image
   is
      type Gdk_Pixel_Array is array (Natural range 0 .. 67_108_863) of aliased Interfaces.Unsigned_8;
      pragma Convention (C, Gdk_Pixel_Array);
      package Gdk_Pixel_Pointers is new System.Address_To_Access_Conversions (Gdk_Pixel_Array);
      use type Gdk_Pixel_Pointers.Object_Pointer;

      C_Path : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Path);
      Pixbuf : System.Address := System.Null_Address;
      Result : Decoded_Image;
   begin
      Pixbuf :=
        Gdk_Pixbuf_New_From_File_At_Size
          (Filename => C_Path,
           Width    => C_Int (Max_Size),
           Height   => C_Int (Max_Size),
           Error    => System.Null_Address);
      Interfaces.C.Strings.Free (C_Path);

      if Pixbuf = System.Null_Address then
         return Result;
      end if;

      declare
         Width     : constant Natural := Natural (Gdk_Pixbuf_Get_Width (Pixbuf));
         Height    : constant Natural := Natural (Gdk_Pixbuf_Get_Height (Pixbuf));
         Channels  : constant Natural := Natural (Gdk_Pixbuf_Get_N_Channels (Pixbuf));
         Rowstride : constant Natural := Natural (Gdk_Pixbuf_Get_Rowstride (Pixbuf));
         Pixels_Address : constant System.Address := Gdk_Pixbuf_Get_Pixels (Pixbuf);
         Raw       : constant Gdk_Pixel_Pointers.Object_Pointer :=
           Gdk_Pixel_Pointers.To_Pointer (Pixels_Address);
      begin
         if Width = 0
           or else Height = 0
           or else Width > Max_Size
           or else Height > Max_Size
           or else Channels < 3
           or else Rowstride < Width * Channels
           or else Pixels_Address = System.Null_Address
           or else Raw = null
         then
            G_Object_Unref (Pixbuf);
            return Result;
         end if;

         --  Copy row-major RGBA (alpha from the source or opaque when absent),
         --  matching the byte layout the icon-atlas thumbnail rasterizer reads.
         for Row in 0 .. Height - 1 loop
            for Column in 0 .. Width - 1 loop
               declare
                  Offset : constant Natural := Row * Rowstride + Column * Channels;
               begin
                  Result.Pixels.Append (Raw.all (Offset));
                  Result.Pixels.Append (Raw.all (Offset + 1));
                  Result.Pixels.Append (Raw.all (Offset + 2));
                  Result.Pixels.Append (if Channels >= 4 then Raw.all (Offset + 3) else 255);
               end;
            end loop;
         end loop;

         G_Object_Unref (Pixbuf);
         Result.Available := True;
         Result.Width := Width;
         Result.Height := Height;
         return Result;
      end;
   exception
      when others =>
         Safe_Free (C_Path);
         if Pixbuf /= System.Null_Address then
            G_Object_Unref (Pixbuf);
         end if;
         return (Available => False, Width => 0, Height => 0,
                 Pixels => Files.Types.Byte_Vectors.Empty_Vector);
   end Decode_Image_To_Pixels;

   function Generate_Thumbnail
     (Source_Path      : String;
      Cache_Directory : String;
      Size            : Positive := 64)
      return Thumbnail_Result
   is
      File : Ada.Text_IO.File_Type;

      function Clamp_Channel (Value : Natural) return Natural is
      begin
         return Value mod 256;
      end Clamp_Channel;

      function File_Size_Signal return Natural is
      begin
         return Natural (Long_Long_Integer'Min (Long_Long_Integer (Ada.Directories.Size (Source_Path)), 65_535));
      exception
         when others =>
            return 0;
      end File_Size_Signal;

      type Rgb_Pixel is record
         Red   : Natural := 0;
         Green : Natural := 0;
         Blue  : Natural := 0;
      end record;

      package Pixel_Vectors is new Ada.Containers.Vectors
        (Index_Type   => Natural,
         Element_Type => Rgb_Pixel);

      package Thumbnail_Byte_Vectors is new Ada.Containers.Vectors
        (Index_Type   => Natural,
         Element_Type => Ada.Streams.Stream_Element);

      type Gdk_Pixel_Array is array (Natural range 0 .. 67_108_863) of aliased Interfaces.Unsigned_8;
      pragma Convention (C, Gdk_Pixel_Array);

      package Gdk_Pixel_Pointers is new System.Address_To_Access_Conversions (Gdk_Pixel_Array);
      use type Gdk_Pixel_Pointers.Object_Pointer;

      function Byte_At
        (Data  : Thumbnail_Byte_Vectors.Vector;
         Index : Natural)
         return Natural is
      begin
         if Index >= Natural (Data.Length) then
            return 0;
         end if;

         return Natural (Data.Element (Index));
      end Byte_At;

      function U32_BE_From
        (Data  : Thumbnail_Byte_Vectors.Vector;
         Index : Natural)
         return Natural is
      begin
         return
           Byte_At (Data, Index) * 16#1000000#
           + Byte_At (Data, Index + 1) * 16#10000#
           + Byte_At (Data, Index + 2) * 16#100#
           + Byte_At (Data, Index + 3);
      end U32_BE_From;

      function Bytes_To_Stream_Array
        (Data : Thumbnail_Byte_Vectors.Vector)
         return Ada.Streams.Stream_Element_Array
      is
         Result : Ada.Streams.Stream_Element_Array (0 .. Ada.Streams.Stream_Element_Offset (Data.Length) - 1);
      begin
         for Index in 0 .. Natural (Data.Length) - 1 loop
            Result (Ada.Streams.Stream_Element_Offset (Index)) := Data.Element (Index);
         end loop;

         return Result;
      end Bytes_To_Stream_Array;

      procedure Write_Pixels_As_Ppm
        (Target_Path   : String;
         Pixels        : Pixel_Vectors.Vector;
         Source_Width  : Natural;
         Source_Height : Natural)
      is
         Output : Ada.Text_IO.File_Type;
      begin
         Ada.Text_IO.Create (Output, Ada.Text_IO.Out_File, Target_Path);
         Ada.Text_IO.Put_Line (Output, "P3");
         Ada.Text_IO.Put_Line (Output, Image_No_Space (Size) & " " & Image_No_Space (Size));
         Ada.Text_IO.Put_Line (Output, "255");
         for Row in 0 .. Size - 1 loop
            for Column in 0 .. Size - 1 loop
               declare
                  Source_Row    : constant Natural := Row * Source_Height / Size;
                  Source_Column : constant Natural := Column * Source_Width / Size;
                  Source_Index  : constant Natural := Source_Row * Source_Width + Source_Column;
                  Pixel         : constant Rgb_Pixel := Pixels.Element (Source_Index);
               begin
                  Ada.Text_IO.Put
                    (Output,
                     Image_No_Space (Pixel.Red) & " "
                     & Image_No_Space (Pixel.Green) & " "
                     & Image_No_Space (Pixel.Blue));
                  if Column < Size - 1 then
                     Ada.Text_IO.Put (Output, " ");
                  end if;
               end;
            end loop;
            Ada.Text_IO.New_Line (Output);
         end loop;
         Ada.Text_IO.Close (Output);
      exception
         when others =>
            Safe_Close (Output);
            raise;
      end Write_Pixels_As_Ppm;

      function Try_Write_Decoded_P3_Thumbnail
        (Target_Path : String)
         return Boolean
      is
         Input  : Ada.Text_IO.File_Type;
         Token  : Unbounded_String;
         Content : Unbounded_String;
         Scan_Index : Positive := 1;
         Pixels : Pixel_Vectors.Vector;
         Source_Width  : Natural := 0;
         Source_Height : Natural := 0;
         Max_Value     : Natural := 0;

         function Next_Token return Boolean is
            Value : Character;
         begin
            Token := Null_Unbounded_String;
            while Scan_Index <= Length (Content) loop
               Value := Element (Content, Scan_Index);
               Scan_Index := Scan_Index + 1;
               if Value = ' ' or else Value = ASCII.HT or else Value = ASCII.LF or else Value = ASCII.CR then
                  if Length (Token) > 0 then
                     return True;
                  end if;
               else
                  Append (Token, Value);
               end if;
            end loop;

            return Length (Token) > 0;
         end Next_Token;

         function Next_Natural
           (Value : out Natural)
            return Boolean is
         begin
            if not Next_Token then
               return False;
            end if;

            Value := Natural'Value (To_String (Token));
            return True;
         exception
            when others =>
               return False;
         end Next_Natural;

         function Scaled_Channel
           (Value : Natural)
            return Natural is
         begin
            if Max_Value = 0 then
               return 0;
            elsif Max_Value = 255 then
               return Natural'Min (Value, 255);
            end if;

            return Natural'Min ((Value * 255) / Max_Value, 255);
         end Scaled_Channel;
      begin
         Ada.Text_IO.Open (Input, Ada.Text_IO.In_File, Source_Path);
         while not Ada.Text_IO.End_Of_File (Input) loop
            declare
               Buffer  : String (1 .. 4096);
               Last    : Natural;
               Comment : Natural := 0;
            begin
               Ada.Text_IO.Get_Line (Input, Buffer, Last);
               for Index in 1 .. Last loop
                  if Buffer (Index) = '#' then
                     Comment := Index;
                     exit;
                  end if;
               end loop;

               if Last = 0 then
                  null;
               elsif Comment = 0 then
                  Append (Content, Buffer (1 .. Last));
               elsif Comment > 1 then
                  Append (Content, Buffer (1 .. Comment - 1));
               end if;
               Append (Content, ' ');
            end;
         end loop;
         Ada.Text_IO.Close (Input);

         if not Next_Token or else To_String (Token) /= "P3" then
            return False;
         end if;

         if not Next_Natural (Source_Width)
           or else not Next_Natural (Source_Height)
           or else not Next_Natural (Max_Value)
           or else Source_Width = 0
           or else Source_Height = 0
           or else Max_Value = 0
           or else Source_Width > 4096
           or else Source_Height > 4096
           or else Source_Width * Source_Height > 4_194_304
         then
            return False;
         end if;

         for Pixel_Index in 1 .. Source_Width * Source_Height loop
            declare
               Red   : Natural;
               Green : Natural;
               Blue  : Natural;
            begin
               if not Next_Natural (Red) or else not Next_Natural (Green) or else not Next_Natural (Blue) then
                  return False;
               end if;

               Pixels.Append
                 (New_Item =>
                    Rgb_Pixel'
                      (Red   => Scaled_Channel (Red),
                       Green => Scaled_Channel (Green),
                       Blue  => Scaled_Channel (Blue)));
            end;
         end loop;

         Write_Pixels_As_Ppm (Target_Path, Pixels, Source_Width, Source_Height);
         return True;
      exception
         when others =>
            Safe_Close (Input);
            return False;
      end Try_Write_Decoded_P3_Thumbnail;

      function Try_Write_Decoded_Png_Thumbnail
        (Target_Path : String)
         return Boolean
      is
         File   : Ada.Streams.Stream_IO.File_Type;
         Buffer : Ada.Streams.Stream_Element_Array (1 .. 4096);
         Last   : Ada.Streams.Stream_Element_Offset;
         Bytes  : Thumbnail_Byte_Vectors.Vector;
         Idat   : Thumbnail_Byte_Vectors.Vector;
         Width  : Natural := 0;
         Height : Natural := 0;
         Bit_Depth  : Natural := 0;
         Color_Type : Natural := 0;
         Interlace  : Natural := 0;
         Position   : Natural := 8;
         Channels   : Natural := 0;
         Pixels     : Pixel_Vectors.Vector;

         function Is_Png_Signature return Boolean is
         begin
            return Natural (Bytes.Length) >= 8
              and then Byte_At (Bytes, 0) = 16#89#
              and then Byte_At (Bytes, 1) = Character'Pos ('P')
              and then Byte_At (Bytes, 2) = Character'Pos ('N')
              and then Byte_At (Bytes, 3) = Character'Pos ('G')
              and then Byte_At (Bytes, 4) = 16#0D#
              and then Byte_At (Bytes, 5) = 16#0A#
              and then Byte_At (Bytes, 6) = 16#1A#
              and then Byte_At (Bytes, 7) = 16#0A#;
         end Is_Png_Signature;

         function Chunk_Type
           (Index : Natural)
            return String is
         begin
            return
              Character'Val (Byte_At (Bytes, Index))
              & Character'Val (Byte_At (Bytes, Index + 1))
              & Character'Val (Byte_At (Bytes, Index + 2))
              & Character'Val (Byte_At (Bytes, Index + 3));
         end Chunk_Type;

         function Raw_Byte
           (Data  : Ada.Streams.Stream_Element_Array;
            Index : Natural)
            return Natural is
         begin
            if Ada.Streams.Stream_Element_Offset (Index) not in Data'Range then
               return 0;
            end if;

            return Natural (Data (Ada.Streams.Stream_Element_Offset (Index)));
         end Raw_Byte;

         function Paeth
           (Left  : Natural;
            Up    : Natural;
            Upper : Natural)
            return Natural
         is
            P  : constant Integer := Integer (Left) + Integer (Up) - Integer (Upper);
            PA : constant Natural := Natural (abs (P - Integer (Left)));
            PB : constant Natural := Natural (abs (P - Integer (Up)));
            PC : constant Natural := Natural (abs (P - Integer (Upper)));
         begin
            if PA <= PB and then PA <= PC then
               return Left;
            elsif PB <= PC then
               return Up;
            else
               return Upper;
            end if;
         end Paeth;
      begin
         Ada.Streams.Stream_IO.Open (File, Ada.Streams.Stream_IO.In_File, Source_Path);
         while not Ada.Streams.Stream_IO.End_Of_File (File) loop
            Ada.Streams.Stream_IO.Read (File, Buffer, Last);
            for Index in 1 .. Last loop
               Bytes.Append (Buffer (Index));
            end loop;
         end loop;
         Ada.Streams.Stream_IO.Close (File);

         if not Is_Png_Signature then
            return False;
         end if;

         while Position + 12 <= Natural (Bytes.Length) loop
            declare
               Length_Value : constant Natural := U32_BE_From (Bytes, Position);
               Kind         : constant String := Chunk_Type (Position + 4);
               Data_Start   : constant Natural := Position + 8;
               Data_Last    : constant Natural := Data_Start + Length_Value - 1;
            begin
               if Data_Start + Length_Value + 4 > Natural (Bytes.Length) then
                  return False;
               end if;

               if Kind = "IHDR" then
                  if Length_Value < 13 then
                     return False;
                  end if;
                  Width := U32_BE_From (Bytes, Data_Start);
                  Height := U32_BE_From (Bytes, Data_Start + 4);
                  Bit_Depth := Byte_At (Bytes, Data_Start + 8);
                  Color_Type := Byte_At (Bytes, Data_Start + 9);
                  Interlace := Byte_At (Bytes, Data_Start + 12);
               elsif Kind = "IDAT" then
                  if Length_Value > 0 then
                     for Index in Data_Start .. Data_Last loop
                        Idat.Append (Bytes.Element (Index));
                     end loop;
                  end if;
               elsif Kind = "IEND" then
                  exit;
               end if;

               Position := Data_Start + Length_Value + 4;
            end;
         end loop;

         if Width = 0
           or else Height = 0
           or else Width > 4096
           or else Height > 4096
           or else Width * Height > 4_194_304
           or else Bit_Depth /= 8
           or else Interlace /= 0
           or else Idat.Is_Empty
         then
            --  Adam7-interlaced PNGs have a different IDAT layout than the
            --  single raster this decoder assumes; defer to the gdk-pixbuf
            --  fallback rather than producing a garbled thumbnail.
            return False;
         elsif Color_Type = 2 then
            Channels := 3;
         elsif Color_Type = 6 then
            Channels := 4;
         else
            return False;
         end if;

         declare
            Row_Stride : constant Natural := Width * Channels;
            Needed     : constant Natural := Height * (Row_Stride + 1);
            Compressed : constant Ada.Streams.Stream_Element_Array := Bytes_To_Stream_Array (Idat);
            Source     : Zlib.Byte_Array (0 .. Natural (Compressed'Length) - 1);
            Inflated   : Ada.Streams.Stream_Element_Array (0 .. Ada.Streams.Stream_Element_Offset (Needed - 1)) :=
              [others => 0];
            Decode_Status : Zlib.Status_Code := Zlib.Ok;
            Previous   : Ada.Streams.Stream_Element_Array (0 .. Ada.Streams.Stream_Element_Offset (Row_Stride - 1)) :=
              [others => 0];
            Current    : Ada.Streams.Stream_Element_Array (0 .. Ada.Streams.Stream_Element_Offset (Row_Stride - 1)) :=
              [others => 0];
         begin
            for I in Source'Range loop
               Source (I) :=
                 Zlib.Byte (Compressed (Compressed'First + Ada.Streams.Stream_Element_Offset (I)));
            end loop;
            --  Inflate the zlib-wrapped PNG IDAT stream with the pure-Ada zlib
            --  crate (no system libz dependency).
            declare
               use type Zlib.Status_Code;
               Raw_Inflated : constant Zlib.Byte_Array :=
                 Zlib.Inflate_With_Header (Source, Zlib.Zlib_Header, Decode_Status);
            begin
               if Decode_Status /= Zlib.Ok or else Raw_Inflated'Length < Needed then
                  return False;
               end if;
               for I in 0 .. Needed - 1 loop
                  Inflated (Ada.Streams.Stream_Element_Offset (I)) :=
                    Ada.Streams.Stream_Element (Raw_Inflated (Raw_Inflated'First + I));
               end loop;
            end;

            for Row in 0 .. Height - 1 loop
               declare
                  Filter : constant Natural := Raw_Byte (Inflated, Row * (Row_Stride + 1));
                  Base   : constant Natural := Row * (Row_Stride + 1) + 1;
               begin
                  if Filter > 4 then
                     return False;
                  end if;

                  for Column in 0 .. Row_Stride - 1 loop
                     declare
                        Raw   : constant Natural := Raw_Byte (Inflated, Base + Column);
                        Left  : constant Natural :=
                          (if Column >= Channels
                           then Natural (Current (Ada.Streams.Stream_Element_Offset (Column - Channels)))
                           else 0);
                        Up    : constant Natural :=
                          Natural (Previous (Ada.Streams.Stream_Element_Offset (Column)));
                        Upper : constant Natural :=
                          (if Column >= Channels
                           then Natural (Previous (Ada.Streams.Stream_Element_Offset (Column - Channels)))
                           else 0);
                        Value : Natural := Raw;
                     begin
                        case Filter is
                           when 0 =>
                              null;
                           when 1 =>
                              Value := Raw + Left;
                           when 2 =>
                              Value := Raw + Up;
                           when 3 =>
                              Value := Raw + (Left + Up) / 2;
                           when 4 =>
                              Value := Raw + Paeth (Left, Up, Upper);
                           when others =>
                              null;
                        end case;
                        Current (Ada.Streams.Stream_Element_Offset (Column)) :=
                          Ada.Streams.Stream_Element (Value mod 256);
                     end;
                  end loop;

                  for Column in 0 .. Width - 1 loop
                     Pixels.Append
                       (Rgb_Pixel'
                          (Red   =>
                             Natural (Current (Ada.Streams.Stream_Element_Offset (Column * Channels))),
                           Green =>
                             Natural (Current (Ada.Streams.Stream_Element_Offset (Column * Channels + 1))),
                           Blue  =>
                             Natural (Current (Ada.Streams.Stream_Element_Offset (Column * Channels + 2)))));
                  end loop;

                  Previous := Current;
               end;
            end loop;
         end;

         Write_Pixels_As_Ppm (Target_Path, Pixels, Width, Height);
         return True;
      exception
         when others =>
            Safe_Close (File);
            return False;
      end Try_Write_Decoded_Png_Thumbnail;

      function Try_Write_Gdk_Pixbuf_Thumbnail
        (Target_Path : String)
         return Boolean
      is
         C_Path : Interfaces.C.Strings.chars_ptr := Interfaces.C.Strings.New_String (Source_Path);
         Pixbuf : System.Address := System.Null_Address;
      begin
         Pixbuf :=
           Gdk_Pixbuf_New_From_File_At_Size
             (Filename => C_Path,
              Width    => C_Int (Size),
              Height   => C_Int (Size),
              Error    => System.Null_Address);
         Interfaces.C.Strings.Free (C_Path);

         if Pixbuf = System.Null_Address then
            return False;
         end if;

         declare
            Width     : constant Natural := Natural (Gdk_Pixbuf_Get_Width (Pixbuf));
            Height    : constant Natural := Natural (Gdk_Pixbuf_Get_Height (Pixbuf));
            Channels  : constant Natural := Natural (Gdk_Pixbuf_Get_N_Channels (Pixbuf));
            Rowstride : constant Natural := Natural (Gdk_Pixbuf_Get_Rowstride (Pixbuf));
            Pixels_Address : constant System.Address := Gdk_Pixbuf_Get_Pixels (Pixbuf);
            Raw       : constant Gdk_Pixel_Pointers.Object_Pointer :=
              Gdk_Pixel_Pointers.To_Pointer (Pixels_Address);
            Decoded   : Pixel_Vectors.Vector;
         begin
            if Width = 0
              or else Height = 0
              or else Width > 4096
              or else Height > 4096
              or else Channels < 3
              or else Rowstride < Width * Channels
              or else Pixels_Address = System.Null_Address
              or else Raw = null
            then
               G_Object_Unref (Pixbuf);
               return False;
            end if;

            for Row in 0 .. Height - 1 loop
               for Column in 0 .. Width - 1 loop
                  declare
                     Offset : constant Natural := Row * Rowstride + Column * Channels;
                  begin
                     Decoded.Append
                       (Rgb_Pixel'
                          (Red   => Natural (Raw.all (Offset)),
                           Green => Natural (Raw.all (Offset + 1)),
                           Blue  => Natural (Raw.all (Offset + 2))));
                  end;
               end loop;
            end loop;

            G_Object_Unref (Pixbuf);
            Pixbuf := System.Null_Address;
            --  Null the handle before any further work: Write_Pixels_As_Ppm can
            --  raise, and the exception handler unrefs Pixbuf when non-null.
            Write_Pixels_As_Ppm (Target_Path, Decoded, Width, Height);
            return True;
         end;
      exception
         when others =>
            Safe_Free (C_Path);
            if Pixbuf /= System.Null_Address then
               G_Object_Unref (Pixbuf);
            end if;
            return False;
      end Try_Write_Gdk_Pixbuf_Thumbnail;

      Checksum  : Natural := 0;
      Size_Bias : Natural := 0;
      Target    : Unbounded_String;
   begin
      if not Ada.Directories.Exists (Source_Path) then
         return
           (Status         => Thumbnail_Source_Missing,
            Source_Path    => To_Unbounded_String (Source_Path),
            Thumbnail_Path => Null_Unbounded_String,
            Width          => Size,
            Height         => Size,
            Error_Key      => To_Unbounded_String ("error.thumbnail.source_missing"));
      elsif Ada.Directories.Kind (Source_Path) /= Ada.Directories.Ordinary_File then
         return
           (Status         => Thumbnail_Unsupported,
            Source_Path    => To_Unbounded_String (Source_Path),
            Thumbnail_Path => Null_Unbounded_String,
            Width          => Size,
            Height         => Size,
            Error_Key      => To_Unbounded_String ("error.thumbnail.unsupported"));
      end if;

      Ada.Directories.Create_Path (Cache_Directory);
      Target := To_Unbounded_String (Thumbnail_Path_For (Source_Path, Cache_Directory, Size));
      if Try_Write_Decoded_Png_Thumbnail (To_String (Target))
        or else Try_Write_Decoded_P3_Thumbnail (To_String (Target))
        or else Try_Write_Gdk_Pixbuf_Thumbnail (To_String (Target))
      then
         return
           (Status         => Thumbnail_Generated,
            Source_Path    => To_Unbounded_String (Ada.Directories.Full_Name (Source_Path)),
            Thumbnail_Path => Target,
            Width          => Size,
            Height         => Size,
            Error_Key      => Null_Unbounded_String);
      end if;

      Checksum := Thumbnail_Path_Checksum (Source_Path);
      Size_Bias := File_Size_Signal;

      Ada.Text_IO.Create (File, Ada.Text_IO.Out_File, To_String (Target));
      Ada.Text_IO.Put_Line (File, "P3");
      Ada.Text_IO.Put_Line (File, Image_No_Space (Size) & " " & Image_No_Space (Size));
      Ada.Text_IO.Put_Line (File, "255");
      for Row in 0 .. Size - 1 loop
         for Column in 0 .. Size - 1 loop
            declare
               Cell   : constant Natural := Natural'Max (1, Size / 8);
               Stripe : constant Natural := (Row / Cell + Column / Cell) mod 2;
               Red    : constant Natural := Clamp_Channel (Checksum + Row * 5 + Size_Bias / 7 + Stripe * 28);
               Green  : constant Natural := Clamp_Channel (Checksum / 257 + Column * 7 + Size_Bias / 11);
               Blue   : constant Natural := Clamp_Channel (Checksum / 65_521 + Row + Column * 3 + Size_Bias / 13);
            begin
               Ada.Text_IO.Put
                 (File,
                  Image_No_Space (Red) & " "
                  & Image_No_Space (Green) & " "
                  & Image_No_Space (Blue));
               if Column < Size - 1 then
                  Ada.Text_IO.Put (File, " ");
               end if;
            end;
         end loop;
         Ada.Text_IO.New_Line (File);
      end loop;
      Ada.Text_IO.Close (File);

      return
        (Status         => Thumbnail_Generated,
         Source_Path    => To_Unbounded_String (Ada.Directories.Full_Name (Source_Path)),
         Thumbnail_Path => Target,
         Width          => Size,
         Height         => Size,
         Error_Key      => Null_Unbounded_String);
   exception
      when others =>
         Safe_Close (File);
         return
           (Status         => Thumbnail_Failed,
            Source_Path    => To_Unbounded_String (Source_Path),
            Thumbnail_Path => Target,
            Width          => Size,
            Height         => Size,
            Error_Key      => To_Unbounded_String ("error.thumbnail.failed"));
   end Generate_Thumbnail;

end Files.File_System;
