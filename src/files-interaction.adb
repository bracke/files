with Ada.Strings.Unbounded;

with Guikit.Settings_Panel;

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

   --  Pointer actions are translated from an immutable frame snapshot and may
   --  be delivered after another event has opened an overlay.  Admit only the
   --  command buttons owned by the overlay that is top-most now; otherwise a
   --  stale toolbar/bottom-bar action could mutate the covered file view.
   function Command_Action_Is_Current
     (Model   : Files.Model.Window_Model;
      Command : Files.Commands.Command_Id) return Boolean is
   begin
      if Files.Model.Paste_Execution_Is_Active (Model)
        or else Files.Model.Paste_Conflict_Is_Active (Model)
      then
         return False;
      elsif Files.Model.Quick_Look_Is_Open (Model) then
         return Command = Files.Commands.Toggle_Quick_Look_Command;
      elsif Files.Model.Label_Picker_Is_Open (Model) then
         return Command = Files.Commands.Close_Command_Palette_Command;
      elsif Files.Model.Command_Palette_Is_Open (Model) then
         return Command = Files.Commands.Close_Command_Palette_Command;
      elsif Files.Model.Settings_Pane_Is_Open (Model) then
         return Command = Files.Commands.Toggle_Settings_Pane_Command;
      elsif Files.Model.Root_Selector_Is_Open (Model) then
         return Command in Files.Commands.Select_Drive_Command
                           | Files.Commands.Close_Command_Palette_Command;
      elsif Files.Model.Sort_Menu_Is_Open (Model) then
         return Command in Files.Commands.Sort_By_Name_Command
                           | Files.Commands.Sort_By_Size_Command
                           | Files.Commands.Sort_By_Type_Command
                           | Files.Commands.Sort_By_Created_Command
                           | Files.Commands.Sort_By_Changed_Command
                           | Files.Commands.Close_Command_Palette_Command;
      elsif Files.Model.Context_Menu_Is_Open (Model) then
         return Command = Files.Commands.Close_Command_Palette_Command;
      elsif Files.Model.Tree_Pick_Is_Active (Model) then
         return Command = Files.Commands.Toggle_Folder_Tree_Command;
      end if;

      return True;
   end Command_Action_Is_Current;

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

   --  Copy the common controller observations into the public interaction
   --  result. Keeping this mapping in one place prevents non-command input
   --  routes (for example an activating item click) from losing the command id
   --  and executed flag returned by the controller.
   procedure Observe_Controller_Outcome
     (Outcome : Files.Controller.Controller_Result;
      Result  : in out Interaction_Result) is
   begin
      Result.Command := Outcome.Command;
      Result.Status := Outcome.Status;
      Result.Command_Executed :=
        Outcome.Status = Files.Controller.Controller_Command_Executed;
      Result.Directory_Reloaded :=
        Result.Directory_Reloaded
        or else Outcome.Operation.Status = Files.Operations.Operation_Navigated;
   end Observe_Controller_Outcome;

   --  Record the UI follow-ups of a settings command the controller applied:
   --  the change itself, a live font-size change, a reloaded listing.
   procedure Observe_Settings_Command
     (Command           : Files.Commands.Command_Id;
      Before            : Files.Settings.Settings_Model;
      Settings          : Files.Settings.Settings_Model;
      Current_Font_Size : Positive;
      Result            : in out Interaction_Result) is
   begin
      case Command is
         when Files.Commands.Save_Settings_Command =>
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
            Result.Settings_Changed := True;
            Result.Directory_Reloaded := True;
         when Files.Commands.Toggle_Favorite_Command =>
            --  A favorite toggle with nothing to toggle changes nothing.
            Result.Settings_Changed := Files.Settings."/=" (Settings, Before);
         when others =>
            Result.Settings_Changed := Files.Commands.Requires_Settings_Path (Command);
      end case;
   end Observe_Settings_Command;

   procedure Persist_Settings
     (Settings      : Files.Settings.Settings_Model;
      Settings_Path : String)
      renames Files.Controller.Persist_Settings;

   procedure Persist_Settings
     (Model         : in out Files.Model.Window_Model;
      Settings      : Files.Settings.Settings_Model;
      Settings_Path : String)
      renames Files.Controller.Persist_Settings;

   --  Fold any paths the model queued while opening items into the persisted
   --  recent list and write the settings. A no-op when nothing was opened, so it
   --  is safe to call after every dispatch seam (open routes through several).
   --  Give every selected item Label (No_Label clears it) and close the label
   --  picker. An edit that would make the settings file too big to load again
   --  is refused whole, with an error, rather than saved.
   procedure Apply_Label
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Label         : Files.Types.Color_Label;
      Result        : in out Interaction_Result)
   is
      Selected : constant Files.File_System.Item_Vectors.Vector :=
        Files.Model.Selected_Items (Model);
      Before   : constant Files.Settings.Settings_Model := Settings;
   begin
      for Item of Selected loop
         Files.Settings.Set_Label (Settings, To_String (Item.Full_Path), Label);
      end loop;
      Files.Model.Close_Label_Picker (Model);
      if Selected.Is_Empty then
         return;
      elsif not Files.Settings.Loadable (Settings) then
         Settings := Before;
         Files.Model.Set_Error (Model, "error.settings.full");
         return;
      end if;
      Persist_Settings (Model, Settings, Settings_Path);
      Result.Settings_Changed := True;
   end Apply_Label;

   function Follow_Path_Moves
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Boolean
   is
      From, To : Files.Types.String_Vectors.Vector;
      Changed  : Boolean := False;
   begin
      Files.Model.Take_Path_Moves (Model, From, To);
      for Index in From.First_Index .. From.Last_Index loop
         declare
            Moved : Boolean;
         begin
            if Length (To (Index)) = 0 then
               Files.Settings.Forget_Path_References (Settings, To_String (From (Index)), Moved);
            else
               Files.Settings.Move_Path_References
                 (Settings, To_String (From (Index)), To_String (To (Index)), Moved);
            end if;
            Changed := Changed or else Moved;
         end;
      end loop;
      if Changed then
         Persist_Settings (Model, Settings, Settings_Path);
      end if;
      return Changed;
   end Follow_Path_Moves;

   procedure Persist_Recent_Opens
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Result        : in out Interaction_Result)
   is
      Opened : constant Files.Types.String_Vectors.Vector :=
        Files.Model.Take_Recent_Opens (Model);
   begin
      --  Renames and moves made by this action carry their labels along.
      if Follow_Path_Moves (Model, Settings, Settings_Path) then
         Result.Settings_Changed := True;
      end if;
      if Opened.Is_Empty then
         return;
      end if;
      for Path of Opened loop
         Files.Settings.Note_Recent (Settings, To_String (Path));
      end loop;
      Persist_Settings (Model, Settings, Settings_Path);
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
      Context_Menu_At_Entry : constant Boolean :=
        Files.Model.Context_Menu_Is_Open (Model);
   begin
      Result := (others => <>);
      Result.Command := Command;

      if not Files.Commands.Is_Enabled (Command, Model) then
         Outcome := Files.Controller.Execute_Command (Command, Model, Settings, Modifiers);
         Result.Status := Outcome.Status;
         Result.Command_Executed := Outcome.Status = Files.Controller.Controller_Command_Executed;
         Result.Directory_Reloaded :=
           Outcome.Operation.Status = Files.Operations.Operation_Navigated;
         Result.Context_Menu_Changed :=
           Files.Model.Context_Menu_Is_Open (Model) /= Context_Menu_At_Entry;
         return;
      end if;

      declare
         Before : constant Files.Settings.Settings_Model := Settings;
      begin
         Outcome := Files.Controller.Execute_Command (Command, Model, Settings, Settings_Path, Modifiers);
         if Files.Commands.Requires_Settings_Path (Command) then
            Observe_Settings_Command (Command, Before, Settings, Current_Font_Size, Result);
         end if;
      end;

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
      Result.Directory_Reloaded :=
        Result.Directory_Reloaded
        or else Outcome.Operation.Status = Files.Operations.Operation_Navigated;
      Result.Context_Menu_Changed :=
        Files.Model.Context_Menu_Is_Open (Model) /= Context_Menu_At_Entry;
   end Execute_Command;

   --  Confirm the modal copy/move destination picker.  Both keyboard Enter and
   --  the Choose button route here so stale click actions cannot close an
   --  ordinary tree panel, and a validation failure leaves the picker open for
   --  the user to select a different destination.
   procedure Confirm_Tree_Pick
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Result   : in out Interaction_Result)
   is
   begin
      if not Files.Model.Tree_Pick_Is_Active (Model) then
         return;
      end if;

      declare
         Mode    : constant Files.Model.Tree_Pick_Mode :=
           Files.Model.Tree_Pick_Mode_Of (Model);
         Sources : constant Files.Types.String_Vectors.Vector :=
           Files.Model.Tree_Pick_Sources (Model);
         Target  : constant String := Files.Model.Tree_Pick_Target (Model);
      begin
         --  An empty target can occur while a newly seeded tree has no visible
         --  rows.  Keep the modal open instead of turning Choose into Cancel.
         if Mode = Files.Model.Pick_None or else Target = "" then
            return;
         end if;

         declare
            Op : constant Files.Operations.Operation_Result :=
              Files.Operations.Begin_Paste_To
                (Model, Settings, Sources, Target,
                 (if Mode = Files.Model.Pick_Move
                  then Files.File_System.Drop_Move
                  else Files.File_System.Drop_Copy));
         begin
            if Op.Status = Files.Operations.Operation_Success then
               Files.Model.End_Tree_Pick (Model);
               Result.Directory_Reloaded :=
                 not Files.Model.Paste_Conflict_Is_Active (Model)
                 and then not Files.Model.Paste_Execution_Is_Active (Model);
            end if;
         end;
      end;
   end Confirm_Tree_Pick;

   procedure Handle_Key
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Key               : Guikit.Input.Key_Code;
      Modifiers         : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Current_Font_Size : Positive;
      Result            : out Interaction_Result;
      Tree_Page_Rows    : Natural := 0)
   is
      --  Ctrl (Shift allowed for '+') without Alt/Meta drives keyboard zoom.
      Zoom_Modifier : constant Boolean :=
        Modifiers (Guikit.Input.Control_Key)
          and then not Modifiers (Guikit.Input.Alt_Key)
          and then not Modifiers (Guikit.Input.Meta_Key);
      Zoom_Chord    : constant Boolean :=
        Zoom_Modifier
          and then Key in Guikit.Input.Key_Equal
                        | Guikit.Input.Key_Minus
                        | Guikit.Input.Key_0;
      Zoom_Allowed  : constant Boolean :=
        not Files.Model.Input_Owning_Overlay_Is_Open (Model);
      --  Post-controller work must belong to the overlay that owned this key
      --  when dispatch began.  A command executed by one overlay can open a
      --  different overlay, which must not consume the same keypress again.
      Label_Picker_At_Entry : constant Boolean :=
        Files.Model.Label_Picker_Is_Open (Model);
      Context_Menu_At_Entry : constant Boolean :=
        Files.Model.Context_Menu_Is_Open (Model);
      Tree_Pick_At_Entry : constant Boolean :=
        Files.Model.Tree_Pick_Is_Active (Model);
   begin
      --  Start from a clean result so no flag leaks from a previous call when a
      --  caller reuses the same Result object across keystrokes.
      Result := (others => <>);
      --  Keyboard zoom is handled on this pure seam (not the controller, whose
      --  Settings are read-only): Ctrl+'=' / Ctrl+'+' grows, Ctrl+'-' shrinks,
      --  and Ctrl+0 resets the live font size. The shell's font-size sync and
      --  glyph rebuild then run through Apply_Interaction_Result, and the
      --  behaviour is exercisable through the genuine key seam in tests.
      if Zoom_Chord and then Zoom_Allowed then
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
               Persist_Settings (Model, Settings, Settings_Path);
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
         Before  : constant Files.Settings.Settings_Model := Settings;
         Outcome : constant Files.Controller.Controller_Result :=
           Files.Controller.Handle_Key
             (Model          => Model,
              Settings       => Settings,
              Settings_Path  => Settings_Path,
              Key            => Key,
              Modifiers      => Modifiers,
              Tree_Page_Rows => Tree_Page_Rows);
      begin
         Observe_Controller_Outcome (Outcome, Result);
         if Files.Commands.Requires_Settings_Path (Outcome.Command)
           and then Outcome.Status = Files.Controller.Controller_Command_Executed
           and then Files.Commands.Is_Enabled (Outcome.Command, Model)
         then
            --  The controller applied a settings shortcut (or Enter in the
            --  palette). The shell then dropped any parallel character event;
            --  surface that as a follow-up flag so Apply_Interaction_Result
            --  performs the clear.
            Observe_Settings_Command (Outcome.Command, Before, Settings, Current_Font_Size, Result);
            Result.Clear_Pending_Text := True;
         end if;
         --  A view / info-pane change driven from the keyboard (Ctrl+1..4) has
         --  already run inside Handle_Key; sync it to the settings so it
         --  persists. Sync_Global_UI_State is idempotent -- it writes only when
         --  the mirrored state actually differs -- so this is a no-op for any
         --  other command.
         if Files.Commands.Persists_Global_Ui_State (Outcome.Command)
           and then Sync_Global_UI_State (Model, Settings, Settings_Path)
         then
            Result.Settings_Changed := True;
         end if;
      end;

      --  A keyboard Enter on the open label picker applies the highlighted
      --  swatch to the selection. The read-only controller cannot write settings,
      --  so it is applied here on the in-out seam, exactly as the mouse
      --  Label_Picker_Choice action does.
      if Label_Picker_At_Entry
        and then Files.Model.Label_Picker_Is_Open (Model)
        and then Key = Guikit.Input.Key_Return
      then
         Apply_Label (Model, Settings, Settings_Path, Files.Model.Label_Picker_Highlight_Color (Model), Result);
      end if;

      --  A keyboard Enter on the open context menu runs the highlighted command,
      --  routed through Apply_Context_Menu_Command (which needs the settings path
      --  the read-only controller lacks), exactly as clicking that row does.
      if Context_Menu_At_Entry
        and then Files.Model.Context_Menu_Is_Open (Model)
        and then Key = Guikit.Input.Key_Return
      then
         declare
            use type Files.Commands.Context_Menu_Row_Kind;
            Rows      : constant Files.Commands.Context_Menu_Rows :=
              Files.Commands.Context_Menu_Rows_For (Files.Model.Context_Menu_Target_Of (Model));
            Highlight : constant Natural := Files.Model.Context_Menu_Highlight (Model);
         begin
            if Highlight in 1 .. Rows.Count
              and then Rows.Rows (Highlight).Kind = Files.Commands.Menu_Command
            then
               Apply_Context_Menu_Command
                 (Model, Settings, Settings_Path, Rows.Rows (Highlight).Command,
                  Current_Font_Size, Modifiers, Result);
            else
               --  Nothing highlighted (a mouse-opened menu not yet arrowed): a
               --  bare Enter just dismisses it.
               Files.Model.Close_Context_Menu (Model);
            end if;
         end;
      end if;

      --  A keyboard Enter with the destination-pick tree active confirms it: copy
      --  or move the captured sources into the highlighted directory, then close
      --  the sidebar, exactly as the picker's Confirm button does. Needs the
      --  settings the read-only controller cannot pass.
      if Tree_Pick_At_Entry
        and then Files.Model.Tree_Pick_Is_Active (Model)
        and then Key = Guikit.Input.Key_Return
      then
         Confirm_Tree_Pick (Model, Settings, Result);
      end if;

      --  Space is a reserved grid shortcut (Quick Look), not a type-ahead
      --  character: when the grid owns the keyboard, drop the parallel space
      --  character event so it never leaks into type-ahead. A space typed into a
      --  focused text field keeps its character event and types a space; one
      --  that flipped a settings toggle or choice is dropped like the grid's.
      if Key = Guikit.Input.Key_Space
        and then (Files.Model.Focus (Model) = Files.Types.Focus_None
                  or else (Files.Model.Focus (Model) = Files.Types.Focus_Settings_Input
                           and then Files.Model.Settings_Focused_Kind (Model) in
                             Guikit.Settings_Panel.Toggle | Guikit.Settings_Panel.Choice))
      then
         Result.Clear_Pending_Text := True;
      end if;

      --  A reserved zoom chord is consumed even when a modal overlay blocks
      --  the zoom itself, so its parallel character event cannot type "=" into
      --  an overlay text field.
      if Zoom_Chord then
         Result.Clear_Pending_Text := True;
      end if;

      Result.Context_Menu_Changed :=
        Result.Context_Menu_Changed
        or else Files.Model.Context_Menu_Is_Open (Model) /= Context_Menu_At_Entry;

      --  Fold any item opened by this key press (Enter on the selection) into
      --  the persisted recent list.
      Persist_Recent_Opens (Model, Settings, Settings_Path, Result);

      --  Keep the info-pane folder-size cache aligned with keyboard-driven
      --  selection changes. Cheap when the selected directory is unchanged.
      Files.Operations.Update_Folder_Size (Model, Settings);
      Files.Model.Ensure_Selected_Item_Extra (Model);
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
      Context_Menu_At_Entry : constant Boolean :=
        Files.Model.Context_Menu_Is_Open (Model);
   begin
      --  Callers reuse this record across input events. Reset every field before
      --  applying the branch-specific observations so a prior command's follow-up
      --  flags can never leak into an unrelated click or no-op.
      Result := (others => <>);

      case Action.Kind is
         when Files.Events.Command_Input_Action =>
            if not Command_Action_Is_Current (Model, Action.Command) then
               null;
            elsif Files.Commands.Requires_Settings_Path (Action.Command)
              or else Files.Commands.Persists_Global_Ui_State (Action.Command)
            then
               --  Route through Execute_Command so a runtime view / sort / info
               --  change (e.g. from the bottom bar) is synced to the settings and,
               --  for sort, the listing is re-loaded to match the new order.
               Execute_Command
                 (Model, Settings, Settings_Path, Action.Command,
                  Current_Font_Size, Modifiers, Result);
            else
               Outcome :=
                 Files.Controller.Handle_Command_Click
                   (Action.Command, Model, Settings, Modifiers);
               Observe_Controller_Outcome (Outcome, Result);
            end if;
         when Files.Events.Item_Click_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Item_Click
                (Model         => Model,
                 Settings      => Settings,
                 Visible_Index => Action.Item_Index,
                 Activate      => Action.Activate,
                 Modifiers     => Modifiers);
            Observe_Controller_Outcome (Outcome, Result);
         when Files.Events.Root_Click_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Root_Click
                (Model, Settings, Action.Root_Index);
            Observe_Controller_Outcome (Outcome, Result);
         when Files.Events.Breadcrumb_Click_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Breadcrumb_Click
                (Model, Settings, Action.Item_Index);
            Observe_Controller_Outcome (Outcome, Result);
         when Files.Events.Label_Picker_Choice_Input_Action =>
            --  Apply the chosen color label to every selected item and persist
            --  through the same settings-write seam the favorite toggle uses,
            --  then close the picker. A pos of zero clears the label (No_Label).
            if Files.Model.Label_Picker_Is_Open (Model)
              and then Action.Item_Index
                in Files.Types.Color_Label'Pos (Files.Types.Color_Label'First)
                   .. Files.Types.Color_Label'Pos (Files.Types.Color_Label'Last)
            then
               Apply_Label
                 (Model, Settings, Settings_Path, Files.Types.Color_Label'Val (Action.Item_Index), Result);
            end if;
         when Files.Events.Path_Favorite_Toggle_Input_Action =>
            --  Toggle the current directory's favorite state directly by path,
            --  independent of the selection, then persist through the same
            --  settings-write seam the Toggle_Favorite_Command uses so it saves.
            if not Files.Model.Input_Owning_Overlay_Is_Open (Model) then
               declare
                  Before : constant Files.Settings.Settings_Model := Settings;
               begin
                  Files.Settings.Toggle_Favorite_Path
                    (Settings, Files.Model.Current_Path (Model));
                  if Files.Settings.Loadable (Settings) then
                     Persist_Settings (Model, Settings, Settings_Path);
                     Result.Settings_Changed := True;
                  else
                     Settings := Before;
                     Files.Model.Set_Error (Model, "error.settings.full");
                  end if;
               end;
            end if;
         when Files.Events.Tree_Click_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Tree_Click
                (Model, Settings, Action.Item_Index, Action.Toggle_Selection);
            Observe_Controller_Outcome (Outcome, Result);
         when Files.Events.Tree_Pick_Confirm_Input_Action =>
            --  Confirm the destination picker: copy or move the captured sources
            --  into the highlighted directory through the same engine paste path,
            --  then close only after it starts successfully. Begin_Paste_To
            --  surfaces a localized error key (e.g. drop-into-self) on the model
            --  while the shared helper leaves the picker open for correction.
            Confirm_Tree_Pick (Model, Settings, Result);
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
                       and then Id <= Files.Commands.Command_Id'Pos
                         (Files.Commands.Command_Id'Last)
                     then Files.Commands.Command_Id'Val (Id)
                     else Files.Commands.No_Command);
               begin
                  if Command /= Files.Commands.No_Command
                    and then (Files.Commands.Requires_Settings_Path (Command)
                              or else Files.Commands.Persists_Global_Ui_State (Command))
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
                     Observe_Controller_Outcome (Outcome, Result);
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
            Observe_Controller_Outcome (Outcome, Result);
         when Files.Events.Settings_Click_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Settings_Click
                (Model => Model,
                 X     => Action.Click_X,
                 Y     => Action.Click_Y);
            Observe_Controller_Outcome (Outcome, Result);
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
            if Files.Model.Info_Pane_Is_Open (Model)
              and then not Files.Model.Input_Owning_Overlay_Is_Open (Model)
              and then Action.Item_Index <= 8
            then
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
            end if;
         when Files.Events.Ownership_Edit_Input_Action =>
            --  Open the info-pane ownership editor prefilled with the current
            --  owner or group id; typing then Enter commits the change.
            if Files.Model.Info_Pane_Is_Open (Model)
              and then not Files.Model.Input_Owning_Overlay_Is_Open (Model)
              and then Action.Item_Index <= 1
            then
               Files.Model.Focus_Ownership_Input
                 (Model, Editing_Group => Action.Item_Index = 1);
            end if;
         when Files.Events.Conflict_Click_Input_Action =>
            if Files.Model.Paste_Conflict_Is_Active (Model) then
               case Action.Settings_Field is
                  when Files.Events.Conflict_Button_Apply_All =>
                     Files.Model.Toggle_Paste_Conflict_Apply_All (Model);
                  when Files.Events.Conflict_Button_Replace
                     | Files.Events.Conflict_Button_Skip
                     | Files.Events.Conflict_Button_Rename
                     | Files.Events.Conflict_Button_Cancel =>
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
                  when others =>
                     null;
               end case;
            end if;
         when Files.Events.Paste_Cancel_Input_Action =>
            --  Request cancellation of the in-flight paste, then finalize over
            --  the items completed so far (already-copied files are kept).
            if Files.Model.Paste_Execution_Is_Active (Model) then
               Files.Operations.Cancel_Paste_Execution (Model);
               declare
                  Outcome : constant Files.Operations.Operation_Result :=
                    Files.Operations.Advance_Paste_Execution (Model, Settings, 1);
               begin
                  Result.Directory_Reloaded :=
                    Outcome.Status = Files.Operations.Operation_Success
                    and then not Files.Model.Paste_Execution_Is_Active (Model);
               end;
            end if;
         when Files.Events.Search_Scope_Toggle_Input_Action =>
            --  Clicking the filter-bar scope chip cycles the search scope and
            --  re-runs the shared query in the new scope, replacing the view with
            --  (or restoring it from) recursive search results.
            Outcome := Files.Controller.Handle_Search_Scope_Toggle (Model, Settings);
            Observe_Controller_Outcome (Outcome, Result);
            Result.Directory_Reloaded :=
              Outcome.Operation.Status = Files.Operations.Operation_Success;
         when Files.Events.Scroll_Input_Action =>
            Outcome :=
              Files.Controller.Handle_Targeted_Scroll
                (Model, Action.Scroll_Area, Action.Scroll_Lines);
            Observe_Controller_Outcome (Outcome, Result);
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

      Result.Context_Menu_Changed :=
        Result.Context_Menu_Changed
        or else Files.Model.Context_Menu_Is_Open (Model) /= Context_Menu_At_Entry;

      --  Fold any item opened by this action (double-click activation or an
      --  Open command / palette result) into the persisted recent list.
      Persist_Recent_Opens (Model, Settings, Settings_Path, Result);

      --  Refresh the info-pane folder-size cache for the (possibly changed)
      --  selection. Cheap when the selected directory is unchanged.
      Files.Operations.Update_Folder_Size (Model, Settings);

      --  Compute the selected item's extra info (folder child count, document
      --  page/entry/line counts, symlink target) lazily for the info pane, so
      --  navigation does not open every subfolder and read every document on
      --  load. A no-op when the info pane is closed or the value is cached.
      Files.Model.Ensure_Selected_Item_Extra (Model);
   end Apply_Input_Action;

   procedure Apply_Context_Menu_Command
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Command           : Files.Commands.Command_Id;
      Current_Font_Size : Positive;
      Modifiers         : Guikit.Input.Modifier_Set;
      Result            : out Interaction_Result)
   is
      Offered : Boolean := Command = Files.Commands.No_Command;
   begin
      Result := (others => <>);

      --  The shell resolves a row and dispatches it in separate steps. Reject
      --  an action if its menu has already closed or its command does not
      --  belong to the menu that is open now; otherwise a delayed item-menu
      --  click could execute against a newer empty/header menu or selection.
      if not Files.Model.Context_Menu_Is_Open (Model) then
         return;
      end if;

      if not Offered then
         declare
            Rows : constant Files.Commands.Context_Menu_Rows :=
              Files.Commands.Context_Menu_Rows_For
                (Files.Model.Context_Menu_Target_Of (Model));
         begin
            for Row in 1 .. Rows.Count loop
               if Rows.Rows (Row).Command = Command then
                  Offered := True;
                  exit;
               end if;
            end loop;
         end;
      end if;

      if not Offered then
         return;
      end if;

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
      --  Any input-owning overlay must
      --  swallow the click exactly as left-clicks are suppressed behind these
      --  overlays. Otherwise a right-click in the grid region behind the modal
      --  would open a context menu on top and the next left-click would execute
      --  file commands from a state where they should be unreachable.
      Overlay_Open : constant Boolean :=
        Files.Model.Settings_Pane_Is_Open (Model)
        or else Files.Model.Command_Palette_Is_Open (Model)
        or else Files.Model.Root_Selector_Is_Open (Model)
        or else Files.Model.Sort_Menu_Is_Open (Model)
        or else Files.Model.Label_Picker_Is_Open (Model)
        or else Files.Model.Quick_Look_Is_Open (Model)
        or else Files.Model.Tree_Pick_Is_Active (Model)
        or else Files.Model.Paste_Conflict_Is_Active (Model)
        or else Files.Model.Paste_Execution_Is_Active (Model);
   begin
      Result := (others => <>);
      if In_Details_Header and then not Overlay_Open then
         --  A right-click on the details-view column header opens the column
         --  configuration menu regardless of any item under the header band.
         Files.Model.Open_Context_Menu (Model, X, Y, Files.Model.Context_Menu_Header);
      elsif In_Main and then not Overlay_Open then
         if Item_Index > Files.Model.Visible_Count (Model) then
            --  A queued pointer action can outlive the snapshot that produced
            --  its visible index. Do not turn that stale index into an item
            --  menu operating on whatever selection happens to be current.
            Files.Model.Close_Context_Menu (Model);
         elsif Item_Index /= 0 then
            --  Match desktop file-manager convention: right-click on an
            --  unselected item immediately selects it so the user can see what
            --  the menu commands will operate on. A right-click on something
            --  already part of the selection preserves the full multi-selection.
            if not Files.Model.Is_Selected (Model, Positive (Item_Index))
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
                  Observe_Controller_Outcome (Click_Result, Result);
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
      --  This procedure is public and can be called with values wider than any
      --  real framebuffer. Compute before clamping in a wider type so extreme
      --  coordinates cannot overflow an Integer intermediate.
      Target_Raw : constant Long_Long_Integer :=
        Long_Long_Integer (Origin_Width)
        + Long_Long_Integer (Origin_X)
        - Long_Long_Integer (Current_X);
      New_Width  : constant Natural :=
        (if Target_Raw <= 0 then 0
         elsif Target_Raw >= Long_Long_Integer (Natural'Last) then Natural'Last
         else Natural (Target_Raw));
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
      Rows   : constant Files.Model.Visible_Row_Vectors.Vector := Files.Model.Visible_Rows (Model);
      Result : Files.Rendering.Visible_Index_Vectors.Vector;
   begin
      --  One pass over the rows; Is_Selected per index rescans the items.
      for Index in Rows.First_Index .. Rows.Last_Index loop
         if Rows (Index).Selected then
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
