with Files.Capped_Files;
with Files.Images.Netpbm;
separate (Files.File_System.Thumbnails)
function Load_Cached_Thumbnail
  (Path : String)
   return Cached_Thumbnail
is
   Content : Unbounded_String;
   Result  : Cached_Thumbnail;

   function Natural_Value (Text : String; Value : out Natural) return Boolean
     renames Files.Images.Netpbm.Natural_Of;
   function Channel (Value : Natural; Max_Value : Natural) return Interfaces.Unsigned_8
     renames Files.Images.Netpbm.Channel;

   --  Keep thumbnail payloads byte-exact; text-oriented readers normalize
   --  line terminators and may decode input, corrupting encoded pixel bytes.
   function Read_Bytes
     (From      : String;
      Max_Bytes : Natural)
      return Unbounded_String
   is
      use type Files.Capped_Files.Read_Status;

      Status : Files.Capped_Files.Read_Status;
      Bytes  : constant String :=
        Files.Capped_Files.Read_Capped
          (From, Max_Bytes, Files.Capped_Files.Refuse_Links, Status);
   begin
      if Status /= Files.Capped_Files.Read_Complete then
         return Null_Unbounded_String;
      end if;
      return To_Unbounded_String (Bytes);
   end Read_Bytes;

begin
   if Path = ""
     or else not Files.Fs_Primitives.File_Exists (Path)
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

      --  One header field; leaves At_Byte on the delimiter that ended it.
      function Header_Field return String is
         First : Positive;
         Last  : Natural;
      begin
         Files.Images.Netpbm.Next_Field (Raw, At_Byte, First, Last);
         return Raw (First .. Last);
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
      Raw       : constant String := To_String (Content);
      At_Byte   : Positive := Raw'First;
      Width     : Natural;
      Height    : Natural;
      Max_Value : Natural;

      --  The next field as a number; False at the end or for anything else.
      function Next_Natural (Value : out Natural) return Boolean is
         First : Positive;
         Last  : Natural;
      begin
         Files.Images.Netpbm.Next_Field (Raw, At_Byte, First, Last);
         Value := 0;
         return Last >= First and then Natural_Value (Raw (First .. Last), Value);
      end Next_Natural;

      function Next_Is (Expected : String) return Boolean is
         First : Positive;
         Last  : Natural;
      begin
         Files.Images.Netpbm.Next_Field (Raw, At_Byte, First, Last);
         return Raw (First .. Last) = Expected;
      end Next_Is;
   begin
      if not Next_Is ("P3")
        or else not Next_Natural (Width)
        or else not Next_Natural (Height)
        or else not Next_Natural (Max_Value)
        or else Width = 0
        or else Height = 0
        or else Max_Value = 0
        or else Max_Value > 65_535
        or else Long_Long_Integer (Width) * Long_Long_Integer (Height)
                  > Long_Long_Integer (Max_Cached_Thumbnail_Pixels)
      then
         return Result;
      end if;

      for Pixel in 1 .. Width * Height loop
         declare
            R : Natural;
            G : Natural;
            B : Natural;
         begin
            if not Next_Natural (R)
              or else not Next_Natural (G)
              or else not Next_Natural (B)
              or else R > Max_Value
              or else G > Max_Value
              or else B > Max_Value
            then
               return (Loaded => False, Width => 0, Height => 0, Pixels => Files.Types.Byte_Vectors.Empty_Vector);
            end if;

            Result.Pixels.Append (Channel (R, Max_Value));
            Result.Pixels.Append (Channel (G, Max_Value));
            Result.Pixels.Append (Channel (B, Max_Value));
            Result.Pixels.Append (255);
         end;
      end loop;

      --  Exactly the samples the header promised: nothing after them.
      if not Next_Is ("") then
         return (Loaded => False, Width => 0, Height => 0, Pixels => Files.Types.Byte_Vectors.Empty_Vector);
      end if;

      Result.Loaded := True;
      Result.Width := Width;
      Result.Height := Height;
      return Result;
   end;
exception
   when Swallowed : others =>
      Files.Diagnostics.Note (Swallowed, "Files.File_System.Thumbnails");
      return (Loaded => False, Width => 0, Height => 0, Pixels => Files.Types.Byte_Vectors.Empty_Vector);
end Load_Cached_Thumbnail;
