with Ada.Strings.Unbounded;

with Files.Types;

package body Files.Type_Ahead is

   use Ada.Strings.Unbounded;

   function Starts_With_Case_Insensitive
     (Name   : String;
      Prefix : String)
      return Boolean
   is
      Lower_Name   : constant String := Files.Types.To_Lower (Name);
      Lower_Prefix : constant String := Files.Types.To_Lower (Prefix);
   begin
      if Lower_Prefix = "" then
         return False;
      elsif Lower_Name'Length < Lower_Prefix'Length then
         return False;
      else
         return Lower_Name (Lower_Name'First .. Lower_Name'First + Lower_Prefix'Length - 1) = Lower_Prefix;
      end if;
   end Starts_With_Case_Insensitive;

   function Type_Ahead_Target
     (Items       : Files.File_System.Item_Vectors.Vector;
      Prefix      : String;
      Start_Index : Natural)
      return Natural
   is
      Count : constant Natural := Natural (Items.Length);
      Start : Natural;
   begin
      if Prefix = "" or else Count = 0 then
         return 0;
      end if;

      --  Normalise the start into 1 .. Count so the wrap-around scan visits
      --  every item exactly once regardless of an out-of-range request (for
      --  example a cycling search that starts one past the final item).
      Start := (if Start_Index = 0 then 1 else ((Start_Index - 1) mod Count) + 1);

      for Offset in 0 .. Count - 1 loop
         declare
            Index : constant Positive := ((Start - 1 + Offset) mod Count) + 1;
            Name  : constant String := To_String (Items.Element (Index).Name);
         begin
            if Starts_With_Case_Insensitive (Name, Prefix) then
               return Index;
            end if;
         end;
      end loop;

      return 0;
   end Type_Ahead_Target;

end Files.Type_Ahead;
