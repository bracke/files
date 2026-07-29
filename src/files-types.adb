with Ada.Characters.Handling;
with Ada.Strings.Fixed;
with Files.UTF8;

package body Files.Types is

   function Is_Continuation (Value : Character) return Boolean is
      Code : constant Natural := Character'Pos (Value);
   begin
      return Code in 16#80# .. 16#BF#;
   end Is_Continuation;

   function Next_Scope (Scope : Search_Scope) return Search_Scope is
   begin
      case Scope is
         when Filter_Here =>
            return Search_Names;
         when Search_Names =>
            return Search_Contents;
         when Search_Contents =>
            return Filter_Here;
      end case;
   end Next_Scope;

   function To_Lower (Text : String) return String is
      Result : String (Text'Range);
      Index  : Integer := Text'First;
   begin
      while Index <= Text'Last loop
         if Index < Text'Last
           and then Character'Pos (Text (Index)) = 16#C3#
           and then Character'Pos (Text (Index + 1)) in 16#80# .. 16#96#
         then
            Result (Index) := Text (Index);
            Result (Index + 1) := Character'Val (Character'Pos (Text (Index + 1)) + 16#20#);
            Index := Index + 2;
         elsif Index < Text'Last
           and then Character'Pos (Text (Index)) = 16#C3#
           and then Character'Pos (Text (Index + 1)) in 16#98# .. 16#9E#
         then
            Result (Index) := Text (Index);
            Result (Index + 1) := Character'Val (Character'Pos (Text (Index + 1)) + 16#20#);
            Index := Index + 2;
         elsif Index < Text'Last
           and then Character'Pos (Text (Index)) = 16#C5#
           and then Character'Pos (Text (Index + 1)) = 16#B8#
         then
            Result (Index) := Character'Val (16#C3#);
            Result (Index + 1) := Character'Val (16#BF#);
            Index := Index + 2;
         elsif Index < Text'Last
           and then Character'Pos (Text (Index)) in 16#C2# .. 16#DF#
           and then Is_Continuation (Text (Index + 1))
         then
            Result (Index) := Text (Index);
            Result (Index + 1) := Text (Index + 1);
            Index := Index + 2;
         elsif Index <= Text'Last - 2
           and then Character'Pos (Text (Index)) in 16#E0# .. 16#EF#
           and then Is_Continuation (Text (Index + 1))
           and then Is_Continuation (Text (Index + 2))
         then
            Result (Index) := Text (Index);
            Result (Index + 1) := Text (Index + 1);
            Result (Index + 2) := Text (Index + 2);
            Index := Index + 3;
         elsif Index <= Text'Last - 3
           and then Character'Pos (Text (Index)) in 16#F0# .. 16#F4#
           and then Is_Continuation (Text (Index + 1))
           and then Is_Continuation (Text (Index + 2))
           and then Is_Continuation (Text (Index + 3))
         then
            Result (Index) := Text (Index);
            Result (Index + 1) := Text (Index + 1);
            Result (Index + 2) := Text (Index + 2);
            Result (Index + 3) := Text (Index + 3);
            Index := Index + 4;
         else
            Result (Index) := Ada.Characters.Handling.To_Lower (Text (Index));
            Index := Index + 1;
         end if;
      end loop;

      return Result;
   end To_Lower;

   function Fold_For_Sort (Text : String) return String is
      Result    : Ada.Strings.Unbounded.Unbounded_String;
      Index     : Integer := Text'First;
      Start     : Integer;
      Codepoint : Natural := 0;

      --  The base ASCII letter(s) for a codepoint, or "" when it has none (a
      --  non-letter, or a script with no Latin base -- the caller keeps those
      --  as they are). Upper and lower case fold to the same lowercase base.
      function Base_Letter (Value : Natural) return String is
      begin
         case Value is
            when 16#41# .. 16#5A#           => return [1 => Character'Val (Value + 16#20#)];
            when 16#C0# .. 16#C5# | 16#E0# .. 16#E5# | 16#100# .. 16#105# => return "a";
            when 16#C6# | 16#E6#            => return "ae";
            when 16#C7# | 16#E7# | 16#106# .. 16#10D# => return "c";
            when 16#D0# | 16#F0# | 16#10E# .. 16#111# => return "d";
            when 16#C8# .. 16#CB# | 16#E8# .. 16#EB# | 16#112# .. 16#11B# => return "e";
            when 16#11C# .. 16#123#         => return "g";
            when 16#124# .. 16#127#         => return "h";
            when 16#CC# .. 16#CF# | 16#EC# .. 16#EF# | 16#128# .. 16#131# => return "i";
            when 16#134# | 16#135#          => return "j";
            when 16#136# | 16#137#          => return "k";
            when 16#139# .. 16#142#         => return "l";
            when 16#D1# | 16#F1# | 16#143# .. 16#14B# => return "n";
            when 16#D2# .. 16#D6# | 16#F2# .. 16#F6# | 16#D8# | 16#F8#
               | 16#14C# .. 16#151#         => return "o";
            when 16#152# | 16#153#          => return "oe";
            when 16#154# .. 16#159#         => return "r";
            when 16#15A# .. 16#161#         => return "s";
            when 16#162# .. 16#167#         => return "t";
            when 16#DE# | 16#FE#            => return "th";
            when 16#D9# .. 16#DC# | 16#F9# .. 16#FC# | 16#168# .. 16#173# => return "u";
            when 16#174# | 16#175#          => return "w";
            when 16#DD# | 16#FD# | 16#FF# | 16#176# .. 16#178# => return "y";
            when 16#179# .. 16#17E#         => return "z";
            when 16#DF#                     => return "ss";
            when others                     => return "";
         end case;
      end Base_Letter;
   begin
      while Index <= Text'Last loop
         Start := Index;
         Files.UTF8.Decode_Next_Codepoint (Text, Index, Codepoint);

         declare
            Folded : constant String := Base_Letter (Codepoint);
         begin
            if Folded /= "" then
               Ada.Strings.Unbounded.Append (Result, Folded);
            elsif Codepoint < 16#80# then
               Ada.Strings.Unbounded.Append
                 (Result, Ada.Characters.Handling.To_Lower (Text (Start)));
            else
               --  Unmapped non-ASCII: keep its own bytes so its order is stable.
               Ada.Strings.Unbounded.Append (Result, Text (Start .. Index - 1));
            end if;
         end;
      end loop;

      return Ada.Strings.Unbounded.To_String (Result);
   end Fold_For_Sort;

   function Contains_Case_Insensitive
     (Haystack : String;
      Needle   : String)
      return Boolean
   is
   begin
      if Needle = "" then
         return True;
      end if;

      return Ada.Strings.Fixed.Index (To_Lower (Haystack), To_Lower (Needle)) > 0;
   end Contains_Case_Insensitive;

   function Move_Column
     (Order    : Detail_Column_Order;
      Column   : Detail_Column;
      To_Index : Detail_Column_Index)
      return Detail_Column_Order
   is
      Target  : Detail_Column_Index := To_Index;
      From    : Detail_Column_Index := Detail_Column_Index'First;
      Found   : Boolean := False;
      Reduced : Detail_Column_Order;
      Count   : Natural := 0;
      Result  : Detail_Column_Order;
      Read    : Natural := 0;
   begin
      --  Name is pinned to the first slot and never moves; nor may any column
      --  displace it from the first slot.
      if Column = Name_Column then
         return Order;
      elsif Target < Detail_Column_Index'First + 1 then
         Target := Detail_Column_Index'First + 1;
      end if;

      --  Collect the order minus Column into Reduced, recording Column's slot.
      for Index in Order'Range loop
         if Order (Index) = Column then
            From := Index;
            Found := True;
         else
            Count := Count + 1;
            Reduced (Count) := Order (Index);
         end if;
      end loop;

      if not Found or else From = Target then
         return Order;
      end if;

      --  Re-emit the reduced sequence, inserting Column at the target slot.
      for Index in Result'Range loop
         if Index = Target then
            Result (Index) := Column;
         else
            Read := Read + 1;
            Result (Index) := Reduced (Read);
         end if;
      end loop;

      return Result;
   end Move_Column;

end Files.Types;
