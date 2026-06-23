package body Files.UTF8 is

   function Saturating_Add
     (Left  : Natural;
      Right : Natural)
      return Natural is
   begin
      if Left > Natural'Last - Right then
         return Natural'Last;
      else
         return Left + Right;
      end if;
   end Saturating_Add;

   function Is_Continuation (Value : Character) return Boolean is
      Code : constant Natural := Character'Pos (Value);
   begin
      return Code in 16#80# .. 16#BF#;
   end Is_Continuation;

   function Byte_At
     (Content : String;
      Index   : Integer)
      return Natural is
   begin
      return Character'Pos (Content (Index));
   end Byte_At;

   function Unit_Length
     (Content : String;
      Index   : Integer)
      return Positive
   is
      B1 : constant Natural := Byte_At (Content, Index);
      B2 : Natural := 0;
   begin
      if B1 <= 16#7F# then
         return 1;
      elsif B1 in 16#C2# .. 16#DF#
        and then Index <= Content'Last - 1
        and then Is_Continuation (Content (Index + 1))
      then
         return 2;
      elsif B1 in 16#E0# .. 16#EF#
        and then Index <= Content'Last - 2
        and then Is_Continuation (Content (Index + 1))
        and then Is_Continuation (Content (Index + 2))
      then
         B2 := Byte_At (Content, Index + 1);
         if (B1 = 16#E0# and then B2 < 16#A0#)
           or else (B1 = 16#ED# and then B2 > 16#9F#)
         then
            return 1;
         end if;

         return 3;
      elsif B1 in 16#F0# .. 16#F4#
        and then Index <= Content'Last - 3
        and then Is_Continuation (Content (Index + 1))
        and then Is_Continuation (Content (Index + 2))
        and then Is_Continuation (Content (Index + 3))
      then
         B2 := Byte_At (Content, Index + 1);
         if (B1 = 16#F0# and then B2 < 16#90#)
           or else (B1 = 16#F4# and then B2 > 16#8F#)
         then
            return 1;
         end if;

         return 4;
      end if;

      return 1;
   end Unit_Length;

   function Is_Combining_Codepoint
     (Codepoint : Natural)
      return Boolean is
   begin
      return Is_Required_Zero_Width_Codepoint (Codepoint)
        or else Codepoint in 16#FE00# .. 16#FE0F#
        or else Codepoint in 16#E0100# .. 16#E01EF#;
   end Is_Combining_Codepoint;

   function Is_Required_Zero_Width_Codepoint
     (Codepoint : Natural)
      return Boolean is
   begin
      return Codepoint in 16#0300# .. 16#036F#
        or else Codepoint in 16#1AB0# .. 16#1AFF#
        or else Codepoint in 16#1DC0# .. 16#1DFF#
        or else Codepoint in 16#20D0# .. 16#20FF#
        or else Codepoint in 16#FE20# .. 16#FE2F#;
   end Is_Required_Zero_Width_Codepoint;

   function Is_Wide_Codepoint
     (Codepoint : Natural)
      return Boolean is
   begin
      return Codepoint in 16#1100# .. 16#115F#
        or else Codepoint = 16#2329#
        or else Codepoint = 16#232A#
        or else Codepoint in 16#2E80# .. 16#A4CF#
        or else Codepoint in 16#AC00# .. 16#D7A3#
        or else Codepoint in 16#F900# .. 16#FAFF#
        or else Codepoint in 16#FE10# .. 16#FE19#
        or else Codepoint in 16#FE30# .. 16#FE6F#
        or else Codepoint in 16#FF00# .. 16#FF60#
        or else Codepoint in 16#FFE0# .. 16#FFE6#
        or else Codepoint in 16#1F300# .. 16#1FAFF#;
   end Is_Wide_Codepoint;

   function Codepoint_Display_Units
     (Codepoint : Natural)
      return Natural is
   begin
      if Is_Combining_Codepoint (Codepoint) then
         return 0;
      elsif Is_Wide_Codepoint (Codepoint) then
         return 2;
      else
         return 1;
      end if;
   end Codepoint_Display_Units;

   function Codepoint_At_Offset
     (Content : String;
      Offset  : Natural)
      return Natural
   is
      Index     : Integer := Content'First + Offset;
      Codepoint : Natural := 0;
   begin
      if Offset >= Content'Length then
         return 16#110000#;
      end if;

      Decode_Next_Codepoint
        (Content,
         Index,
         Codepoint,
         Replacement_Codepoint => 16#FFFD#);
      return Codepoint;
   end Codepoint_At_Offset;

   function Continuation_At
     (Content  : String;
      Position : Natural)
      return Boolean
   is
      Index : constant Natural := Content'First + Position;
      Lead  : Natural := Position;
   begin
      if Position = 0
        or else Position >= Content'Length
        or else not Is_Continuation (Content (Index))
      then
         return False;
      end if;

      while Lead > 0 and then Is_Continuation (Content (Content'First + Lead)) loop
         Lead := Lead - 1;
      end loop;

      declare
         Lead_Code : constant Natural := Character'Pos (Content (Content'First + Lead));
         Expected  : Natural := 0;
      begin
         if Lead_Code in 16#C2# .. 16#DF# then
            Expected := 1;
         elsif Lead_Code in 16#E0# .. 16#EF# then
            Expected := 2;
         elsif Lead_Code in 16#F0# .. 16#F4# then
            Expected := 3;
         else
            return False;
         end if;

         return Position - Lead <= Expected;
      end;
   end Continuation_At;

   function Next_Unit_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural
   is
      Position : Natural := Natural'Min (Cursor, Content'Length);
   begin
      if Position >= Content'Length then
         return Content'Length;
      end if;

      Position := Position + 1;
      while Position < Content'Length and then Continuation_At (Content, Position) loop
         Position := Position + 1;
      end loop;

      return Position;
   end Next_Unit_Boundary;

   function Display_Units
     (Content : String)
      return Natural
   is
      Index     : Integer := Content'First;
      Units     : Natural := 0;
      Codepoint : Natural := 0;
   begin
      while Index <= Content'Last loop
         Decode_Next_Codepoint (Content, Index, Codepoint);
         Units := Saturating_Add (Units, Codepoint_Display_Units (Codepoint));
      end loop;

      return Units;
   end Display_Units;

   function Prefix_By_Units
     (Content   : String;
      Max_Units : Natural)
      return String
   is
      Index     : Integer := Content'First;
      Last      : Integer := Content'First - 1;
      Units     : Natural := 0;
      Codepoint : Natural := 0;
      Width     : Natural := 0;
   begin
      if Max_Units = 0 or else Content'Length = 0 then
         return "";
      end if;

      while Index <= Content'Last loop
         declare
            Start : constant Integer := Index;
         begin
            Decode_Next_Codepoint (Content, Index, Codepoint);
            Width := Codepoint_Display_Units (Codepoint);
            exit when Saturating_Add (Units, Width) > Max_Units;

            Units := Saturating_Add (Units, Width);
            Last := Index - 1;
         exception
            when Constraint_Error =>
               Index := Start + 1;
               exit when Saturating_Add (Units, 1) > Max_Units;
               Units := Saturating_Add (Units, 1);
               Last := Start;
         end;
      end loop;

      if Last < Content'First then
         return "";
      end if;

      return Content (Content'First .. Last);
   end Prefix_By_Units;

   function Display_Units_Before
     (Content : String;
      Cursor  : Natural)
      return Natural
   is
      Limit     : constant Natural := Natural'Min (Cursor, Content'Length);
      Index     : Integer := Content'First;
      Units     : Natural := 0;
      Codepoint : Natural := 0;
   begin
      if Limit = 0 then
         return 0;
      end if;

      while Index <= Content'Last and then Natural (Index - Content'First) < Limit loop
         Decode_Next_Codepoint (Content, Index, Codepoint);
         Units := Saturating_Add (Units, Codepoint_Display_Units (Codepoint));
      end loop;

      return Units;
   end Display_Units_Before;

   function Byte_Offset_For_Display_Column
     (Content : String;
      Column  : Natural)
      return Natural
   is
      Index     : Integer := Content'First;
      Units     : Natural := 0;
      Codepoint : Natural := 0;
      Width     : Natural := 0;
      Offset    : Natural := 0;

      function After_Trailing_Zero_Width (Start : Integer) return Natural is
         Scan            : Integer := Start;
         Scanned_Point   : Natural := 0;
         Scanned_Width   : Natural := 0;
      begin
         while Scan <= Content'Last loop
            declare
               Unit_Start : constant Integer := Scan;
            begin
               Decode_Next_Codepoint (Content, Scan, Scanned_Point);
               Scanned_Width := Codepoint_Display_Units (Scanned_Point);
               exit when Scanned_Width > 0;
               Offset := Natural (Scan - Content'First);
            exception
               when Constraint_Error =>
                  return Natural (Unit_Start - Content'First);
            end;
         end loop;

         return Offset;
      end After_Trailing_Zero_Width;
   begin
      if Content'Length = 0 or else Column = 0 then
         return 0;
      end if;

      while Index <= Content'Last loop
         Offset := Natural (Index - Content'First);
         if Units >= Column then
            return After_Trailing_Zero_Width (Index);
         end if;

         Decode_Next_Codepoint (Content, Index, Codepoint);
         Width := Codepoint_Display_Units (Codepoint);
         if Width > 0 and then Saturating_Add (Units, Width) > Column then
            return Offset;
         end if;

         Units := Saturating_Add (Units, Width);
      end loop;

      return Content'Length;
   end Byte_Offset_For_Display_Column;

   procedure Decode_Next_Codepoint
     (Content               : String;
      Index                 : in out Integer;
      Codepoint             : out Natural;
      Replacement_Codepoint : Natural := 16#FFFD#)
   is
      B1 : constant Natural := Byte_At (Content, Index);
      B2 : Natural := 0;
      B3 : Natural := 0;
      B4 : Natural := 0;
   begin
      if B1 <= 16#7F# then
         Codepoint := B1;
         Index := Index + 1;
      elsif B1 in 16#C2# .. 16#DF#
        and then Index <= Content'Last - 1
        and then Is_Continuation (Content (Index + 1))
      then
         B2 := Byte_At (Content, Index + 1);
         Codepoint := ((B1 mod 32) * 64) + (B2 mod 64);
         Index := Index + 2;
      elsif B1 in 16#E0# .. 16#EF#
        and then Index <= Content'Last - 2
        and then Is_Continuation (Content (Index + 1))
        and then Is_Continuation (Content (Index + 2))
      then
         B2 := Byte_At (Content, Index + 1);
         B3 := Byte_At (Content, Index + 2);
         if (B1 = 16#E0# and then B2 < 16#A0#)
           or else (B1 = 16#ED# and then B2 > 16#9F#)
         then
            Codepoint := Replacement_Codepoint;
            Index := Index + 1;
         else
            Codepoint := ((B1 mod 16) * 4096) + ((B2 mod 64) * 64) + (B3 mod 64);
            Index := Index + 3;
         end if;
      elsif B1 in 16#F0# .. 16#F4#
        and then Index <= Content'Last - 3
        and then Is_Continuation (Content (Index + 1))
        and then Is_Continuation (Content (Index + 2))
        and then Is_Continuation (Content (Index + 3))
      then
         B2 := Byte_At (Content, Index + 1);
         B3 := Byte_At (Content, Index + 2);
         B4 := Byte_At (Content, Index + 3);
         if (B1 = 16#F0# and then B2 < 16#90#)
           or else (B1 = 16#F4# and then B2 > 16#8F#)
         then
            Codepoint := Replacement_Codepoint;
            Index := Index + 1;
         else
            Codepoint :=
              ((B1 mod 8) * 262_144)
              + ((B2 mod 64) * 4096)
              + ((B3 mod 64) * 64)
              + (B4 mod 64);
            Index := Index + 4;
         end if;
      else
         Codepoint := Replacement_Codepoint;
         Index := Index + 1;
      end if;
   end Decode_Next_Codepoint;

   procedure Decode_Next_Display_Codepoint
     (Content   : String;
      Index     : in out Integer;
      Codepoint : out Natural)
   is
      Byte_Value : constant Natural := Byte_At (Content, Index);
   begin
      if Byte_Value > 16#7F# and then Unit_Length (Content, Index) = 1 then
         Codepoint := Byte_Value;
         Index := Index + 1;
      else
         Decode_Next_Codepoint
           (Content,
            Index,
            Codepoint,
            Replacement_Codepoint => 16#FFFD#);
      end if;
   end Decode_Next_Display_Codepoint;

   function Is_Valid
     (Content : String)
      return Boolean
   is
      Invalid_Codepoint : constant Natural := 16#110000#;
      Index             : Integer := Content'First;
      Codepoint         : Natural := 0;
   begin
      while Index <= Content'Last loop
         Decode_Next_Codepoint
           (Content,
            Index,
            Codepoint,
            Replacement_Codepoint => Invalid_Codepoint);
         if Codepoint = Invalid_Codepoint then
            return False;
         end if;
      end loop;

      return True;
   end Is_Valid;

   function Encode_Codepoint
     (Codepoint : Natural)
      return String
   is
      Value : constant Natural :=
        (if Codepoint <= 16#10FFFF#
           and then not (Codepoint in 16#D800# .. 16#DFFF#)
         then Codepoint
         else 16#FFFD#);

      function Byte (V : Natural) return Character is
      begin
         return Character'Val (V);
      end Byte;
   begin
      if Value <= 16#7F# then
         return [1 => Byte (Value)];
      elsif Value <= 16#7FF# then
         return
           [1 => Byte (16#C0# + Value / 64),
            2 => Byte (16#80# + Value mod 64)];
      elsif Value <= 16#FFFF# then
         return
           [1 => Byte (16#E0# + Value / 4096),
            2 => Byte (16#80# + (Value / 64) mod 64),
            3 => Byte (16#80# + Value mod 64)];
      else
         return
           [1 => Byte (16#F0# + Value / 262_144),
            2 => Byte (16#80# + (Value / 4096) mod 64),
            3 => Byte (16#80# + (Value / 64) mod 64),
            4 => Byte (16#80# + Value mod 64)];
      end if;
   end Encode_Codepoint;

   function Previous_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural
   is
      Position : Natural := Natural'Min (Cursor, Content'Length);
      Codepoint : Natural := 0;
   begin
      if Position = 0 then
         return 0;
      end if;

      loop
         Position := Position - 1;
         while Position > 0 and then Continuation_At (Content, Position) loop
            Position := Position - 1;
         end loop;

         Codepoint := Codepoint_At_Offset (Content, Position);
         exit when not Is_Combining_Codepoint (Codepoint) or else Position = 0;
      end loop;

      return Position;
   end Previous_Boundary;

   function Next_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural
   is
      Position : Natural := Natural'Min (Cursor, Content'Length);
      Codepoint : Natural := 0;
   begin
      Position := Next_Unit_Boundary (Content, Position);
      while Position < Content'Length loop
         Codepoint := Codepoint_At_Offset (Content, Position);
         exit when not Is_Combining_Codepoint (Codepoint);
         Position := Next_Unit_Boundary (Content, Position);
      end loop;

      return Position;
   end Next_Boundary;

   function Boundary_At_Or_Before
     (Content : String;
      Cursor  : Natural)
      return Natural
   is
      Position : Natural := Natural'Min (Cursor, Content'Length);
      Codepoint : Natural := 0;
   begin
      while Position > 0
        and then Position < Content'Length
        and then Continuation_At (Content, Position)
      loop
         Position := Position - 1;
      end loop;

      if Position > 0 and then Position < Content'Length then
         Codepoint := Codepoint_At_Offset (Content, Position);
         if Is_Combining_Codepoint (Codepoint) then
            return Previous_Boundary (Content, Position);
         end if;
      end if;

      return Position;
   end Boundary_At_Or_Before;

   function Is_Whitespace_Separator_Codepoint
     (Codepoint : Natural)
      return Boolean is
   begin
      return Codepoint = Character'Pos (' ')
        or else Codepoint = 9
        or else Codepoint = 10
        or else Codepoint = 11
        or else Codepoint = 12
        or else Codepoint = 13
        or else Codepoint = 16#85#
        or else Codepoint = 16#00A0#
        or else Codepoint = 16#1680#
        or else Codepoint in 16#2000# .. 16#200A#
        or else Codepoint = 16#2028#
        or else Codepoint = 16#2029#
        or else Codepoint = 16#202F#
        or else Codepoint = 16#205F#
        or else Codepoint = 16#3000#;
   end Is_Whitespace_Separator_Codepoint;

   function Is_Word_Punctuation (Codepoint : Natural) return Boolean is
   begin
      return Codepoint = Character'Pos ('/')
        or else Codepoint = Character'Pos ('\')
        or else Codepoint = Character'Pos ('.')
        or else Codepoint = Character'Pos ('-')
        or else Codepoint = Character'Pos ('_');
   end Is_Word_Punctuation;

   function Whitespace_Separator_Length
     (Content  : String;
      Position : Natural)
      return Natural
   is
      Index     : constant Natural := Content'First + Position;
      Next      : Integer := Index;
      Codepoint : Natural := 0;
   begin
      if Position >= Content'Length then
         return 0;
      elsif Byte_At (Content, Index) = 16#85# then
         return 1;
      end if;

      Decode_Next_Codepoint
        (Content,
         Next,
         Codepoint,
         Replacement_Codepoint => 16#110000#);
      if Is_Whitespace_Separator_Codepoint (Codepoint) then
         return Natural (Next - Index);
      end if;

      return 0;
   end Whitespace_Separator_Length;

   function Word_Separator_Length
     (Content  : String;
      Position : Natural)
      return Natural
   is
      Length : constant Natural := Whitespace_Separator_Length (Content, Position);
      Index  : constant Natural := Content'First + Position;
   begin
      if Length > 0 then
         return Length;
      elsif Position >= Content'Length then
         return 0;
      elsif Is_Word_Punctuation (Character'Pos (Content (Index))) then
         return 1;
      end if;

      return 0;
   end Word_Separator_Length;

   function Previous_Word_Separator_Length
     (Content  : String;
      Position : Natural)
      return Natural
   is
      Max_Length : constant Natural := Natural'Min (4, Position);
   begin
      for Length in reverse 1 .. Max_Length loop
         if Word_Separator_Length (Content, Position - Length) = Length then
            return Length;
         end if;
      end loop;

      return 0;
   end Previous_Word_Separator_Length;

   function Previous_Word_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural
   is
      Position : Natural := Natural'Min (Cursor, Content'Length);
      Separator_Length : Natural;
   begin
      loop
         Separator_Length := Previous_Word_Separator_Length (Content, Position);
         exit when Separator_Length = 0;
         Position := Position - Separator_Length;
      end loop;

      while Position > 0 and then Previous_Word_Separator_Length (Content, Position) = 0 loop
         Position := Previous_Boundary (Content, Position);
      end loop;

      return Position;
   end Previous_Word_Boundary;

   function Next_Word_Boundary
     (Content : String;
      Cursor  : Natural)
      return Natural
   is
      Position : Natural := Natural'Min (Cursor, Content'Length);
      Separator_Length : Natural;
   begin
      loop
         Separator_Length := Word_Separator_Length (Content, Position);
         exit when Separator_Length = 0;
         Position := Natural'Min (Position + Separator_Length, Content'Length);
      end loop;

      while Position < Content'Length and then Word_Separator_Length (Content, Position) = 0 loop
         Position := Next_Boundary (Content, Position);
      end loop;

      return Position;
   end Next_Word_Boundary;

end Files.UTF8;
