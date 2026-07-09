with Ada.Strings.Unbounded;

with Files.File_System;
with Files.Operations;

package body Files.Interaction is

   use Ada.Strings.Unbounded;
   use type Files.Commands.Command_Id;
   use type Files.Controller.Controller_Status;
   use type Files.Model.Tree_Pick_Mode;
   use type Files.Model.Palette_Mode;
   use type Files.Operations.Operation_Status;
   use type Files.Types.Focus_Target;
   use type Guikit.Input.Key_Code;

   --  Map the model's runtime sort enum onto the settings enum.
   function Settings_Sort_Of
     (Field : Files.Model.Sort_Field) return Files.Settings.Sort_Field is
   begin
      case Field is
         when Files.Model.Sort_Name     => return Files.Settings.Sort_By_Name;
         when Files.Model.Sort_Type     => return Files.Settings.Sort_By_Filetype;
         when Files.Model.Sort_Size     => return Files.Settings.Sort_By_Size;
         when Files.Model.Sort_Created  => return Files.Settings.Sort_By_Created;
         when Files.Model.Sort_Changed  => return Files.Settings.Sort_By_Modified;
      end case;
   end Settings_Sort_Of;

   procedure Persist_Settings
     (Settings      : Files.Settings.Settings_Model;
      Settings_Path : String)
   is
      Saved : Files.Settings.Settings_Write_Result;
   begin
      if Settings_Path = "" then
         return;
      end if;
      Saved := Files.Settings.Save_Text (Settings_Path, Files.Settings.To_Text (Settings));
      pragma Unreferenced (Saved);
   end Persist_Settings;

   --  Fold any paths the model queued while opening items into the persisted
   --  recent list and write the settings. A no-op when nothing was opened, so it
   --  is safe to call after every dispatch seam (open routes through several).
   procedure Persist_Recent_Opens
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Result        : in out Interaction_Result)
   is
      Opened : constant Files.Types.String_Vectors.Vector :=
        Files.Model.Take_Recent_Opens (Model);
   begin
      if Opened.Is_Empty then
         return;
      end if;
      for Path of Opened loop
         Files.Settings.Note_Recent (Settings, To_String (Path));
      end loop;
      Persist_Settings (Settings, Settings_Path);
      Result.Settings_Changed := True;
   end Persist_Recent_Opens;

   --  Copy the user-visible global UI state from the model into the settings
   --  record and persist it. Called whenever a runtime command flips one of the
   --  persisted toggles. Returns True when a change was written.
   function Sync_Global_UI_State
     (Model         : Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Boolean
   is
      use type Files.Types.View_Mode;
      use type Files.Settings.Sort_Field;

      New_View  : constant Files.Types.View_Mode :=
        Files.Model.View_Mode_Of (Model);
      New_Sort  : constant Files.Settings.Sort_Field :=
        Settings_Sort_Of (Files.Model.Sort_Field_Of (Model));
      New_Asc   : constant Boolean :=
        Files.Model.Sort_Is_Ascending (Model);
      New_Info  : constant Boolean :=
        Files.Model.Info_Pane_Is_Open (Model);
      Changed   : constant Boolean :=
        Settings.Default_View /= New_View
        or else Settings.Sort_Field_Value /= New_Sort
        or else Settings.Sort_Ascending /= New_Asc
        or else Settings.Info_Pane_Open /= New_Info;
   begin
      if not Changed then
         return False;
      end if;

      Settings.Default_View := New_View;
      Settings.Sort_Field_Value := New_Sort;
      Settings.Sort_Ascending := New_Asc;
      Settings.Info_Pane_Open := New_Info;
      Persist_Settings (Settings, Settings_Path);
      return True;
   end Sync_Global_UI_State;

   procedure Execute_Command
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Command           : Files.Commands.Command_Id;
      Current_Font_Size : Positive;
      Modifiers         : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result            : out Interaction_Result)
   is
      Outcome : Files.Controller.Controller_Result;
   begin
      Result.Command := Command;

      if not Files.Commands.Is_Enabled (Command, Model) then
         Outcome := Files.Controller.Execute_Command (Command, Model, Settings, Modifiers);
         Result.Status := Outcome.Status;
         Result.Command_Executed := Outcome.Status = Files.Controller.Controller_Command_Executed;
         return;
      end if;

      case Command is
         when Files.Commands.Save_Settings_Command =>
            Outcome :=
              Files.Controller.Save_Settings (Model, Settings, Settings_Path);
            Result.Settings_Changed := True;
            --  Apply a font-size change made in the settings pane live, the same
            --  way Ctrl+scroll / Ctrl+= zoom does: signal the shell to sync the
            --  runtime size and invalidate the glyph cache so text re-rasterizes
            --  now rather than only on the next launch.
            if Settings.Font_Pixel_Size /= Current_Font_Size then
               Result.Font_Size_Changed := True;
               Result.Needs_Glyph_Rebuild := True;
            end if;
         when Files.Commands.Toggle_Hidden_Files_Command =>
            Outcome :=
              Files.Controller.Toggle_Hidden_Files (Model, Settings, Settings_Path);
            Result.Settings_Changed := True;
            Result.Directory_Reloaded := True;
         when Files.Commands.Toggle_Show_Extensions_Command =>
            Outcome :=
              Files.Controller.Toggle_Show_Extensions (Model, Settings, Settings_Path);
            Result.Settings_Changed := True;
         when Files.Commands.Toggle_Favorite_Command =>
            declare
               Selected : constant Files.File_System.Item_Vectors.Vector :=
                 Files.Model.Selected_Items (Model);
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
               if Changed then
                  Persist_Settings (Settings, Settings_Path);
                  Result.Settings_Changed := True;
               end if;
               Outcome :=
                 (Status => Files.Controller.Controller_Command_Executed, others => <>);
            end;
         when Files.Commands.Toggle_Column_Modified_Command
            | Files.Commands.Toggle_Column_Size_Command
            | Files.Commands.Toggle_Column_Type_Command
            | Files.Commands.Toggle_Column_Created_Command
            | Files.Commands.Toggle_Column_Permissions_Command =>
            declare
               Column : constant Files.Types.Detail_Column :=
                 (case Command is
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
               Persist_Settings (Settings, Settings_Path);
               Result.Settings_Changed := True;
               Outcome :=
                 (Status => Files.Controller.Controller_Command_Executed, others => <>);
            end;
         when Files.Commands.Cycle_Group_By_Command =>
            Settings := Files.Settings.Cycle_Group_By (Settings);
            Persist_Settings (Settings, Settings_Path);
            Result.Settings_Changed := True;
            Outcome :=
              (Status => Files.Controller.Controller_Command_Executed, others => <>);
         when Files.Commands.Clear_Recent_Command =>
            Files.Settings.Clear_Recent (Settings);
            Persist_Settings (Settings, Settings_Path);
            Result.Settings_Changed := True;
            --  Rebuild the (now empty) recent view in place so it reflects the
            --  cleared list without leaving the view or touching history.
            if Files.Model.In_Recent_View (Model) then
               declare
                  Rebuilt : constant Files.Operations.Operation_Result :=
                    Files.Operations.Navigate_Recent (Model, Settings);
                  pragma Unreferenced (Rebuilt);
               begin
                  Result.Directory_Reloaded := True;
               end;
            end if;
            Outcome :=
              (Status => Files.Controller.Controller_Command_Executed, others => <>);
         when others =>
            Outcome := Files.Controller.Execute_Command (Command, Model, Settings, Modifiers);
      end case;

      case Command is
         when Files.Commands.Select_Small_Icons_Command
            | Files.Commands.Select_Large_Icons_Command
            | Files.Commands.Select_Details_Command
            | Files.Commands.Sort_By_Name_Command
            | Files.Commands.Sort_By_Size_Command
            | Files.Commands.Sort_By_Type_Command
            | Files.Commands.Sort_By_Created_Command
            | Files.Commands.Sort_By_Changed_Command
            | Files.Commands.Toggle_Info_Pane_Command =>
            if Sync_Global_UI_State (Model, Settings, Settings_Path) then
               Result.Settings_Changed := True;
            end if;
         when others =>
            null;
      end case;

      --  A sort change reorders the listing. The renderer re-sorts the snapshot
      --  for display, but the model's item order (used by keyboard navigation)
      --  is the load order, so re-list the directory to keep them in sync.
      --  Sync above has already updated the settings sort field that Refresh uses.
      case Command is
         when Files.Commands.Sort_By_Name_Command
            | Files.Commands.Sort_By_Size_Command
            | Files.Commands.Sort_By_Type_Command
            | Files.Commands.Sort_By_Created_Command
            | Files.Commands.Sort_By_Changed_Command =>
            declare
               Reloaded : constant Files.Operations.Operation_Result :=
                 Files.Operations.Refresh (Model, Settings);
               pragma Unreferenced (Reloaded);
            begin
               null;
            end;
            Result.Directory_Reloaded := True;
         when others =>
            null;
      end case;

      Result.Status := Outcome.Status;
      Result.Command_Executed := Outcome.Status = Files.Controller.Controller_Command_Executed;
   end Execute_Command;

   procedure Handle_Key
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Key               : Guikit.Input.Key_Code;
      Modifiers         : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Current_Font_Size : Positive;
      Result            : out Interaction_Result)
   is
      --  Ctrl (Shift allowed for '+') without Alt/Meta drives keyboard zoom.
      Zoom_Modifier : constant Boolean :=
        Modifiers (Guikit.Input.Control_Key)
          and then not Modifiers (Guikit.Input.Alt_Key)
          and then not Modifiers (Guikit.Input.Meta_Key);
      Zoom_Key      : constant Boolean :=
        Zoom_Modifier
          and then Key in Guikit.Input.Key_Equal
                        | Guikit.Input.Key_Minus
                        | Guikit.Input.Key_0;
   begin
      --  Start from a clean result so no flag leaks from a previous call when a
      --  caller reuses the same Result object across keystrokes.
      Result := (others => <>);
      --  Keyboard zoom is handled on this pure seam (not the controller, whose
      --  Settings are read-only): Ctrl+'=' / Ctrl+'+' grows, Ctrl+'-' shrinks,
      --  and Ctrl+0 resets the live font size. The shell's font-size sync and
      --  glyph rebuild then run through Apply_Interaction_Result, and the
      --  behaviour is exercisable through the genuine key seam in tests.
      if Zoom_Key then
         declare
            Old_Size : constant Positive := Settings.Font_Pixel_Size;
            New_Size : constant Positive :=
              (case Key is
                  when Guikit.Input.Key_Equal =>
                     Files.Settings.Clamp_Font_Pixel_Size (Old_Size + 1),
                  when Guikit.Input.Key_Minus =>
                     Files.Settings.Clamp_Font_Pixel_Size (Old_Size - 1),
                  when others =>
                     Files.Settings.Default_Font_Pixel_Size);
         begin
            if New_Size /= Old_Size then
               Settings.Font_Pixel_Size := New_Size;
               Persist_Settings (Settings, Settings_Path);
               Result.Settings_Changed    := True;
               Result.Font_Size_Changed   := True;
               Result.Needs_Glyph_Rebuild := True;
            end if;
            --  Drop any parallel '=' / '-' / '0' character event so a zoomed
            --  keystroke never leaks a glyph into a focused text field.
            Result.Clear_Pending_Text := True;
         end;
         return;
      end if;

      declare
         Outcome : constant Files.Controller.Controller_Result :=
           Files.Controller.Handle_Key
             (Model     => Model,
              Settings  => Settings,
              Key       => Key,
              Modifiers => Modifiers);
      begin
         if Outcome.Command = Files.Commands.Save_Settings_Command
           or else Outcome.Command = Files.Commands.Toggle_Hidden_Files_Command
           or else Outcome.Command = Files.Commands.Toggle_Show_Extensions_Command
         then
            --  Re-route settings-path commands through Execute_Command for the
            --  in-out settings handling, exactly as the shell did inline. The
            --  shell then dropped any parallel character event; surface that as
            --  a follow-up flag so Apply_Interaction_Result performs the clear.
            Execute_Command
              (Model             => Model,
               Settings          => Settings,
               Settings_Path     => Settings_Path,
               Command           => Outcome.Command,
               Current_Font_Size => Current_Font_Size,
               Result            => Result);
            Result.Clear_Pending_Text := True;
         else
            Result.Command := Outcome.Command;
            Result.Status := Outcome.Status;
            Result.Command_Executed :=
              Outcome.Status = Files.Controller.Controller_Command_Executed;
         end if;
      end;

      --  Space is a reserved grid shortcut (Quick Look), not a type-ahead
      --  character: when the grid owns the keyboard, drop the parallel space
      --  character event so it never leaks into type-ahead. A space typed into a
      --  focused text field keeps its character event and types a space.
      if Key = Guikit.Input.Key_Space
        and then Files.Model.Focus (Model) = Files.Types.Focus_None
      then
         Result.Clear_Pending_Text := True;
      end if;

      --  Fold any item opened by this key press (Enter on the selection) into
      --  the persisted recent list.
      Persist_Recent_Opens (Model, Settings, Settings_Path, Result);

      --  Keep the info-pane folder-size cache aligned with keyboard-driven
      --  selection changes. Cheap when the selected directory is unchanged.
      Files.Operations.Update_Folder_Size (Model, Settings);
   end Handle_Key;

   procedure Apply_Input_Action
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Action            : Files.Events.Input_Action;
      Current_Font_Size : Positive;
      Modifiers         : Guikit.Input.Modifier_Set;
      Result            : out Interaction_Result)
   is
      Outcome : Files.Controller.Controller_Result;
   begin
      case Action.Kind is
         when Files.Events.Command_Input_Action =>
            if Files.Commands.Requires_Settings_Path (Action.Command) then
               Execute_Command
                 (Model, Settings, Settings_Path, Action.Command,
                  Current_Font_Size, Modifiers, Result);
            else
               Outcome :=
                 Files.Controller.Handle_Command_Click
                   (Action.Command, Model, Settings, Modifiers);
               Result.Command := Action.Command;
               Result.Status := Outcome.Status;
               Result.Command_Executed :=
                 Outcome.Status = Files.Controller.Controller_Command_Executed;
            end if;
         when Files.Events.Item_Click_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Item_Click
                (Model         => Model,
                 Settings      => Settings,
                 Visible_Index => Action.Item_Index,
                 Activate      => Action.Activate,
                 Modifiers     => Modifiers);
            Result.Status := Outcome.Status;
         when Files.Events.Root_Click_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Root_Click
                (Model, Settings, Action.Root_Index);
            Result.Status := Outcome.Status;
         when Files.Events.Breadcrumb_Click_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Breadcrumb_Click
                (Model, Settings, Action.Item_Index);
            Result.Status := Outcome.Status;
            Result.Directory_Reloaded :=
              Outcome.Status = Files.Controller.Controller_Command_Executed;
         when Files.Events.Label_Picker_Choice_Input_Action =>
            --  Apply the chosen color label to every selected item and persist
            --  through the same settings-write seam the favorite toggle uses,
            --  then close the picker. A pos of zero clears the label (No_Label).
            declare
               Label : constant Files.Types.Color_Label :=
                 Files.Types.Color_Label'Val (Action.Item_Index);
               Selected : constant Files.File_System.Item_Vectors.Vector :=
                 Files.Model.Selected_Items (Model);
            begin
               for Item of Selected loop
                  Files.Settings.Set_Label
                    (Settings, To_String (Item.Full_Path), Label);
               end loop;
               Files.Model.Close_Label_Picker (Model);
               if not Selected.Is_Empty then
                  Persist_Settings (Settings, Settings_Path);
                  Result.Settings_Changed := True;
               end if;
            end;
         when Files.Events.Path_Favorite_Toggle_Input_Action =>
            --  Toggle the current directory's favorite state directly by path,
            --  independent of the selection, then persist through the same
            --  settings-write seam the Toggle_Favorite_Command uses so it saves.
            Files.Settings.Toggle_Favorite_Path
              (Settings, Files.Model.Current_Path (Model));
            Persist_Settings (Settings, Settings_Path);
            Result.Settings_Changed := True;
         when Files.Events.Tree_Click_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Tree_Click
                (Model, Settings, Action.Item_Index, Action.Toggle_Selection);
            Result.Status := Outcome.Status;
            Result.Directory_Reloaded :=
              (not Action.Toggle_Selection)
              and then Outcome.Status = Files.Controller.Controller_Command_Executed;
         when Files.Events.Tree_Pick_Confirm_Input_Action =>
            --  Confirm the destination picker: copy or move the captured sources
            --  into the highlighted directory through the same engine paste path,
            --  then clear the picker and close the sidebar. Begin_Paste_To surfaces
            --  a localized error key (e.g. drop-into-self) on the model on failure.
            declare
               Mode    : constant Files.Model.Tree_Pick_Mode :=
                 Files.Model.Tree_Pick_Mode_Of (Model);
               Sources : constant Files.Types.String_Vectors.Vector :=
                 Files.Model.Tree_Pick_Sources (Model);
               Target  : constant String := Files.Model.Tree_Pick_Target (Model);
            begin
               if Mode /= Files.Model.Pick_None and then Target /= "" then
                  declare
                     Op : constant Files.Operations.Operation_Result :=
                       Files.Operations.Begin_Paste_To
                         (Model, Settings, Sources, Target,
                          (if Mode = Files.Model.Pick_Move
                           then Files.File_System.Drop_Move
                           else Files.File_System.Drop_Copy));
                  begin
                     Files.Model.Close_Tree_Panel (Model);
                     Result.Directory_Reloaded :=
                       Op.Status = Files.Operations.Operation_Success
                       and then not Files.Model.Paste_Conflict_Is_Active (Model)
                       and then not Files.Model.Paste_Execution_Is_Active (Model);
                  end;
               else
                  Files.Model.Close_Tree_Panel (Model);
               end if;
            end;
         when Files.Events.Command_Result_Click_Input_Action =>
            --  The palette hit-tests the click and selects the row; a command
            --  that needs the settings path is executed here (the controller's
            --  generic Execute_Command has no path), otherwise the controller
            --  activates the highlighted command.
            if Files.Model.Command_Palette_Is_Open (Model)
              and then Files.Model.Palette_Click (Model, Action.Click_X, Action.Click_Y)
            then
               declare
                  Id      : constant Natural := Files.Model.Palette_Selected_Id (Model);
                  Command : constant Files.Commands.Command_Id :=
                    (if Files.Model.Command_Palette_Mode_Of (Model) = Files.Model.Palette_Commands
                       and then Id > 0
                     then Files.Commands.Command_Id'Val (Id)
                     else Files.Commands.No_Command);
               begin
                  if Command /= Files.Commands.No_Command
                    and then Files.Commands.Requires_Settings_Path (Command)
                    and then Files.Commands.Is_Enabled (Command, Model)
                  then
                     Execute_Command
                       (Model, Settings, Settings_Path, Command,
                        Current_Font_Size, Modifiers, Result);
                     if Result.Status /= Files.Controller.Controller_Ignored then
                        Files.Model.Close_Command_Palette (Model);
                     end if;
                  else
                     Outcome :=
                       Files.Controller.Activate_Palette_Command (Model, Settings, Modifiers);
                     Result.Status := Outcome.Status;
                  end if;
               end;
            end if;
         when Files.Events.Text_Click_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Text_Click
                (Model           => Model,
                 Target          => Action.Focus_Target,
                 Cursor_Position => Action.Cursor_Position,
                 Item_Index      => Action.Item_Index);
            Result.Status := Outcome.Status;
         when Files.Events.Settings_Click_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Settings_Click
                (Model => Model,
                 X     => Action.Click_X,
                 Y     => Action.Click_Y);
            Result.Status := Outcome.Status;
            if Outcome.Command = Files.Commands.Save_Settings_Command
              or else Outcome.Command = Files.Commands.Toggle_Hidden_Files_Command
           or else Outcome.Command = Files.Commands.Toggle_Show_Extensions_Command
            then
               Execute_Command
                 (Model, Settings, Settings_Path, Outcome.Command,
                  Current_Font_Size, Guikit.Input.No_Modifiers, Result);
               Result.Clear_Pending_Text := True;
            end if;
         when Files.Events.Permission_Toggle_Input_Action =>
            declare
               Toggle : constant Files.Operations.Operation_Result :=
                 Files.Operations.Toggle_Permission_Bit
                   (Model    => Model,
                    Bit      => Action.Item_Index,
                    Settings => Settings);
            begin
               Result.Directory_Reloaded :=
                 Toggle.Status = Files.Operations.Operation_Success;
            end;
         when Files.Events.Ownership_Edit_Input_Action =>
            --  Open the info-pane ownership editor prefilled with the current
            --  owner or group id; typing then Enter commits the change.
            Files.Model.Focus_Ownership_Input
              (Model, Editing_Group => Action.Item_Index = 1);
         when Files.Events.Conflict_Click_Input_Action =>
            if Action.Settings_Field = Files.Events.Conflict_Button_Apply_All then
               Files.Model.Toggle_Paste_Conflict_Apply_All (Model);
            else
               declare
                  Choice : constant Files.Operations.Conflict_Choice :=
                    (if Action.Settings_Field = Files.Events.Conflict_Button_Replace
                     then Files.Operations.Choice_Replace
                     elsif Action.Settings_Field = Files.Events.Conflict_Button_Skip
                     then Files.Operations.Choice_Skip
                     elsif Action.Settings_Field = Files.Events.Conflict_Button_Rename
                     then Files.Operations.Choice_Rename
                     else Files.Operations.Choice_Cancel);
                  Outcome : constant Files.Operations.Operation_Result :=
                    Files.Operations.Resolve_Paste_Conflict
                      (Model     => Model,
                       Settings  => Settings,
                       Choice    => Choice,
                       Apply_All => Files.Model.Paste_Conflict_Apply_All (Model));
               begin
                  Result.Directory_Reloaded :=
                    Outcome.Status = Files.Operations.Operation_Success
                    and then not Files.Model.Paste_Conflict_Is_Active (Model);
               end;
            end if;
         when Files.Events.Paste_Cancel_Input_Action =>
            --  Request cancellation of the in-flight paste, then finalize over
            --  the items completed so far (already-copied files are kept).
            Files.Operations.Cancel_Paste_Execution (Model);
            declare
               Outcome : constant Files.Operations.Operation_Result :=
                 Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
            begin
               Result.Directory_Reloaded :=
                 Outcome.Status = Files.Operations.Operation_Success
                 and then not Files.Model.Paste_Execution_Is_Active (Model);
            end;
         when Files.Events.Search_Scope_Toggle_Input_Action =>
            --  Clicking the filter-bar scope chip cycles the search scope and
            --  re-runs the shared query in the new scope, replacing the view with
            --  (or restoring it from) recursive search results.
            Outcome := Files.Controller.Handle_Search_Scope_Toggle (Model, Settings);
            Result.Status := Outcome.Status;
            Result.Command := Outcome.Command;
            Result.Command_Executed :=
              Outcome.Status = Files.Controller.Controller_Command_Executed;
            Result.Directory_Reloaded :=
              Outcome.Operation.Status = Files.Operations.Operation_Success;
         when Files.Events.Scroll_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Targeted_Scroll
                (Model, Action.Scroll_Area, Action.Scroll_Lines);
            Result.Status := Outcome.Status;
         when Files.Events.Scrollbar_Drag_Begin_Input_Action
            | Files.Events.Column_Resize_Begin_Input_Action
            | Files.Events.Column_Reorder_Begin_Input_Action
            | Files.Events.Marquee_Begin_Input_Action
            | Files.Events.No_Input_Action
            | Files.Events.Selection_Input_Action =>
            --  Scrollbar-drag, column-resize, column-reorder, and marquee begin
            --  all update runtime drag state owned by the shell (applied through
            --  Apply_Column_Resize / Apply_Column_Reorder on drop, or
            --  Apply_Marquee_Selection per frame); the no-op kinds are ignored.
            --  Nothing to apply here.
            null;
      end case;

      --  Fold any item opened by this action (double-click activation or an
      --  Open command / palette result) into the persisted recent list.
      Persist_Recent_Opens (Model, Settings, Settings_Path, Result);

      --  Refresh the info-pane folder-size cache for the (possibly changed)
      --  selection. Cheap when the selected directory is unchanged.
      Files.Operations.Update_Folder_Size (Model, Settings);
   end Apply_Input_Action;

   procedure Apply_Context_Menu_Command
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Command           : Files.Commands.Command_Id;
      Current_Font_Size : Positive;
      Modifiers         : Guikit.Input.Modifier_Set;
      Result            : out Interaction_Result) is
   begin
      Files.Model.Close_Context_Menu (Model);
      if Command /= Files.Commands.No_Command then
         Execute_Command
           (Model, Settings, Settings_Path, Command,
            Current_Font_Size, Modifiers, Result);
         --  Fold any item opened via the context menu's Open entry into the
         --  persisted recent list.
         Persist_Recent_Opens (Model, Settings, Settings_Path, Result);
      end if;
      Result.Context_Menu_Changed := True;
   end Apply_Context_Menu_Command;

   procedure Apply_Right_Click
     (Model             : in out Files.Model.Window_Model;
      Settings          : Files.Settings.Settings_Model;
      In_Main           : Boolean;
      Item_Index        : Natural;
      X                 : Natural;
      Y                 : Natural;
      Result            : out Interaction_Result;
      In_Details_Header : Boolean := False)
   is
      --  A modal overlay (settings, palette, root selector, sort menu) must
      --  swallow the click exactly as left-clicks are suppressed behind these
      --  overlays. Otherwise a right-click in the grid region behind the modal
      --  would open a context menu on top and the next left-click would execute
      --  file commands from a state where they should be unreachable.
      Overlay_Open : constant Boolean :=
        Files.Model.Settings_Pane_Is_Open (Model)
        or else Files.Model.Command_Palette_Is_Open (Model)
        or else Files.Model.Root_Selector_Is_Open (Model)
        or else Files.Model.Sort_Menu_Is_Open (Model);
   begin
      if In_Details_Header and then not Overlay_Open then
         --  A right-click on the details-view column header opens the column
         --  configuration menu regardless of any item under the header band.
         Files.Model.Open_Context_Menu (Model, X, Y, Files.Model.Context_Menu_Header);
      elsif In_Main and then not Overlay_Open then
         if Item_Index /= 0 then
            --  Match desktop file-manager convention: right-click on an
            --  unselected item immediately selects it so the user can see what
            --  the menu commands will operate on. A right-click on something
            --  already part of the selection preserves the full multi-selection.
            if Item_Index <= Files.Model.Visible_Count (Model)
              and then not Files.Model.Is_Selected (Model, Positive (Item_Index))
            then
               declare
                  Click_Result : Files.Controller.Controller_Result;
               begin
                  Files.Model.Clear_Selection (Model);
                  Click_Result :=
                    Files.Controller.Handle_Item_Click
                      (Model         => Model,
                       Settings      => Settings,
                       Visible_Index => Item_Index,
                       Activate      => False,
                       Modifiers     => Guikit.Input.No_Modifiers);
                  Result.Status := Click_Result.Status;
               end;
            end if;
            Files.Model.Open_Context_Menu
              (Model, X, Y, Files.Model.Context_Menu_Item, Item_Index);
         else
            Files.Model.Open_Context_Menu (Model, X, Y, Files.Model.Context_Menu_Empty);
         end if;
      else
         Files.Model.Close_Context_Menu (Model);
      end if;
      Result.Context_Menu_Changed := True;
   end Apply_Right_Click;

   procedure Apply_Column_Resize
     (Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Column        : Files.Types.Detail_Column;
      Origin_X      : Integer;
      Origin_Width  : Natural;
      Current_X     : Integer;
      Result        : out Interaction_Result)
   is
      --  The name column is the flexible remainder on the left, so a wider fixed
      --  column pushes its own left edge left: dragging the separator left grows
      --  the column and dragging it right shrinks it. Hence the applied delta is
      --  Origin_X minus Current_X.
      Target_Raw : constant Integer := Integer (Origin_Width) + (Origin_X - Current_X);
      New_Width  : constant Natural := (if Target_Raw < 0 then 0 else Target_Raw);
      Updated    : constant Files.Settings.Settings_Model :=
        Files.Settings.With_Column_Width (Settings, Column, New_Width);
   begin
      Result := (others => <>);
      if Updated.Column_Widths (Column) /= Settings.Column_Widths (Column) then
         Settings := Updated;
         Persist_Settings (Settings, Settings_Path);
         Result.Settings_Changed := True;
      end if;
   end Apply_Column_Resize;

   procedure Apply_Column_Reorder
     (Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Column        : Files.Types.Detail_Column;
      To_Index      : Files.Types.Detail_Column_Index;
      Result        : out Interaction_Result)
   is
      use type Files.Types.Detail_Column_Order;
      Updated : constant Files.Settings.Settings_Model :=
        Files.Settings.With_Column_Order (Settings, Column, To_Index);
   begin
      Result := (others => <>);
      if Updated.Column_Order /= Settings.Column_Order then
         Settings := Updated;
         Persist_Settings (Settings, Settings_Path);
         Result.Settings_Changed := True;
      end if;
   end Apply_Column_Reorder;

   function Selected_Visible_Indices
     (Model : Files.Model.Window_Model)
      return Files.Rendering.Visible_Index_Vectors.Vector
   is
      Count  : constant Natural := Files.Model.Visible_Count (Model);
      Result : Files.Rendering.Visible_Index_Vectors.Vector;
   begin
      for Index in 1 .. Count loop
         if Files.Model.Is_Selected (Model, Index) then
            Result.Append (Index);
         end if;
      end loop;
      return Result;
   end Selected_Visible_Indices;

   procedure Apply_Marquee_Selection
     (Model    : in out Files.Model.Window_Model;
      Hits     : Files.Rendering.Visible_Index_Vectors.Vector;
      Additive : Boolean;
      Base     : Files.Rendering.Visible_Index_Vectors.Vector)
   is
      Count    : constant Natural := Files.Model.Visible_Count (Model);
      Combined : Files.Rendering.Visible_Index_Vectors.Vector;

      --  Collect a unique, in-range visible index into the target set. Bounding
      --  by Count keeps a stale Base snapshot (e.g. after a listing shrank)
      --  from toggling a no-longer-visible index.
      procedure Add (Index : Positive) is
      begin
         if Index <= Count and then not Combined.Contains (Index) then
            Combined.Append (Index);
         end if;
      end Add;
   begin
      if Additive then
         for Index of Base loop
            Add (Index);
         end loop;
      end if;
      for Index of Hits loop
         Add (Index);
      end loop;

      Files.Model.Clear_Selection (Model);
      for Index of Combined loop
         Files.Model.Toggle_Visible_Selection (Model, Index);
      end loop;
   end Apply_Marquee_Selection;

end Files.Interaction;
