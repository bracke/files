with Files.Operation_Results;
with Files.Window_Polls;
with Files.Items;
with Ada.Strings.Unbounded;

with Guikit.Layout;
with Guikit.Settings_Panel;

with Files.Operations;
with Files.Model.Command_Palette;
with Files.Model.Context_Menu;
with Files.Model.Label_Picker;
with Files.Model.Settings_Pane;
with Files.Settings.Path_References;

package body Files.Interaction is

   use Ada.Strings.Unbounded;
   use type Files.Commands.Command_Id;
   use type Files.Controller.Controller_Status;
   use type Files.Operation_Results.Operation_Status;
   use type Files.Types.Focus_Target;
   use type Guikit.Input.Key_Code;

   --  Pointer actions are translated from an immutable frame snapshot and may
   --  be delivered after another event has opened an overlay.  Admit only the
   --  command buttons owned by the overlay that is top-most now; otherwise a
   --  stale toolbar/bottom-bar action could mutate the covered file view.
   function Command_Action_Is_Current
     (Model   : Files.Model.Window_Model;
      Command : Files.Commands.Command_Id) return Boolean is
      Overlay : Files.Model.Input_Overlay;
   begin
      if not Files.Model.Topmost_Overlay (Model, Overlay) then
         return True;
      end if;
      case Overlay is
         when Files.Types.Foreground_Job_Overlay | Files.Types.Paste_Conflict_Overlay =>
            return False;
         when Files.Types.Quick_Look_Overlay =>
            return Command = Files.Commands.Toggle_Quick_Look_Command;
         when Files.Types.Label_Picker_Overlay
            | Files.Types.Command_Palette_Overlay
            | Files.Types.Context_Menu_Overlay =>
            return Command = Files.Commands.Close_Overlay_Command;
         when Files.Types.Settings_Pane_Overlay =>
            return Command = Files.Commands.Toggle_Settings_Pane_Command;
         when Files.Types.Root_Selector_Overlay =>
            return Command in Files.Commands.Select_Drive_Command
                              | Files.Commands.Close_Overlay_Command;
         when Files.Types.Sort_Menu_Overlay =>
            return Command in Files.Commands.Sort_Command_Id
                              | Files.Commands.Close_Overlay_Command;
         when Files.Types.Tree_Pick_Overlay =>
            return Command = Files.Commands.Toggle_Folder_Tree_Command;
      end case;
   end Command_Action_Is_Current;

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
   end Observe_Controller_Outcome;

   --  Record the UI follow-ups of a settings command the controller applied:
   --  whether it changed the settings (by what they hold now, not by which
   --  command ran: a save of an unchanged draft or a favourite toggle with
   --  nothing to toggle changes nothing) and a live font-size change.
   procedure Observe_Settings_Command
     (Command  : Files.Commands.Command_Id;
      Before   : Files.Settings.Settings_Model;
      Settings : Files.Settings.Settings_Model;
      Result   : in out Interaction_Result) is
   begin
      Result.Settings_Changed := not Files.Settings.Same_Content (Before, Settings);
      --  Apply a font-size change made in the settings pane live, the same
      --  way Ctrl+scroll / Ctrl+= zoom does: signal the shell to sync the
      --  runtime size and invalidate the glyph cache so text re-rasterizes
      --  now rather than only on the next launch.
      if Command in Files.Commands.Save_Settings_Command | Files.Commands.Reset_Settings_Command
        and then Settings.Font_Pixel_Size /= Before.Font_Pixel_Size
      then
         Result.Font_Size_Changed := True;
         Result.Needs_Glyph_Rebuild := True;
      end if;
   end Observe_Settings_Command;

   procedure Apply_Zoom
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      New_Size      : Positive;
      Result        : in out Interaction_Result) is
   begin
      if New_Size /= Settings.Font_Pixel_Size then
         Files.Controller.Commit_Settings
           (Model, Settings, (Settings with delta Font_Pixel_Size => New_Size), Settings_Path,
            Accepted => Result.Settings_Changed);
         Result.Font_Size_Changed   := Result.Settings_Changed;
         Result.Needs_Glyph_Rebuild := Result.Settings_Changed;
      end if;
   end Apply_Zoom;

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
      Updated : Files.Settings.Settings_Model := Settings;
   begin
      Files.Settings.Path_References.Set_Labels (Updated, Files.Model.Selection.Selected_Paths (Model), Label);
      Files.Model.Label_Picker.Close (Model);
      Files.Controller.Commit_Settings (Model, Settings, Updated, Settings_Path, Accepted => Result.Settings_Changed);
   end Apply_Label;

   function Follow_Path_Moves
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Boolean
   is
      Moves   : constant Files.Types.Path_Move_Vectors.Vector := Files.Model.Take_Path_Moves (Model);
      Changed : Boolean := False;
      Updated : Files.Settings.Settings_Model := Settings;
   begin
      for Move of Moves loop
         declare
            Followed : Boolean;
         begin
            case Move.Kind is
               when Files.Types.Removed =>
                  Files.Settings.Path_References.Forget_Path_References (Updated, To_String (Move.From), Followed);
               when Files.Types.Moved =>
                  Files.Settings.Path_References.Move_Path_References
                    (Updated, To_String (Move.From), To_String (Move.To), Followed);
            end case;
            Changed := Changed or else Followed;
         end;
      end loop;
      --  Longer paths can make the file too big to load again: then the
      --  labels stay where they were, and the error line says why.
      if not Changed then
         return False;
      end if;
      Files.Controller.Commit_Settings (Model, Settings, Updated, Settings_Path, Accepted => Changed);
      return Changed;
   end Follow_Path_Moves;

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
      --  Renames and moves made by this action carry their labels along.
      if Follow_Path_Moves (Model, Settings, Settings_Path) then
         Result.Settings_Changed := True;
      end if;
      if Opened.Is_Empty then
         return;
      end if;
      declare
         Updated  : Files.Settings.Settings_Model := Settings;
         Accepted : Boolean;
      begin
         for Path of Opened loop
            Files.Settings.Path_References.Note_Recent (Updated, To_String (Path));
         end loop;
         Files.Controller.Commit_Settings (Model, Settings, Updated, Settings_Path, Accepted);
         --  Added to, not overwritten: a refused recent list must not hide
         --  the label moves just written.
         Result.Settings_Changed := Result.Settings_Changed or else Accepted;
      end;
   end Persist_Recent_Opens;

   --  Copy the user-visible global UI state from the model into the settings
   --  record and persist it. Called whenever a runtime command flips one of the
   --  persisted toggles. Returns True when a change was written.
   function Sync_Global_UI_State
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Boolean
   is
      use type Files.Types.View_Mode;
      use type Files.Types.Sort_Field;

      New_View  : constant Files.Types.View_Mode :=
        Files.Model.View_Mode_Of (Model);
      New_Sort  : constant Files.Types.Sort_Field :=
        Files.Model.Sort_Field_Of (Model);
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

      declare
         Accepted : Boolean;
      begin
         Files.Controller.Commit_Settings
           (Model, Settings,
            (Settings with delta
               Default_View     => New_View,
               Sort_Field_Value => New_Sort,
               Sort_Ascending   => New_Asc,
               Info_Pane_Open   => New_Info),
            Settings_Path,
            Accepted);
         return Accepted;
      end;
   end Sync_Global_UI_State;

   --  After a command (from a click, a shortcut or the palette) that changed
   --  a setting the open settings pane edits: the pane shows the new value,
   --  and its next save cannot write the old one back.
   procedure Refresh_Open_Pane
     (Model    : in out Files.Model.Window_Model;
      Before   : Files.Settings.Settings_Model;
      Settings : Files.Settings.Settings_Model) is
   begin
      if Files.Model.Settings_Pane.Is_Open (Model) then
         declare
            use type Files.Settings.Settings_Draft;
            Shown     : constant Files.Settings.Settings_Draft := Files.Model.Settings_Pane.Draft_Of (Model);
            Refreshed : constant Files.Settings.Settings_Draft :=
              Files.Settings.Refresh_Draft (Shown, Before, Settings);
         begin
            if Refreshed /= Shown then
               Files.Model.Settings_Pane.Set_Draft (Model, Refreshed);
            end if;
         end;
      end if;
   end Refresh_Open_Pane;

   procedure Adopt_Shared_Settings
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model;
      Shared   : Files.Settings.Settings_Model)
   is
      use type Files.Types.Listing_Options;
      use type Files.Types.Sort_Field;
      use type Files.Settings.String_Maps.Map;
      Before : constant Files.Settings.Settings_Model := Settings;
   begin
      Settings := Shared;
      Refresh_Open_Pane (Model, Before, Settings);
      Files.Controller.Follow_Favorites (Model, Before, Settings);
      --  Items carry the hidden filter, the order and the type and icon they
      --  were classified with when the folder was read.
      if Files.Settings.Listing_Options_Of (Before) = Files.Settings.Listing_Options_Of (Settings)
        and then Before.Extension_Filetypes = Settings.Extension_Filetypes
        and then Before.Icon_Mappings = Settings.Icon_Mappings
      then
         null;
      elsif Files.Model.Search_Results_Are_Active (Model) then
         --  Search results have no folder to read again (a reload would
         --  replace them with the folder): the new settings apply to them in
         --  place, a changed order with them.
         if Before.Sort_Field_Value /= Settings.Sort_Field_Value
           or else Before.Sort_Ascending /= Settings.Sort_Ascending
         then
            Files.Model.Apply_Sort (Model, Settings.Sort_Field_Value, Settings.Sort_Ascending);
         end if;
         Files.Model.Reapply_Listing_Settings
           (Model, Settings,
            Reclassify => Before.Extension_Filetypes /= Settings.Extension_Filetypes
                          or else Before.Icon_Mappings /= Settings.Icon_Mappings);
      else
         declare
            --  A reload that fails says so in the window's error line. The
            --  folder sizes stay: only a refresh the user asks for measures
            --  them again.
            Reloaded : constant Files.Operation_Results.Operation_Result :=
              Files.Operations.Refresh (Model, Settings, Measure_Again => False);
            pragma Unreferenced (Reloaded);
         begin
            null;
         end;
      end if;
   end Adopt_Shared_Settings;

   --  Whether a settings command ran, judged by what it did, not by whether
   --  it is enabled now: Clear Recent, say, disables itself by running. A
   --  disabled or ignored one reported no change and gets no follow-ups.
   function Ran_Settings_Command
     (Command  : Files.Commands.Command_Id;
      Outcome  : Files.Controller.Controller_Result;
      Before   : Files.Settings.Settings_Model;
      Settings : Files.Settings.Settings_Model)
      return Boolean is
     (Files.Commands.Requires_Settings_Path (Command)
      and then Outcome.Status = Files.Controller.Controller_Command_Executed
      and then (Outcome.Operation.Status /= Files.Operation_Results.Operation_Disabled
                or else not Files.Settings.Same_Content (Before, Settings)));

   --  What a command that may have changed the settings ends with: its own
   --  settings follow-ups (Observe, when it is a settings command that ran),
   --  the UI state it changed written back to the settings, and an open
   --  settings pane shown the new values.
   procedure Finish_Settings_Command
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Command           : Files.Commands.Command_Id;
      Before            : Files.Settings.Settings_Model;
      Observe           : Boolean;
      Result            : in out Interaction_Result) is
   begin
      if Observe then
         Observe_Settings_Command (Command, Before, Settings, Result);
      end if;
      if Files.Commands.Persists_Global_Ui_State (Command)
        and then Sync_Global_UI_State (Model, Settings, Settings_Path)
      then
         Result.Settings_Changed := True;
      end if;
      Refresh_Open_Pane (Model, Before, Settings);
   end Finish_Settings_Command;

   --  Finish what a controller entry answered: a settings command it only
   --  reported is applied with the path (Controller.Complete_Settings_Command),
   --  the result is observed, and the settings follow-ups run
   --  (Finish_Settings_Command). Ran says whether a settings command ran.
   procedure Conclude
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Reported      : Files.Controller.Controller_Result;
      Before        : Files.Settings.Settings_Model;
      Result        : in out Interaction_Result;
      Ran           : out Boolean)
   is
      Outcome : constant Files.Controller.Controller_Result :=
        Files.Controller.Complete_Settings_Command (Reported, Model, Settings, Settings_Path);
   begin
      Ran := Ran_Settings_Command (Outcome.Command, Outcome, Before, Settings);
      Observe_Controller_Outcome (Outcome, Result);
      Finish_Settings_Command
        (Model, Settings, Settings_Path, Outcome.Command, Before, Observe => Ran, Result => Result);
   end Conclude;

   procedure Execute_Command
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Command           : Files.Commands.Command_Id;
      Modifiers         : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result            : out Interaction_Result)
   is
      Before : constant Files.Settings.Settings_Model := Settings;
      Ran    : Boolean;
   begin
      Result := (others => <>);
      --  The controller refuses a disabled command (it reports why) and
      --  applies a settings command with the path.
      Conclude
        (Model, Settings, Settings_Path,
         Files.Controller.Execute_Command (Command, Model, Settings, Settings_Path, Modifiers), Before, Result, Ran);
      Result.Command := Command;
   end Execute_Command;

   --  What every key and action dispatch ends with: any item opened folded
   --  into the recent list, the
   --  folder-size targets (at once when the items and selection stand), and
   --  the selected item's lazily computed extra info.
   procedure Finish_Dispatch
     (Model                 : in out Files.Model.Window_Model;
      Settings              : in out Files.Settings.Settings_Model;
      Settings_Path         : String;
      Result                : in out Interaction_Result) is
   begin
      Persist_Recent_Opens (Model, Settings, Settings_Path, Result);
      Files.Window_Polls.Update_Folder_Size (Model);
      Files.Window_Polls.Ensure_Selected_Item_Extra (Model, Settings.Show_Hidden_Files);
   end Finish_Dispatch;

   procedure Handle_Key
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Key               : Guikit.Input.Key_Code;
      Modifiers         : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result            : out Interaction_Result;
      Tree_Page_Rows    : Natural := 0) is separate;

   procedure Apply_Input_Action
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Action            : Files.Events.Input_Action;
      Modifiers         : Guikit.Input.Modifier_Set;
      Result            : out Interaction_Result) is separate;

   procedure Apply_Context_Menu_Command
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Command           : Files.Commands.Command_Id;
      Modifiers         : Guikit.Input.Modifier_Set;
      Result            : out Interaction_Result)
   is
      use type Files.Types.Input_Overlay;
      Offered : Boolean := Command = Files.Commands.No_Command;
      Top     : Files.Model.Input_Overlay;
   begin
      Result := (others => <>);

      --  The shell resolves a row and dispatches it in separate steps. Reject
      --  an action if its menu has already closed, is no longer on top, or
      --  its command does not belong to the menu that is open now; otherwise a delayed item-menu
      --  click could execute against a newer empty/header menu or selection.
      if not Files.Model.Context_Menu.Is_Open (Model)
        or else not Files.Model.Topmost_Overlay (Model, Top)
        or else Top /= Files.Types.Context_Menu_Overlay
      then
         return;
      end if;

      if not Offered then
         declare
            Rows : constant Files.Commands.Context_Menu_Rows :=
              Files.Commands.Context_Menu_Rows_For
                (Files.Model.Context_Menu.Target_Of (Model));
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

      Files.Model.Context_Menu.Close (Model);
      if Command /= Files.Commands.No_Command then
         Execute_Command
           (Model, Settings, Settings_Path, Command,
            Modifiers, Result);
         --  Fold any item opened via the context menu's Open entry into the
         --  persisted recent list.
         Persist_Recent_Opens (Model, Settings, Settings_Path, Result);
      end if;
   end Apply_Context_Menu_Command;

   procedure Apply_Right_Click
     (Model             : in out Files.Model.Window_Model;
      Settings          : Files.Settings.Settings_Model;
      In_Main           : Boolean;
      Item_Index        : Natural;
      X                 : Natural;
      Y                 : Natural;
      Result            : out Interaction_Result;
      In_Details_Header : Boolean := False;
      On_Context_Menu   : Boolean := False)
   is
      --  Any input-owning overlay must swallow the click exactly as left-clicks
      --  are suppressed behind these overlays. Otherwise a right-click in the
      --  grid region behind the modal would open a context menu on top and the
      --  next left-click would execute file commands from a state where they
      --  should be unreachable. An open context menu does not count:
      --  right-clicking elsewhere replaces it with a new menu.
      Overlay_Open : constant Boolean :=
        Files.Model.Other_Input_Owning_Overlay_Is_Open (Model, Except => Files.Types.Context_Menu_Overlay);
   begin
      Result := (others => <>);
      if On_Context_Menu and then Files.Model.Context_Menu.Is_Open (Model) then
         return;
      elsif In_Details_Header and then not Overlay_Open then
         --  A right-click on the details-view column header opens the column
         --  configuration menu regardless of any item under the header band.
         Files.Model.Context_Menu.Open (Model, X, Y, Files.Types.Context_Menu_Header);
      elsif In_Main and then not Overlay_Open then
         if Item_Index > Files.Model.Visible_Count (Model) then
            --  A queued pointer action can outlive the snapshot that produced
            --  its visible index. Do not turn that stale index into an item
            --  menu operating on whatever selection happens to be current.
            Files.Model.Context_Menu.Close (Model);
         elsif Item_Index /= 0 then
            --  Match desktop file-manager convention: right-click on an
            --  unselected item immediately selects it so the user can see what
            --  the menu commands will operate on. A right-click on something
            --  already part of the selection preserves the full multi-selection.
            if not Files.Model.Selection.Is_Selected (Model, Positive (Item_Index))
            then
               declare
                  Click_Result : Files.Controller.Controller_Result;
               begin
                  --  A menu still open for another item would make the
                  --  click below ignored, leaving nothing selected.
                  Files.Model.Context_Menu.Close (Model);
                  Files.Model.Selection.Clear (Model);
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
            Files.Model.Context_Menu.Open
              (Model, X, Y, Files.Types.Context_Menu_Item, Item_Index);
         else
            Files.Model.Context_Menu.Open (Model, X, Y, Files.Types.Context_Menu_Empty);
         end if;
      else
         Files.Model.Context_Menu.Close (Model);
      end if;
   end Apply_Right_Click;

   procedure Apply_Column_Resize
     (Model        : in out Files.Model.Window_Model;
      Settings     : in out Files.Settings.Settings_Model;
      Column       : Files.Types.Detail_Column;
      Origin_X     : Integer;
      Origin_Width : Natural;
      Current_X    : Integer;
      Result       : out Interaction_Result;
      Line_Height  : Positive)
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
      --  Store the pixel width in reference units, rounded to nearest, the
      --  inverse of the Guikit.Layout.Scaled the renderer applies (which never
      --  shrinks below the reference, hence the same floor on the divisor).
      Scale      : constant Long_Long_Integer :=
        Long_Long_Integer (Positive'Max (Line_Height, Guikit.Layout.Reference_Line_Height));
      Target_Ref : constant Long_Long_Integer :=
        (if Target_Raw <= 0 then 0
         else (Target_Raw * Long_Long_Integer (Guikit.Layout.Reference_Line_Height) + Scale / 2) / Scale);
      New_Width  : constant Natural :=
        (if Target_Ref >= Long_Long_Integer (Natural'Last) then Natural'Last
         else Natural (Target_Ref));
      Updated    : constant Files.Settings.Settings_Model :=
        Files.Settings.With_Column_Width (Settings, Column, New_Width);
   begin
      Result := (others => <>);
      if Updated.Column_Widths (Column) /= Settings.Column_Widths (Column) then
         Settings := Updated;
         Result.Settings_Changed := True;
         --  In memory only (End_Column_Resize writes the file once), but the
         --  window's settings moved: other windows take them from here.
         Files.Model.Note_Settings_Changed (Model);
      end if;
   end Apply_Column_Resize;

   procedure End_Column_Resize
     (Model         : in out Files.Model.Window_Model;
      Settings      : Files.Settings.Settings_Model;
      Settings_Path : String;
      Changed       : Boolean) is
   begin
      if Changed then
         Files.Controller.Persist_Settings (Model, Settings, Settings_Path);
      end if;
   end End_Column_Resize;

   procedure Apply_Column_Reorder
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
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
         Files.Controller.Commit_Settings
           (Model, Settings, Updated, Settings_Path, Accepted => Result.Settings_Changed);
      end if;
   end Apply_Column_Reorder;

   function Selected_Visible_Indices
     (Model : Files.Model.Window_Model)
      return Files.Model.Selection.Visible_Index_List
   is
      Result   : Files.Model.Selection.Visible_Index_List;
      Position : Natural := 0;

      procedure Note (Item : Files.Items.Directory_Item; Item_Index : Natural; Selected : Boolean) is
         pragma Unreferenced (Item, Item_Index);
      begin
         Position := Position + 1;
         if Selected then
            Result.Append (Position);
         end if;
      end Note;
   begin
      --  One pass over the rows; Is_Selected per index rescans the items.
      Files.Model.For_Each_Visible_Row (Model, Note'Access);
      return Result;
   end Selected_Visible_Indices;

   procedure Apply_Marquee_Selection
     (Model    : in out Files.Model.Window_Model;
      Hits     : Files.Model.Selection.Visible_Index_List;
      Additive : Boolean;
      Base     : Files.Model.Selection.Visible_Index_List)
   is
      use type Files.Model.Selection.Visible_Index_List;
   begin
      --  The base (when additive), then the hits; the model drops repeats and
      --  indexes a stale base names past the listing's end.
      Files.Model.Selection.Select_Visible_Set (Model, (if Additive then Base & Hits else Hits));
   end Apply_Marquee_Selection;

end Files.Interaction;
