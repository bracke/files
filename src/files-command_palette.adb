with Ada.Strings.Unbounded;

with Files.Applications;
with Files.Localization;
with Files.UTF8;

with Guikit.Palette;

package body Files.Command_Palette is
   use Ada.Strings.Unbounded;
   use type Files.Model.Palette_Mode;

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
      Items   : Guikit.Palette.Item_Vectors.Vector;
   begin
      if Files.Model.Command_Palette_Mode_Of (Model) = Files.Model.Palette_Open_With then
         return Search_Applications (Query);
      end if;

      --  Build a domain-free palette item per visible command (Id carries the
      --  command's enumeration position) and let Guikit.Palette score and rank
      --  them; the ranked items are mapped back to command results below.
      for Id in Files.Commands.Registered_Command_Id loop
         if Files.Commands.Command_Palette_Visible (Id) then
            Items.Append
              (Guikit.Palette.Item'
                 (Id          => Files.Commands.Command_Id'Pos (Id),
                  Identifier  => To_Unbounded_String (Files.Commands.Identifier (Id)),
                  Label       =>
                    To_Unbounded_String (Files.Localization.Text (Files.Commands.Name_Key (Id))),
                  Description =>
                    To_Unbounded_String (Files.Localization.Text (Files.Commands.Description_Key (Id))),
                  Shortcut    => To_Unbounded_String (Files.Commands.Shortcut_Search_Text (Id)),
                  Enabled     => Files.Commands.Is_Enabled (Id, Model),
                  Score       => 0));
         end if;
      end loop;

      for Ranked of Guikit.Palette.Search (Query, Items) loop
         Results.Append
           (Result_Entry'
              (Command     => Files.Commands.Command_Id'Val (Ranked.Id),
               Identifier  => Ranked.Identifier,
               Label       => Ranked.Label,
               Description => Ranked.Description,
               Enabled     => Ranked.Enabled,
               Score       => Ranked.Score,
               others      => <>));
      end loop;

      return Results;
   end Search;

end Files.Command_Palette;
