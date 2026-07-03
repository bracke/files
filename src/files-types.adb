with Ada.Characters.Handling;
with Ada.Strings.Fixed;

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
