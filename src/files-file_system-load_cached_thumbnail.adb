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
