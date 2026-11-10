with Ada.Containers;

package body Files.Images.Netpbm is

   function Is_Blank (C : Character) return Boolean is (C in ' ' | ASCII.HT | ASCII.LF | ASCII.CR);

   procedure Next_Field
     (Text    : String;
      At_Byte : in out Positive;
      First   : out Positive;
      Last    : out Natural) is
   begin
      loop
         while At_Byte <= Text'Last and then Is_Blank (Text (At_Byte)) loop
            At_Byte := At_Byte + 1;
         end loop;
         exit when At_Byte > Text'Last or else Text (At_Byte) /= '#';
         while At_Byte <= Text'Last and then Text (At_Byte) not in ASCII.LF | ASCII.CR loop
            At_Byte := At_Byte + 1;
         end loop;
      end loop;
      First := At_Byte;
      while At_Byte <= Text'Last and then not Is_Blank (Text (At_Byte)) and then Text (At_Byte) /= '#' loop
         At_Byte := At_Byte + 1;
      end loop;
      Last := At_Byte - 1;
   end Next_Field;

   function Natural_Of (Field : String; Value : out Natural) return Boolean is
   begin
      Value := 0;
      if Field = "" then
         return False;
      end if;
      for C of Field loop
         if C not in '0' .. '9'
           or else Value > (Natural'Last - (Character'Pos (C) - Character'Pos ('0'))) / 10
         then
            return False;
         end if;
         Value := Value * 10 + Character'Pos (C) - Character'Pos ('0');
      end loop;
      return True;
   end Natural_Of;

   function Channel (Value : Natural; Max_Value : Natural) return Interfaces.Unsigned_8 is
     (if Max_Value = 0 then 0
      elsif Max_Value = 255 then Interfaces.Unsigned_8 (Natural'Min (Value, 255))
      else Interfaces.Unsigned_8 (Natural'Min ((Value * 255) / Max_Value, 255)));

   function P6_Header (Width : Positive; Height : Positive) return Ada.Streams.Stream_Element_Array is
      Text : constant String :=
        "P6" & ASCII.LF
        & Files.Types.Natural_Text (Width) & " " & Files.Types.Natural_Text (Height) & ASCII.LF
        & "255" & ASCII.LF;
      Bytes : Ada.Streams.Stream_Element_Array (1 .. Text'Length);
   begin
      for Index in Text'Range loop
         Bytes (Ada.Streams.Stream_Element_Offset (Index - Text'First + 1)) :=
           Ada.Streams.Stream_Element (Character'Pos (Text (Index)));
      end loop;
      return Bytes;
   end P6_Header;

   function Decode_P3
     (Text       : String;
      Max_Side   : Positive;
      Max_Pixels : Positive;
      Width      : out Natural;
      Height     : out Natural;
      Rgba       : out Files.Types.Byte_Vectors.Vector)
      return Boolean
   is
      At_Byte   : Positive := Text'First;
      Max_Value : Natural := 0;

      function Next return String is
         First : Positive;
         Last  : Natural;
      begin
         Next_Field (Text, At_Byte, First, Last);
         return Text (First .. Last);
      end Next;

      function Next_Natural (Value : out Natural) return Boolean is (Natural_Of (Next, Value));

      function Failed return Boolean is
      begin
         Width := 0;
         Height := 0;
         Rgba.Clear;
         return False;
      end Failed;
   begin
      Rgba.Clear;
      Width := 0;
      Height := 0;
      if Next /= "P3"
        or else not Next_Natural (Width)
        or else not Next_Natural (Height)
        or else not Next_Natural (Max_Value)
        or else Width = 0
        or else Height = 0
        or else Max_Value not in 1 .. 65_535
        or else Width > Max_Side
        or else Height > Max_Side
        or else Long_Long_Integer (Width) * Long_Long_Integer (Height) > Long_Long_Integer (Max_Pixels)
      then
         return Failed;
      end if;

      Rgba.Reserve_Capacity (Ada.Containers.Count_Type (Width * Height * 4));
      for Pixel in 1 .. Width * Height loop
         declare
            R, G, B : Natural;
         begin
            if not Next_Natural (R) or else not Next_Natural (G) or else not Next_Natural (B)
              or else R > Max_Value or else G > Max_Value or else B > Max_Value
            then
               return Failed;
            end if;
            Rgba.Append (Channel (R, Max_Value));
            Rgba.Append (Channel (G, Max_Value));
            Rgba.Append (Channel (B, Max_Value));
            Rgba.Append (255);
         end;
      end loop;

      --  Exactly the samples the header promised: nothing after them.
      return Next = "" or else Failed;
   end Decode_P3;

end Files.Images.Netpbm;
