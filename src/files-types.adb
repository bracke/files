with Ada.Characters.Handling;
with Ada.Strings.Fixed;

package body Files.Types is

   function Is_Continuation (Value : Character) return Boolean is
      Code : constant Natural := Character'Pos (Value);
   begin
      return Code in 16#80# .. 16#BF#;
   end Is_Continuation;

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

end Files.Types;
