with Ada.Strings.Unbounded;

with Files.Commands;
with Files.Commands.Status;
with Files.Localization;

package body Files.Command_Palette is
   use Ada.Strings.Unbounded;
   use type Files.Model.Palette_Mode;

   function Localized (Key : String) return Unbounded_String is
     (if Key = "" then Null_Unbounded_String else To_Unbounded_String (Files.Localization.Text (Key)));

   function Commands
     (Model        : Files.Model.Window_Model;
      Mode         : Files.Model.Palette_Mode;
      Applications : Files.Desktop_Applications.Application_Vectors.Vector)
      return Guikit.Command_Palette.Command_Vectors.Vector
   is
      Result : Guikit.Command_Palette.Command_Vectors.Vector;
   begin
      if Mode = Files.Model.Palette_Open_With then
         declare
            Index : Natural := 0;
         begin
            for App of Applications loop
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
                     --  Searched, never shown: the command's name and every
                     --  spelling of its shortcuts ("ctrl+p", "option+...", the
                     --  secondary one), so typing a shortcut finds it.
                     Identifier  =>
                       To_Unbounded_String
                         (Files.Commands.Identifier (Id) & ASCII.HT & Files.Commands.Shortcut_Search_Text (Id)),
                     Label       => Localized (Files.Commands.Name_Key (Id)),
                     Description => Localized (Files.Commands.Description_Key (Id)),
                     Shortcut    =>
                       To_Unbounded_String
                         (Files.Commands.Shortcut_Display_Text (Files.Commands.Shortcut_For (Id))),
                     Enabled     => Files.Commands.Status.Is_Enabled (Id, Model),
                     Icon        => Guikit.Command_Palette.No_Icon));
            end if;
         end loop;
      end if;
      return Result;
   end Commands;

end Files.Command_Palette;
