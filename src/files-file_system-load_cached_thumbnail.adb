separate (Files.File_System)
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

   --  Keep thumbnail payloads byte-exact; text-oriented readers normalize
   --  line terminators and may decode input, corrupting encoded pixel bytes.
   function Read_Bytes
     (From      : String;
      Max_Bytes : Natural)
      return Unbounded_String
   is
      use Ada.Streams;

      Input      : GNAT.OS_Lib.File_Descriptor := GNAT.OS_Lib.Invalid_FD;
      Buffer     : Stream_Element_Array (1 .. 64 * 1024);
      Bytes_Read : Integer;
      Bytes      : Unbounded_String;
      Total      : Natural := 0;
   begin
      Input := Files.Fs.Open_Regular_Read (From);
      if Input = GNAT.OS_Lib.Invalid_FD then
         return Null_Unbounded_String;
      end if;

      loop
         Bytes_Read := GNAT.OS_Lib.Read
           (Input, Buffer'Address, Integer (Buffer'Length));
         if Bytes_Read < 0 then
            raise Ada.Directories.Use_Error;
         end if;
         exit when Bytes_Read = 0;

         declare
            Chunk_Length : constant Natural :=
              Natural (Bytes_Read);
            Chunk : String (1 .. Chunk_Length);
         begin
            if Chunk_Length > Max_Bytes - Total then
               GNAT.OS_Lib.Close (Input);
               Input := GNAT.OS_Lib.Invalid_FD;
               return Null_Unbounded_String;
            end if;

            for Index in Chunk'Range loop
               Chunk (Index) :=
                 Character'Val (Buffer (Stream_Element_Offset (Index) + Buffer'First - 1));
            end loop;

            Append (Bytes, Chunk);
            Total := Total + Chunk_Length;
         end;
      end loop;

      GNAT.OS_Lib.Close (Input);
      Input := GNAT.OS_Lib.Invalid_FD;
      return Bytes;
   exception
      when others =>
         if Input /= GNAT.OS_Lib.Invalid_FD then
            GNAT.OS_Lib.Close (Input);
         end if;

         return Null_Unbounded_String;
   end Read_Bytes;

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

   Content := Read_Bytes (Path, Max_Cached_Thumbnail_Bytes);
   if Length (Content) = 0 then
      return Result;
   end if;

   --  Binary P6 first: it is what this writes now, and reading it is a
   --  bounded header scan plus a copy, with none of the per-number string
   --  building the ASCII form below needs. P3 stays because caches written
   --  before the format changed are still on disk and still valid.
   declare
      Raw       : constant String := To_String (Content);
      At_Byte   : Natural := Raw'First;
      Width     : Natural := 0;
      Height    : Natural := 0;
      Max_Value : Natural := 0;

      --  One header field: skip blanks and # comments, then take the run of
      --  non-blank bytes. Leaves At_Byte on the delimiter that ended it.
      function Header_Field return String is
         First : Natural;
      begin
         loop
            while At_Byte <= Raw'Last
              and then Raw (At_Byte) in ' ' | ASCII.HT | ASCII.LF | ASCII.CR
            loop
               At_Byte := At_Byte + 1;
            end loop;
            exit when At_Byte > Raw'Last or else Raw (At_Byte) /= '#';
            if Raw (At_Byte) = '#' then
               while At_Byte <= Raw'Last and then Raw (At_Byte) /= ASCII.LF loop
                  At_Byte := At_Byte + 1;
               end loop;
            end if;
         end loop;

         First := At_Byte;
         while At_Byte <= Raw'Last
           and then Raw (At_Byte) not in ' ' | ASCII.HT | ASCII.LF | ASCII.CR | '#'
         loop
            At_Byte := At_Byte + 1;
         end loop;

         return Raw (First .. Natural'Min (At_Byte, Raw'Last + 1) - 1);
      end Header_Field;
   begin
      if Header_Field = "P6"
        and then Natural_Value (Header_Field, Width)
        and then Natural_Value (Header_Field, Height)
        and then Natural_Value (Header_Field, Max_Value)
        and then Width > 0 and then Height > 0 and then Max_Value = 255
        and then At_Byte <= Raw'Last
        and then Raw (At_Byte) in ' ' | ASCII.HT | ASCII.LF | ASCII.CR
        and then Long_Long_Integer (Width) * Long_Long_Integer (Height)
                   <= Long_Long_Integer (Max_Cached_Thumbnail_Pixels)
      then
         --  Exactly one whitespace byte separates the header from the pixels.
         At_Byte := At_Byte + 1;

         declare
            Needed : constant Long_Long_Integer :=
              Long_Long_Integer (Width) * Long_Long_Integer (Height) * 3;
         begin
            if Needed /= Long_Long_Integer (Raw'Last - At_Byte + 1) then
               return Result;
            end if;

            for Pixel in 0 .. Width * Height - 1 loop
               Result.Pixels.Append
                 (Channel (Character'Pos (Raw (At_Byte + Pixel * 3)), Max_Value));
               Result.Pixels.Append
                 (Channel (Character'Pos (Raw (At_Byte + Pixel * 3 + 1)), Max_Value));
               Result.Pixels.Append
                 (Channel (Character'Pos (Raw (At_Byte + Pixel * 3 + 2)), Max_Value));
               Result.Pixels.Append (255);
            end loop;
         end;

         Result.Loaded := True;
         Result.Width := Width;
         Result.Height := Height;
         return Result;
      end if;
   end;

   --  Tokenizing the legacy ASCII format creates one allocation per channel.
   --  Bound that expansion independently from the binary cache-file limit.
   if Length (Content) > Max_Legacy_Thumbnail_Bytes then
      return Result;
   end if;

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
        or else Max_Value > 65_535
        or else Long_Long_Integer (Width) * Long_Long_Integer (Height)
                  > Long_Long_Integer (Max_Cached_Thumbnail_Pixels)
        --  Reject headers whose declared pixel count needs more bytes than
        --  are present, computed without overflowing Integer for adversarial
        --  dimensions: Width * Height * 3 can exceed Integer'Last, so compare
        --  in Long_Long_Integer via the division form (equivalent to
        --  Length < 4 + Width * Height * 3 for the reject decision).
        or else Long_Long_Integer (Values.Length) - 4
                  /= Long_Long_Integer (Width) * Long_Long_Integer (Height) * 3
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
              or else R > Max_Value
              or else G > Max_Value
              or else B > Max_Value
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
