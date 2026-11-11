with Files.UTF8;

package body Files.Leaf_Names is

   --  The longest extension Fit keeps whole: anything longer after the last
   --  dot is part of the name, not a type a program opens it by.
   Max_Extension : constant := 32;

   function Is_Continuation (Item : Character) return Boolean is
     (Character'Pos (Item) in 16#80# .. 16#BF#);

   function Length_Under
     (Name      : String;
      Dos_Rules : Boolean)
      return Natural
   is
      Units : Natural := 0;
   begin
      if not Dos_Rules or else not Files.UTF8.Is_Valid (Name) then
         return Name'Length;
      end if;
      for Item of Name loop
         case Character'Pos (Item) is
            when 16#80# .. 16#BF# =>
               --  A continuation byte adds nothing to its character's units.
               null;
            when 16#F0# .. 16#FF# =>
               --  A character beyond the Basic Multilingual Plane is a
               --  surrogate pair in UTF-16.
               Units := Units + 2;
            when others =>
               Units := Units + 1;
         end case;
      end loop;
      return Units;
   end Length_Under;

   function Cut
     (Head      : String;
      Tail      : String;
      Room      : Natural;
      Dos_Rules : Boolean := False)
      return String
   is
      --  A prefix of more than three bytes per unit of Room cannot fit (no
      --  character takes more than three bytes per UTF-16 unit), so the
      --  search starts there rather than at the end of a long Head.
      Last : Natural :=
        (if Room >= Head'Length then Head'Last
         else Head'First - 1 + Natural'Min (Head'Length, 3 * Room));

      --  Move Last back so the prefix ends with a whole character.
      procedure Back_Off is
      begin
         while Last >= Head'First and then Last < Head'Last and then Is_Continuation (Head (Last + 1)) loop
            Last := Last - 1;
         end loop;
      end Back_Off;
   begin
      Back_Off;
      while Last >= Head'First and then Length_Under (Head (Head'First .. Last) & Tail, Dos_Rules) > Room loop
         Last := Last - 1;
         Back_Off;
      end loop;
      return Head (Head'First .. Last) & Tail;
   end Cut;

   function Fit
     (Name      : String;
      Room      : Natural;
      Dos_Rules : Boolean := False;
      Insert    : String := "")
      return String
   is
      Dot : Natural := 0;
   begin
      for Index in reverse Name'Range loop
         if Name (Index) = '.' then
            Dot := Index;
            exit;
         end if;
      end loop;
      if Dot <= Name'First or else Name'Last - Dot + 1 > Max_Extension then
         Dot := Name'Last + 1;
      end if;
      return Cut (Name (Name'First .. Dot - 1), Insert & Name (Dot .. Name'Last), Room, Dos_Rules);
   end Fit;

end Files.Leaf_Names;
