separate (Files.Controller)
function Apply_Settings_Command
  (Id            : Files.Commands.Settings_Command_Id;
   Model         : in out Files.Model.Window_Model;
   Settings      : in out Files.Settings.Settings_Model;
   Settings_Path : String)
   return Controller_Result
is
   Executed : constant Controller_Result := Make_Result (Controller_Command_Executed, Id);
begin
   case Id is
      when Files.Commands.Save_Settings_Command =>
         return Save_Settings (Model, Settings, Settings_Path);
      when Files.Commands.Toggle_Hidden_Files_Command =>
         return Toggle_Hidden_Files (Model, Settings, Settings_Path);
      when Files.Commands.Toggle_Show_Extensions_Command =>
         return Toggle_Show_Extensions (Model, Settings, Settings_Path);
      when Files.Commands.Toggle_Free_Space_Display_Command =>
         return Toggle_Free_Space_Display (Model, Settings, Settings_Path);
      when Files.Commands.Toggle_Favorite_Command =>
         declare
            Selected : constant Files.File_System.Item_Vectors.Vector :=
              Files.Model.Selected_Items (Model);
            Before   : constant Files.Settings.Settings_Model := Settings;
            Changed  : Boolean := False;

            --  Add or remove Path so it matches Favorited, toggling only when
            --  the stored state actually differs. Guarding on Is_Favorite lets
            --  the group logic leave already-correct items untouched. A
            --  favorite is any full item path; the empty path is ignored.
            procedure Set_Favorite (Path : String; Favorited : Boolean) is
            begin
               if Path /= ""
                 and then Files.Settings.Is_Favorite (Settings, Path) /= Favorited
               then
                  Files.Settings.Toggle_Favorite_Path (Settings, Path);
                  Changed := True;
               end if;
            end Set_Favorite;

            --  Unconditionally flip Path's favorite state. Used for the
            --  single-item and folder-fallback cases where the intent is a
            --  plain toggle. The empty path is ignored.
            procedure Toggle_One (Path : String) is
            begin
               if Path = "" then
                  return;
               end if;
               Files.Settings.Toggle_Favorite_Path (Settings, Path);
               Changed := True;
            end Toggle_One;
         begin
            if Selected.Is_Empty then
               --  No selection: fall back to favoriting the current folder,
               --  preserving the historical "bookmark this folder" behavior.
               Toggle_One (Files.Model.Current_Path (Model));
            elsif Natural (Selected.Length) = 1 then
               --  Single selection: plain toggle of that one item's path.
               Toggle_One (To_String (Selected.First_Element.Full_Path));
            else
               --  Multi-select group toggle: if every selected item is
               --  already a favorite, remove them all; otherwise add every
               --  not-yet-favorited item and leave the already-favorited
               --  ones starred. Net effect: one invocation reliably stars a
               --  whole (even mixed) selection; the next un-stars it.
               declare
                  All_Favorited : Boolean := True;
               begin
                  for Item of Selected loop
                     if not Files.Settings.Is_Favorite
                              (Settings, To_String (Item.Full_Path))
                     then
                        All_Favorited := False;
                     end if;
                  end loop;
                  for Item of Selected loop
                     Set_Favorite
                       (To_String (Item.Full_Path), not All_Favorited);
                  end loop;
               end;
            end if;
            if Changed and then not Files.Settings.Loadable (Settings) then
               --  Too many favorites to load again: refuse the toggle whole.
               Settings := Before;
               Files.Model.Set_Error (Model, "error.settings.full");
            elsif Changed then
               Persist_Settings (Model, Settings, Settings_Path);
            end if;
            return Executed;
         end;
      when Files.Commands.Toggle_Column_Modified_Command
         | Files.Commands.Toggle_Column_Size_Command
         | Files.Commands.Toggle_Column_Type_Command
         | Files.Commands.Toggle_Column_Created_Command
         | Files.Commands.Toggle_Column_Permissions_Command =>
         declare
            Column : constant Files.Types.Detail_Column :=
              (case Id is
                  when Files.Commands.Toggle_Column_Modified_Command =>
                     Files.Types.Modified_Column,
                  when Files.Commands.Toggle_Column_Size_Command =>
                     Files.Types.Size_Column,
                  when Files.Commands.Toggle_Column_Type_Command =>
                     Files.Types.Filetype_Column,
                  when Files.Commands.Toggle_Column_Created_Command =>
                     Files.Types.Created_Column,
                  when others =>
                     Files.Types.Permissions_Column);
         begin
            Settings := Files.Settings.Toggle_Column (Settings, Column);
            Persist_Settings (Model, Settings, Settings_Path);
            return Executed;
         end;
      when Files.Commands.Cycle_Group_By_Command =>
         Settings := Files.Settings.Cycle_Group_By (Settings);
         Persist_Settings (Model, Settings, Settings_Path);
         return Executed;
      when Files.Commands.Clear_Recent_Command =>
         Files.Settings.Clear_Recent (Settings);
         Persist_Settings (Model, Settings, Settings_Path);
         --  Rebuild the (now empty) recent view in place so it reflects the
         --  cleared list without leaving the view or touching history.
         if Files.Model.In_Recent_View (Model) then
            return
              Make_Result
                (Controller_Command_Executed, Id, Files.Operations.Navigate_Recent (Model, Settings));
         end if;
         return Executed;
   end case;
end Apply_Settings_Command;
