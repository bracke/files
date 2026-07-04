package body Files.Gui.Utf8 is

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

   function Is_Combining_Codepoint
     (Codepoint : Natural)
      return Boolean is
   begin
      return Is_Required_Zero_Width_Codepoint (Codepoint)
        or else Codepoint in 16#FE00# .. 16#FE0F#
        or else Codepoint in 16#E0100# .. 16#E01EF#;
   end Is_Combining_Codepoint;

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

end Files.Gui.Utf8;
