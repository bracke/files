with Ada.Strings.Unbounded;

with Files.Localization;

package body Files.Command_Palette is
   use Ada.Strings.Unbounded;

   No_Match_Score : constant Natural := Natural'Last;

   function Is_Query_Separator (Value : Character) return Boolean is
   begin
      return Value = ' '
        or else Value = ASCII.HT
        or else Value = ASCII.LF
        or else Value = ASCII.CR
        or else Value = ASCII.VT
        or else Value = ASCII.FF
        or else Character'Pos (Value) = 133;
   end Is_Query_Separator;

   function Query_Separator_Length
     (Query    : String;
      Position : Natural)
      return Natural
   is
      Index : constant Natural := Query'First + Position;
      B1    : Natural;
      B2    : Natural;
      B3    : Natural;
   begin
      if Position >= Query'Length then
         return 0;
      elsif Is_Query_Separator (Query (Index)) then
         return 1;
      end if;

      B1 := Character'Pos (Query (Index));
      if B1 = 16#C2# and then Position + 1 < Query'Length then
         B2 := Character'Pos (Query (Index + 1));
         if B2 = 16#85# or else B2 = 16#A0# then
            return 2;
         end if;
      elsif B1 = 16#E1# and then Position + 2 < Query'Length then
         B2 := Character'Pos (Query (Index + 1));
         B3 := Character'Pos (Query (Index + 2));
         if B2 = 16#9A# and then B3 = 16#80# then
            return 3;
         end if;
      elsif B1 = 16#E2# and then Position + 2 < Query'Length then
         B2 := Character'Pos (Query (Index + 1));
         B3 := Character'Pos (Query (Index + 2));
         if B2 = 16#80#
           and then (B3 in 16#80# .. 16#8A# or else B3 = 16#A8# or else B3 = 16#A9# or else B3 = 16#AF#)
         then
            return 3;
         elsif B2 = 16#81# and then B3 = 16#9F# then
            return 3;
         end if;
      elsif B1 = 16#E3# and then Position + 2 < Query'Length then
         B2 := Character'Pos (Query (Index + 1));
         B3 := Character'Pos (Query (Index + 2));
         if B2 = 16#80# and then B3 = 16#80# then
            return 3;
         end if;
      end if;

      return 0;
   end Query_Separator_Length;

   function Field_Score
     (Field : String;
      Token : String;
      Base  : Natural)
      return Natural
   is
      Lower_Field : constant String := Files.Types.To_Lower (Field);
      Lower_Token : constant String := Files.Types.To_Lower (Token);
   begin
      if Lower_Field = Lower_Token then
         return Base;
      elsif Lower_Field'Length >= Lower_Token'Length
        and then Lower_Field (Lower_Field'First .. Lower_Field'First + Lower_Token'Length - 1) = Lower_Token
      then
         return Base + 10;
      elsif Files.Types.Contains_Case_Insensitive (Field, Token) then
         return Base + 20;
      else
         return No_Match_Score;
      end if;
   end Field_Score;

   function Saturating_Add
     (Left  : Natural;
      Right : Natural)
      return Natural is
   begin
      if Natural'Last - Left < Right then
         return Natural'Last;
      end if;

      return Left + Right;
   end Saturating_Add;

   function Saturating_Score
     (Base_Score     : Natural;
      Registry_Index : Natural)
      return Natural
   is
      Scale : constant Natural := 100;
   begin
      if Base_Score > Natural'Last / Scale then
         return Natural'Last;
      end if;

      return Saturating_Add (Base_Score * Scale, Registry_Index);
   end Saturating_Score;

   function Query_Score
     (Identifier  : String;
      Label       : String;
      Description : String;
      Shortcuts   : String;
      Query       : String)
      return Natural
   is
      Position : Natural := 0;
      Last     : Natural;
      Separator_Length : Natural;
      Score    : Natural := 0;
   begin
      if Query = "" then
         return 0;
      end if;

      while Position < Query'Length loop
         loop
            Separator_Length := Query_Separator_Length (Query, Position);
            exit when Separator_Length = 0;
            Position := Natural'Min (Position + Separator_Length, Query'Length);
         end loop;

         exit when Position >= Query'Length;

         Last := Position;
         while Last < Query'Length and then Query_Separator_Length (Query, Last) = 0 loop
            Last := Last + 1;
         end loop;

         declare
            Token : constant String := Query (Query'First + Position .. Query'First + Last - 1);
            Token_Score : constant Natural :=
              Natural'Min
                 (Field_Score (Identifier, Token, 0),
                 Natural'Min
                   (Field_Score (Label, Token, 100),
                    Natural'Min
                      (Field_Score (Description, Token, 200),
                       Field_Score (Shortcuts, Token, 300))));
         begin
            if Token_Score = No_Match_Score then
               return No_Match_Score;
            end if;
            Score := Saturating_Add (Score, Token_Score);
         end;

         Position := Last;
      end loop;

      return Score;
   end Query_Score;

   function Has_Query_Token (Query : String) return Boolean is
      Position : Natural := 0;
   begin
      while Position < Query'Length loop
         declare
            Separator_Length : constant Natural := Query_Separator_Length (Query, Position);
         begin
            if Separator_Length = 0 then
               return True;
            end if;
            Position := Natural'Min (Position + Separator_Length, Query'Length);
         end;
      end loop;

      return False;
   end Has_Query_Token;

   function Search
     (Query : String;
      Model : Files.Model.Window_Model)
      return Result_Vectors.Vector
   is
      Results : Result_Vectors.Vector;
      Has_Token : constant Boolean := Has_Query_Token (Query);
   begin
      for Id in Files.Commands.Registered_Command_Id loop
         if Files.Commands.Command_Palette_Visible (Id) then
            declare
               Identifier : constant String := Files.Commands.Identifier (Id);
               Label      : constant String :=
                 Files.Localization.Text (Files.Commands.Name_Key (Id));
               Description : constant String :=
                 Files.Localization.Text (Files.Commands.Description_Key (Id));
               Shortcuts : constant String := Files.Commands.Shortcut_Search_Text (Id);
               Base_Score : constant Natural :=
                 Query_Score (Identifier, Label, Description, Shortcuts, Query);
               Registry_Index : constant Natural :=
                 Files.Commands.Command_Id'Pos (Id) - Files.Commands.Command_Id'Pos
                   (Files.Commands.Registered_Command_Id'First);
            begin
               if Base_Score /= No_Match_Score then
                  Results.Append
                    (Result_Entry'(Command    => Id,
                      Identifier => To_Unbounded_String (Identifier),
                      Label      => To_Unbounded_String (Label),
                      Description => To_Unbounded_String (Description),
                      Enabled    => Files.Commands.Is_Enabled (Id, Model),
                      Score      => Saturating_Score (Base_Score, Registry_Index)));
               end if;
            end;
         end if;
      end loop;

      if Has_Token then
         declare
            function Less (Left, Right : Result_Entry) return Boolean is
            begin
               return Left.Score < Right.Score;
            end Less;

            package Sorting is new Result_Vectors.Generic_Sorting
              ("<" => Less);
         begin
            Sorting.Sort (Results);
         end;
      end if;

      return Results;
   end Search;

end Files.Command_Palette;
