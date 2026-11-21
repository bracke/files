with Files.Text_Basics;
with Files.Text_Case;

package body Files.Type_Ahead is

   use Ada.Strings.Unbounded;

   --  Whether Name, case-folded as Files.Text_Case.Fold_Case folds it, starts
   --  with Folded_Prefix. A name whose bytes up to just past the prefix's
   --  length are ASCII folds there to their lower case, whatever follows
   --  (normalization composes a character only with a mark after it), so it
   --  is compared in place; any other name is folded whole.
   function Starts_With_Folded
     (Name          : Unbounded_String;
      Folded_Prefix : String)
      return Boolean
   is
      --  One ASCII letter lowered, any other byte kept (the bytes this is
      --  asked about are ASCII).
      function Lower_Ascii (C : Character) return Character is
        (if C in 'A' .. 'Z' then Character'Val (Character'Pos (C) + 32) else C);

      Prefix_Length : constant Natural := Folded_Prefix'Length;
      Name_Length   : constant Natural := Length (Name);
      Checked       : constant Natural := Natural'Min (Name_Length, Prefix_Length + 1);
      Prefix_Ascii  : constant Boolean := (for all C of Folded_Prefix => Character'Pos (C) < 128);
   begin
      if Prefix_Ascii and then (for all I in 1 .. Checked => Character'Pos (Element (Name, I)) < 128) then
         return Name_Length >= Prefix_Length
           and then (for all I in 1 .. Prefix_Length =>
                       Lower_Ascii (Element (Name, I))
                       = Folded_Prefix (Folded_Prefix'First + I - 1));
      end if;
      return Files.Text_Basics.Starts_With (Files.Text_Case.Fold_Case (To_String (Name)), Folded_Prefix);
   end Starts_With_Folded;

   function Type_Ahead_Target
     (Count       : Natural;
      Name_At     : not null access function (Position : Positive) return Unbounded_String;
      Prefix      : String;
      Start_Index : Natural)
      return Natural
   is
      --  Folded once, not once per candidate.
      Folded_Prefix : constant String := Files.Text_Case.Fold_Case (Prefix);
      Start : Natural;
   begin
      if Prefix = "" or else Folded_Prefix = "" or else Count = 0 then
         return 0;
      end if;

      --  Normalise the start into 1 .. Count so the wrap-around scan visits
      --  every item exactly once regardless of an out-of-range request (for
      --  example a cycling search that starts one past the final item).
      Start := (if Start_Index = 0 then 1 else ((Start_Index - 1) mod Count) + 1);

      for Offset in 0 .. Count - 1 loop
         declare
            Index : constant Positive := ((Start - 1 + Offset) mod Count) + 1;
         begin
            if Starts_With_Folded (Name_At (Index), Folded_Prefix) then
               return Index;
            end if;
         end;
      end loop;

      return 0;
   end Type_Ahead_Target;

   function Type_Ahead_Target
     (Names       : Files.Types.String_Vectors.Vector;
      Prefix      : String;
      Start_Index : Natural)
      return Natural
   is
      function Name_At (Position : Positive) return Unbounded_String is (Names (Position));
   begin
      return Type_Ahead_Target (Natural (Names.Length), Name_At'Access, Prefix, Start_Index);
   end Type_Ahead_Target;

end Files.Type_Ahead;
