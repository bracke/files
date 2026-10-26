separate (Files.Controller)
function Apply_Settings_Command
  (Id            : Files.Commands.Settings_Command_Id;
   Model         : in out Files.Model.Window_Model;
   Settings      : in out Files.Settings.Settings_Model;
   Settings_Path : String)
   return Controller_Result
is
begin
   case Id is
      when Files.Commands.Save_Settings_Command =>
         return Save_Settings (Model, Settings, Settings_Path);
      when Files.Commands.Reset_Settings_Command =>
         --  The pane's Reset button: back to defaults, shortcuts included,
         --  and saved.
         if not Files.Model.Settings_Pane_Is_Open (Model) then
            return Settings_Closed_Result (Id, Model, Settings_Path);
         end if;
         Files.Settings_Form.Reset_To_Defaults (Model);
         declare
            Saved : Controller_Result := Save_Settings (Model, Settings, Settings_Path);
         begin
            Saved.Command := Id;
            return Saved;
         end;
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
            Updated  : Files.Settings.Settings_Model := Settings;

            --  Add or remove Path so it matches Favorited, toggling only when
            --  the stored state actually differs. Guarding on Is_Favorite lets
            --  the group logic leave already-correct items untouched. A
            --  favorite is any full item path; the empty path is ignored.
            procedure Set_Favorite (Path : String; Favorited : Boolean) is
            begin
               if Path /= ""
                 and then Files.Settings.Is_Favorite (Updated, Path) /= Favorited
               then
                  Files.Settings.Toggle_Favorite_Path (Updated, Path);
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
               Files.Settings.Toggle_Favorite_Path (Updated, Path);
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
                              (Updated, To_String (Item.Full_Path))
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
            --  Too many favorites to load again: refused whole (Commit_Settings).
            return Apply_Settings_Change (Id, Model, Settings, Updated, Settings_Path);
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
            return
              Apply_Settings_Change
                (Id, Model, Settings, Files.Settings.Toggle_Column (Settings, Column), Settings_Path);
         end;
      when Files.Commands.Cycle_Group_By_Command =>
         return
           Apply_Settings_Change (Id, Model, Settings, Files.Settings.Cycle_Group_By (Settings), Settings_Path);
      when Files.Commands.Clear_Recent_Command =>
         declare
            Updated : Files.Settings.Settings_Model := Settings;
            Saved   : Controller_Result;
         begin
            Files.Settings.Clear_Recent (Updated);
            Saved := Apply_Settings_Change (Id, Model, Settings, Updated, Settings_Path);
            --  Rebuild the (now empty) recent view in place so it reflects the
            --  cleared list without leaving the view or touching history.
            --  Listing clears the error line; the save's report stays on it.
            if Files.Model.In_Recent_View (Model) then
               declare
                  Reported : constant String := Files.Model.Last_Error_Key (Model);
                  Listed   : constant Files.Operations.Operation_Result :=
                    Files.Operations.Navigate_Recent (Model, Settings);
                  pragma Unreferenced (Listed);
               begin
                  Files.Model.Set_Error (Model, Reported);
               end;
            end if;
            return Saved;
         end;
   end case;
end Apply_Settings_Command;
