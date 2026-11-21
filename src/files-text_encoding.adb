with Ada.Strings.Unbounded;
with Guikit.Utf8;

package body Files.Text_Encoding is

   use Ada.Strings.Unbounded;

   Replacement : constant String := Guikit.Utf8.Encode (16#FFFD#);

   --  What Guikit.Utf8.Decode_Next_Codepoint answers for a byte that starts
   --  no well-formed sequence: past every codepoint, so never a real one.
   Invalid : constant Natural := Natural'Last;

   function Is_Continuation (Value : Character) return Boolean is
     (Character'Pos (Value) in 16#80# .. 16#BF#);

   function Utf8_Sequence_Length (Text : String; At_Index : Positive) return Natural is
      Next      : Integer := At_Index;
      Codepoint : Natural;
   begin
      if Character'Pos (Text (At_Index)) < 16#80# then
         return 0;
      end if;
      Guikit.Utf8.Decode_Next_Codepoint (Text, Next, Codepoint, Replacement_Codepoint => Invalid);
      return (if Codepoint = Invalid then 0 else Next - At_Index);
   end Utf8_Sequence_Length;

   --  Whether Raw, without a byte order mark, reads as UTF-16 text in the
   --  order Little says: of its first units, most have a NUL high byte and
   --  next to none a NUL low byte.
   function Looks_Utf16 (Raw : String; Little : Boolean) return Boolean is
      Units     : constant Natural := Natural'Min (Raw'Length / 2, 512);
      High_Nuls : Natural := 0;
      Low_Nuls  : Natural := 0;
   begin
      if Units < 2 then
         return False;
      end if;
      for Unit in 0 .. Units - 1 loop
         declare
            Even : constant Character := Raw (Raw'First + 2 * Unit);
            Odd  : constant Character := Raw (Raw'First + 2 * Unit + 1);
         begin
            if (if Little then Odd else Even) = ASCII.NUL then
               High_Nuls := High_Nuls + 1;
            end if;
            if (if Little then Even else Odd) = ASCII.NUL then
               Low_Nuls := Low_Nuls + 1;
            end if;
         end;
      end loop;
      return High_Nuls * 4 >= Units * 3 and then Low_Nuls * 16 <= Units;
   end Looks_Utf16;

   function Utf16_Layout_Of (Raw : String) return Utf16_Layout is
   begin
      if Raw'Length >= 2 and then Raw (Raw'First) = Character'Val (16#FF#)
        and then Raw (Raw'First + 1) = Character'Val (16#FE#)
      then
         return Little_Endian_Marked;
      elsif Raw'Length >= 2 and then Raw (Raw'First) = Character'Val (16#FE#)
        and then Raw (Raw'First + 1) = Character'Val (16#FF#)
      then
         return Big_Endian_Marked;
      elsif Looks_Utf16 (Raw, Little => True) then
         return Little_Endian;
      elsif Looks_Utf16 (Raw, Little => False) then
         return Big_Endian;
      end if;
      return Not_Utf16;
   end Utf16_Layout_Of;

   --  Raw from First on as UTF-16 units, Little or big endian, UTF-8 encoded.
   --  A trailing odd byte, or a pair's first half, a read cut short is
   --  dropped; an unpaired surrogate is U+FFFD.
   function From_Utf16 (Raw : String; First : Positive; Little : Boolean) return String is
      Result : Unbounded_String;
      Index  : Natural := First;

      function Unit_At (At_Index : Positive) return Natural is
        (if Little
         then Character'Pos (Raw (At_Index)) + 256 * Character'Pos (Raw (At_Index + 1))
         else 256 * Character'Pos (Raw (At_Index)) + Character'Pos (Raw (At_Index + 1)));
   begin
      while Index < Raw'Last loop
         declare
            Unit : constant Natural := Unit_At (Index);
         begin
            Index := Index + 2;
            if Unit in 16#D800# .. 16#DBFF# then
               if Index >= Raw'Last then
                  --  The pair's second half was cut off.
                  exit;
               elsif Unit_At (Index) in 16#DC00# .. 16#DFFF# then
                  Append
                    (Result,
                     Guikit.Utf8.Encode (16#10000# + (Unit - 16#D800#) * 16#400# + (Unit_At (Index) - 16#DC00#)));
                  Index := Index + 2;
               else
                  Append (Result, Replacement);
               end if;
            elsif Unit in 16#DC00# .. 16#DFFF# then
               Append (Result, Replacement);
            else
               Append (Result, Guikit.Utf8.Encode (Unit));
            end if;
         end;
      end loop;
      return To_String (Result);
   end From_Utf16;

   --  Raw transcoded from the UTF-16 Layout says.
   function From_Utf16 (Raw : String; Layout : Utf16_Layout) return String is
     (case Layout is
         when Little_Endian_Marked => From_Utf16 (Raw, Raw'First + 2, Little => True),
         when Big_Endian_Marked    => From_Utf16 (Raw, Raw'First + 2, Little => False),
         when Little_Endian        => From_Utf16 (Raw, Raw'First, Little => True),
         when Big_Endian           => From_Utf16 (Raw, Raw'First, Little => False),
         when Not_Utf16            => Raw);

   --  Windows-1252's 0x80 .. 0x9F; 0 where it has no character.
   Cp1252 : constant array (16#80# .. 16#9F#) of Natural :=
     [16#20AC#, 0, 16#201A#, 16#0192#, 16#201E#, 16#2026#, 16#2020#, 16#2021#,
      16#02C6#, 16#2030#, 16#0160#, 16#2039#, 16#0152#, 0, 16#017D#, 0,
      0, 16#2018#, 16#2019#, 16#201C#, 16#201D#, 16#2022#, 16#2013#, 16#2014#,
      16#02DC#, 16#2122#, 16#0161#, 16#203A#, 16#0153#, 0, 16#017E#, 16#0178#];

   --  One byte as Windows-1252 says it, UTF-8 encoded.
   function Cp1252_Char (Char : Character) return String is
      Code : constant Natural := Character'Pos (Char);
   begin
      if Code < 16#80# then
         return [1 => Char];
      elsif Code <= 16#9F# then
         return (if Cp1252 (Code) = 0 then Replacement else Guikit.Utf8.Encode (Cp1252 (Code)));
      else
         return Guikit.Utf8.Encode (Code);
      end if;
   end Cp1252_Char;

   --  Raw decoded byte by byte: each well-formed UTF-8 sequence kept, every
   --  other byte read as Windows-1252 -- or, when Mixed is False, every byte
   --  read so (text with next to no UTF-8 in it is not UTF-8: the odd pair of
   --  Latin-1 letters that happens to form a sequence is not one).
   function Decoded (Raw : String; Mixed : Boolean) return String is
      Result : Unbounded_String;
      Index  : Positive := Raw'First;
   begin
      while Index <= Raw'Last loop
         declare
            Length : constant Natural := (if Mixed then Utf8_Sequence_Length (Raw, Index) else 0);
         begin
            if Length > 0 then
               Append (Result, Raw (Index .. Index + Length - 1));
               Index := Index + Length;
            else
               Append (Result, Cp1252_Char (Raw (Index)));
               Index := Index + 1;
            end if;
         end;
      end loop;
      return To_String (Result);
   end Decoded;

   --  Whether Raw holds more well-formed UTF-8 sequences than stray high
   --  bytes: UTF-8 text with a few bytes of something else.
   function Mostly_Utf8 (Raw : String) return Boolean is
      Sequences : Natural := 0;
      Strays    : Natural := 0;
      Index     : Positive := Raw'First;
   begin
      while Index <= Raw'Last loop
         declare
            Length : constant Natural := Utf8_Sequence_Length (Raw, Index);
         begin
            if Length > 0 then
               Sequences := Sequences + 1;
               Index := Index + Length;
            else
               if Character'Pos (Raw (Index)) >= 16#80# then
                  Strays := Strays + 1;
               end if;
               Index := Index + 1;
            end if;
         end;
      end loop;
      return Sequences > Strays;
   end Mostly_Utf8;

   function Looks_Binary
     (Raw_Bytes : String)
      return Boolean
   is
      Control_Count : Natural := 0;
   begin
      if Raw_Bytes'Length = 0 then
         return False;
      end if;

      for Char of Raw_Bytes loop
         declare
            Code : constant Natural := Character'Pos (Char);
         begin
            if Code = 0 then
               --  A NUL byte is a decisive signal of non-text content.
               return True;
            elsif Code < 32
              and then Char /= ASCII.HT
              and then Char /= ASCII.LF
              and then Char /= ASCII.CR
              and then Char /= ASCII.FF
            then
               Control_Count := Control_Count + 1;
            end if;
         end;
      end loop;

      --  Treat a large share of stray control bytes as binary; ordinary text
      --  and source files stay well under this threshold.
      --  Equivalent to Control_Count * 10 > Length, without overflowing for a
      --  very large caller-supplied buffer.
      return Control_Count > Raw_Bytes'Length / 10;
   end Looks_Binary;

   function Trim_To_Character (Raw : String) return String is
      Lead : Natural := Raw'Last;
   begin
      --  Step back over at most three continuation bytes (10xxxxxx).
      while Lead >= Raw'First
        and then Raw'Last - Lead < 3
        and then Is_Continuation (Raw (Lead))
      loop
         Lead := Lead - 1;
      end loop;
      if Lead < Raw'First then
         return Raw;
      end if;
      declare
         Code   : constant Natural := Character'Pos (Raw (Lead));
         Needed : constant Natural :=
           (if Code in 16#C0# .. 16#DF# then 2
            elsif Code in 16#E0# .. 16#EF# then 3
            elsif Code in 16#F0# .. 16#F7# then 4
            else 1);
      begin
         if Raw'Last - Lead + 1 < Needed then
            return Raw (Raw'First .. Lead - 1);
         end if;
         return Raw;
      end;
   end Trim_To_Character;

   function Searchable_Text (Raw : String) return String is
      Layout : constant Utf16_Layout := Utf16_Layout_Of (Raw);
   begin
      if Layout /= Not_Utf16 then
         return From_Utf16 (Raw, Layout);
      end if;
      declare
         Text : constant String := Trim_To_Character (Raw);
      begin
         if Looks_Binary (Text) or else Guikit.Utf8.Is_Valid (Text) then
            return Text;
         end if;
      end;
      --  Not UTF-8 throughout: UTF-8 with a stray byte keeps its characters
      --  (only the stray bytes are read as Windows-1252); anything else is
      --  read as Windows-1252 whole.
      return Decoded (Raw, Mixed => Mostly_Utf8 (Raw));
   end Searchable_Text;

   function Classify (Sample : String; Complete : Boolean) return Encoding is
      Layout : constant Utf16_Layout := Utf16_Layout_Of (Sample);
   begin
      if Layout /= Not_Utf16 then
         --  What the search reads it as; text only when that is text.
         if Looks_Binary (From_Utf16 (Sample, Layout)) then
            return Binary;
         end if;
         return (if Layout in Little_Endian_Marked | Little_Endian then Utf16_Little_Endian else Utf16_Big_Endian);
      end if;
      declare
         Text       : constant String := (if Complete then Sample else Trim_To_Character (Sample));
         Index      : Positive := Text'First;
         --  A character the sample's end cut short is not ASCII either.
         Ascii_Only : Boolean := Text'Length = Sample'Length;
      begin
         while Index <= Text'Last loop
            if Text (Index) = ASCII.NUL then
               return Binary;
            elsif Character'Pos (Text (Index)) < 16#80# then
               Index := Index + 1;
            else
               declare
                  Length : constant Natural := Utf8_Sequence_Length (Text, Index);
               begin
                  if Length = 0 then
                     return Binary;
                  end if;
                  Ascii_Only := False;
                  Index := Index + Length;
               end;
            end if;
         end loop;
         return (if Ascii_Only then Ascii_Text else Utf8);
      end;
   end Classify;

end Files.Text_Encoding;
