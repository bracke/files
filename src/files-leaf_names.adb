with Files.Text_Basics;
with Files.Text_Encoding;
with Guikit.Utf8;

package body Files.Leaf_Names is

   --  The longest extension Fit keeps whole: anything longer after the last
   --  dot is part of the name, not a type a program opens it by.
   Max_Extension : constant := 32;

   function Length_Under
     (Name : String;
      Unit : Hostkit.Fs.Name_Length_Unit)
      return Natural
   is
      Units : Natural := 0;
   begin
      if Unit = Hostkit.Fs.Bytes or else not Guikit.Utf8.Is_Valid (Name) then
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
     (Head : String;
      Tail : String;
      Room : Natural;
      Unit : Hostkit.Fs.Name_Length_Unit := Hostkit.Fs.Bytes)
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
         while Last >= Head'First and then Last < Head'Last
           and then Files.Text_Encoding.Is_Continuation_Byte (Head (Last + 1))
         loop
            Last := Last - 1;
         end loop;
      end Back_Off;
   begin
      Back_Off;
      while Last >= Head'First and then Length_Under (Head (Head'First .. Last) & Tail, Unit) > Room loop
         Last := Last - 1;
         Back_Off;
      end loop;
      return Head (Head'First .. Last) & Tail;
   end Cut;

   function Fit
     (Name   : String;
      Room   : Natural;
      Unit   : Hostkit.Fs.Name_Length_Unit := Hostkit.Fs.Bytes;
      Insert : String := "")
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
      return Cut (Name (Name'First .. Dot - 1), Insert & Name (Dot .. Name'Last), Room, Unit);
   end Fit;

   function Counted_Marker (Word : String; Attempt : Natural) return String is
     (if Attempt <= 1 then " (" & Word & ")" else " (" & Word & " " & Files.Text_Basics.Natural_Text (Attempt) & ")");

   function Numbered_Marker (Attempt : Natural) return String is
     (if Attempt = 0 then "" else " (" & Files.Text_Basics.Natural_Text (Attempt) & ")");

   function Spaced_Number (Attempt : Natural) return String is
     (if Attempt <= 1 then "" else " " & Files.Text_Basics.Natural_Text (Attempt));

   function Dotted_Number (Attempt : Natural) return String is
     (if Attempt <= 1 then "" else "." & Files.Text_Basics.Natural_Text (Attempt));

   function Candidate
     (Stem      : String;
      Extension : String;
      Marker    : String;
      Limit     : Hostkit.Fs.Leaf_Name_Limit;
      Place     : Marker_Place := Before_Extension)
      return String
   is
      Dotted : constant String := (if Extension = "" then "" else "." & Extension);
   begin
      if Place = After_Name then
         return Fit
           (Stem & Dotted,
            Limit.Most - Natural'Min (Limit.Most, Length_Under (Marker, Limit.Unit)),
            Limit.Unit)
           & Marker;
      end if;
      declare
         Shortened : constant String := Cut (Stem, Marker & Dotted, Limit.Most, Limit.Unit);
      begin
         if not Too_Long_Under (Shortened, Limit) then
            return Shortened;
         end if;
         --  An extension too long to keep with the marker is name, not type.
         return Fit (Stem & Dotted, Limit.Most, Limit.Unit, Insert => Marker);
      end;
   end Candidate;

   function First_Free
     (Stem      : String;
      Extension : String;
      Marker    : not null access function (Attempt : Natural) return String;
      Taken     : not null access function (Leaf : String) return Boolean;
      Limit     : Hostkit.Fs.Leaf_Name_Limit;
      First     : Natural := 1;
      Place     : Marker_Place := Before_Extension)
      return String is
   begin
      for Attempt in First .. Max_Attempts loop
         declare
            Name : constant String := Candidate (Stem, Extension, Marker (Attempt), Limit, Place);
         begin
            if not Taken (Name) then
               return Name;
            end if;
         end;
      end loop;
      return "";
   end First_Free;

end Files.Leaf_Names;
