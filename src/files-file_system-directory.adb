with Files.File_System.Support;
with Ada.Strings.Unbounded;
with Interfaces.C;
with Interfaces.C.Strings;
with Ada.Directories;
with Ada.Streams;
with GNAT.OS_Lib;
with Ada.Text_IO;
with Ada.Strings.Fixed;
with Files.File_Types;
with Files.Fs;
with Files.Platform.Metadata;
with Hostkit.Fs;
with Ada.Streams.Stream_IO;

separate (Files.File_System)
package body Directory is
   use type Interfaces.C.int;
   use type Interfaces.C.long;
   use type Interfaces.C.unsigned;
   use type Interfaces.C.unsigned_long;
   use type Interfaces.C.Strings.chars_ptr;
   use type Ada.Calendar.Time;
   use type Ada.Directories.File_Kind;
   use type Ada.Streams.Stream_Element;
   use type Ada.Streams.Stream_Element_Offset;
   use type Files.Settings.Sort_Field;
   use type Files.Types.Item_Kind;

   function Stream_Byte (Value : Ada.Streams.Stream_Element) return Natural;

   function Stream_Byte (Value : Ada.Streams.Stream_Element) return Natural is
   begin
      return Natural (Value);
   end Stream_Byte;

   Extra_Line_Limit : constant Natural := 20_000;

   type Cached_Thumbnail is record
      Loaded : Boolean := False;
      Width  : Natural := 0;
      Height : Natural := 0;
      Pixels : Files.Types.Byte_Vectors.Vector;
   end record;

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

   function Load_Cached_Thumbnail
     (Path : String)
      return Cached_Thumbnail;

   function Should_Auto_Generate_Thumbnail
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean;

   function Thumbnail_For_Item
     (Full_Path       : String;
      Kind            : Files.Types.Item_Kind;
      Filetype        : String;
      Name            : String;
      Icon_Id         : String;
      Cache_Directory : String;
      Thumbnail_Path  : String)
      return Cached_Thumbnail;

   function Permission_String (Path : String) return String;

   function Count_Text_Lines (Path : String) return Natural;

   function Text_Encoding_Name (Path : String) return String;

   function Text_Metadata_Token
     (Prefix : String;
      Path   : String)
      return String;

   function Pdf_Page_Count_Token (Path : String) return String;

   function Zip_Entry_Count_Token
     (Path   : String;
      Prefix : String)
      return String;

   function Matches_Signature
     (Buffer  : Ada.Streams.Stream_Element_Array;
      Last    : Ada.Streams.Stream_Element_Offset;
      Pattern : Ada.Streams.Stream_Element_Array)
      return Boolean;

   function Executable_Format_Token (Path : String) return String;

   function Directory_Count_Token (Path : String) return String;

   function U16_BE
     (Buffer : Ada.Streams.Stream_Element_Array;
      Start  : Ada.Streams.Stream_Element_Offset)
      return Natural;

   function U32_BE
     (Buffer : Ada.Streams.Stream_Element_Array;
      Start  : Ada.Streams.Stream_Element_Offset)
      return Natural;

   function Dimensions_Text
     (Width  : Natural;
      Height : Natural)
      return String;

   function Image_Dimensions_Token
     (Path     : String;
      Filetype : String)
      return String;

   function Kind_From_Directory_Entry
     (Dir_Entry : Ada.Directories.Directory_Entry_Type)
      return Files.Types.Item_Kind;

   function Item_For_Path
     (Full        : String;
      Name        : String;
      Parent_Path : String;
      Kind        : Files.Types.Item_Kind;
      Settings    : Files.Settings.Settings_Model)
      return Directory_Item;

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
           --  Reject headers whose declared pixel count needs more bytes than
           --  are present, computed without overflowing Integer for adversarial
           --  dimensions: Width * Height * 3 can exceed Integer'Last, so compare
           --  in Long_Long_Integer via the division form (equivalent to
           --  Length < 4 + Width * Height * 3 for the reject decision).
           or else Long_Long_Integer (Width) * Long_Long_Integer (Height)
                     > (Long_Long_Integer (Values.Length) - 4) / 3
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

   function Should_Auto_Generate_Thumbnail
     (Kind     : Files.Types.Item_Kind;
      Filetype : String;
      Name     : String;
      Icon_Id  : String)
      return Boolean is
   begin
      return Is_Image_Item (Kind, Filetype, Name, Icon_Id);
   end Should_Auto_Generate_Thumbnail;

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
      --  Classify by sampling a bounded prefix, the way file(1) does. Scanning
      --  the whole file would turn a passive directory browse into an
      --  unbounded read: this runs per regular text file via Extra_Info_Token,
      --  so a multi-GB all-valid-text file (a big log or SQL dump) would
      --  otherwise be read end to end just to render its metadata line.
      Encoding_Sample_Limit : constant := 131_072;

      File       : Ada.Streams.Stream_IO.File_Type;
      Buffer     : Ada.Streams.Stream_Element_Array (1 .. 4096);
      Last       : Ada.Streams.Stream_Element_Offset;
      Byte_Value : Natural;
      Ascii_Only : Boolean := True;
      Pending    : Natural := 0;
      First_Byte : Natural := 0;
      Step       : Natural := 0;
      Scanned    : Natural := 0;

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

               Scanned := Scanned + 1;
               if Scanned >= Encoding_Sample_Limit then
                  --  Enough of a clean prefix to classify. A partial multi-byte
                  --  sequence straddling the cap is not a defect here (Ascii_Only
                  --  is already cleared), so do not fall through to the binary
                  --  verdict the way a genuine mid-sequence EOF would.
                  Ada.Streams.Stream_IO.Close (File);
                  return (if Ascii_Only then "ascii" else "utf8");
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

end Directory;
