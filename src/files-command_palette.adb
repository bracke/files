with Ada.Strings.Unbounded;

with Files.Applications;
with Files.Localization;
with Files.UTF8;

package body Files.Command_Palette is
   use Ada.Strings.Unbounded;
   use type Files.Model.Palette_Mode;

   No_Match_Score : constant Natural := Natural'Last;

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
            Separator_Length := Files.UTF8.Whitespace_Separator_Length (Query, Position);
            exit when Separator_Length = 0;
            Position := Natural'Min (Position + Separator_Length, Query'Length);
         end loop;

         exit when Position >= Query'Length;

         Last := Position;
         while Last < Query'Length and then Files.UTF8.Whitespace_Separator_Length (Query, Last) = 0 loop
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
            Separator_Length : constant Natural := Files.UTF8.Whitespace_Separator_Length (Query, Position);
         begin
            if Separator_Length = 0 then
               return True;
            end if;
            Position := Natural'Min (Position + Separator_Length, Query'Length);
         end;
      end loop;

      return False;
   end Has_Query_Token;

   --  Build palette results from the installed applications for the "Open With"
   --  picker, filtered by a case-insensitive substring match on the query.
   function Search_Applications
     (Query : String)
      return Result_Vectors.Vector
   is
      Applications : constant Files.Applications.Application_Vectors.Vector :=
        Files.Applications.Available_Applications;
      Results  : Result_Vectors.Vector;
      Position : Natural := 0;
   begin
      for App of Applications loop
         declare
            Name : constant String := To_String (App.Name);
            Exec : constant String := To_String (App.Exec);
         begin
            if not Has_Query_Token (Query)
              or else Files.Types.Contains_Case_Insensitive (Name, Query)
            then
               Position := Position + 1;
               Results.Append
                 (Result_Entry'
                    (Command          => Files.Commands.No_Command,
                     Identifier       => To_Unbounded_String (Exec),
                     Label            => App.Name,
                     Description      => App.Exec,
                     Enabled          => True,
                     Score            => Position,
                     Is_Application   => True,
                     Application_Name => App.Name,
                     Application_Exec => App.Exec));
            end if;
         end;
      end loop;

      return Results;
   end Search_Applications;

   function Search
     (Query : String;
      Model : Files.Model.Window_Model)
      return Result_Vectors.Vector
   is
      Results : Result_Vectors.Vector;
      Has_Token : constant Boolean := Has_Query_Token (Query);
   begin
      if Files.Model.Command_Palette_Mode_Of (Model) = Files.Model.Palette_Open_With then
         return Search_Applications (Query);
      end if;

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
                      Score      => Saturating_Score (Base_Score, Registry_Index),
                      others     => <>));
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
