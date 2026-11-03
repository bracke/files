with Ada.Strings.Unbounded;

package body Files.Type_Ahead is

   use Ada.Strings.Unbounded;

   function Type_Ahead_Target
     (Names       : Files.Types.String_Vectors.Vector;
      Prefix      : String;
      Start_Index : Natural)
      return Natural
   is
      Count : constant Natural := Natural (Names.Length);
      --  Folded once, not once per candidate.
      Folded_Prefix : constant String := Files.Types.Fold_Case (Prefix);
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
            Name  : constant String := Files.Types.Fold_Case (To_String (Names (Index)));
         begin
            if Files.Types.Starts_With (Name, Folded_Prefix) then
               return Index;
            end if;
         end;
      end loop;

      return 0;
   end Type_Ahead_Target;

end Files.Type_Ahead;
