with Ada.Strings.Unbounded;

with Files.Applications;
with Files.Commands;
with Files.Localization;

package body Files.Command_Palette is
   use Ada.Strings.Unbounded;
   use type Files.Model.Palette_Mode;

   function Localized (Key : String) return Unbounded_String is
   begin
      if Key = "" then
         return Null_Unbounded_String;
      end if;
      return To_Unbounded_String (Files.Localization.Text (Key));
   end Localized;

   function Commands
     (Model : Files.Model.Window_Model)
      return Guikit.Command_Palette.Command_Vectors.Vector
   is
      Result : Guikit.Command_Palette.Command_Vectors.Vector;
   begin
      if Files.Model.Command_Palette_Mode_Of (Model) = Files.Model.Palette_Open_With then
         declare
            Apps : constant Files.Applications.Application_Vectors.Vector :=
              Files.Applications.Available_Applications;
            Index : Natural := 0;
         begin
            for App of Apps loop
               Index := Index + 1;
               Result.Append
                 (Guikit.Command_Palette.Command'
                    (Id          => Index,
                     Identifier  => App.Exec,
                     Label       => App.Name,
                     Description => App.Exec,
                     Shortcut    => Null_Unbounded_String,
                     Enabled     => True,
                     Icon        => Guikit.Command_Palette.No_Icon));
            end loop;
         end;
      else
         for Id in Files.Commands.Registered_Command_Id loop
            if Files.Commands.Command_Palette_Visible (Id) then
               Result.Append
                 (Guikit.Command_Palette.Command'
                    (Id          => Files.Commands.Command_Id'Pos (Id),
                     Identifier  => To_Unbounded_String (Files.Commands.Identifier (Id)),
                     Label       => Localized (Files.Commands.Name_Key (Id)),
                     Description => Localized (Files.Commands.Description_Key (Id)),
                     Shortcut    =>
                       To_Unbounded_String
                         (Files.Commands.Shortcut_Text (Files.Commands.Shortcut_For (Id))),
                     Enabled     => Files.Commands.Is_Enabled (Id, Model),
                     Icon        => Guikit.Command_Palette.No_Icon));
            end if;
         end loop;
      end if;
      return Result;
   end Commands;

end Files.Command_Palette;
