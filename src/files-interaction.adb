with Ada.Containers;
with Files.Model.Selection;
with Files.Commands.Context_Menus;
with Files.Model.Recent;
with Files.Model.Info_Pane;
with Files.Events;
with Files.UI_Types;
with Files.Operation_Results;
with Files.Refresh;
with Files.Items;
with Ada.Strings.Unbounded;

with Guikit.Layout;
with Guikit.Mirroring;
with Guikit.Settings_Panel;

with Files.Operations;
with Files.Model.Command_Palette;
with Files.Model.Context_Menu;
with Files.Model.Label_Picker;
with Files.Model.Settings_Pane;
with Files.Commands.Overlay_Buttons;
with Files.Settings.Path_References;

package body Files.Interaction is

   use Ada.Strings.Unbounded;
   use type Files.Commands.Command_Id;
   use type Files.Controller.Controller_Status;
   use type Files.Operation_Results.Operation_Status;
   use type Files.UI_Types.Focus_Target;
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
      return Files.Commands.Overlay_Buttons.Accepts (Overlay, Command);
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

   --  Record whether a settings command the controller applied changed the
   --  settings, by what they hold now, not by which command ran: a save of an
   --  unchanged draft or a favourite toggle with nothing to toggle changes
   --  nothing.
   procedure Observe_Settings_Command
     (Before   : Files.Settings.Settings_Model;
      Settings : Files.Settings.Settings_Model;
      Result   : in out Interaction_Result) is
   begin
      --  A font size changed here is taken up by the window's next frame
      --  (Read_Window_State), as a zoom is.
      Result.Settings_Changed := not Files.Settings.Same_Content (Before, Settings);
   end Observe_Settings_Command;

   procedure Apply_Zoom
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      New_Size      : Positive;
      Result        : in out Interaction_Result)
   is
      Accepted : Boolean;
   begin
      Files.Controller.Set_Font_Size (Model, Settings, Settings_Path, New_Size, Accepted);
      Result.Settings_Changed := Result.Settings_Changed or else Accepted;
   end Apply_Zoom;

   --  Give every selected item Label (No_Label clears it) and close the label
   --  picker. An edit that would make the settings file too big to load again
   --  is refused whole, with an error, rather than saved.
   procedure Apply_Label
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Label         : Files.Preference_Types.Color_Label;
      Result        : in out Interaction_Result)
   is
   begin
      Files.Controller.Label_Selection (Model, Settings, Settings_Path, Label, Accepted => Result.Settings_Changed);
   end Apply_Label;

   function Follow_Path_Moves
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String)
      return Boolean
   is
      Moves   : constant Files.Types.Path_Move_Vectors.Vector := Files.Model.Recent.Take_Path_Moves (Model);
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
        Files.Model.Recent.Take_Recent_Opens (Model);
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

   --  The window's own view of the persisted UI state (view mode, sort,
   --  info pane), captured before a command runs so what it changed, and only
   --  that, is written back: a value the window never adopted from another
   --  window (its view mode, its info pane) must not overwrite the shared one.
   type UI_State is record
      View      : Files.Preference_Types.View_Mode := Files.Preference_Types.Small_Icons;
      Sort      : Files.Types.Sort_Field := Files.Types.Sort_Name;
      Ascending : Boolean := True;
      Info      : Boolean := False;
   end record;

   function UI_State_Of (Model : Files.Model.Window_Model) return UI_State is
     (View      => Files.Model.View_Mode_Of (Model),
      Sort      => Files.Model.Sort_Field_Of (Model),
      Ascending => Files.Model.Sort_Is_Ascending (Model),
      Info      => Files.Model.Info_Pane.Info_Pane_Is_Open (Model));

   --  Write the global UI state a command changed in the model (against
   --  Before_UI, the model's state before it ran) into the settings record and
   --  persist it. Called whenever a runtime command flips one of the persisted
   --  toggles. Returns True when a change was written.
   function Sync_Global_UI_State
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Before_UI     : UI_State)
      return Boolean
   is
      use type Files.Preference_Types.View_Mode;
      use type Files.Types.Sort_Field;

      Now     : constant UI_State := UI_State_Of (Model);
      Updated : Files.Settings.Settings_Model := Settings;
   begin
      if Now.View /= Before_UI.View then
         Updated.Default_View := Now.View;
      end if;
      if Now.Sort /= Before_UI.Sort or else Now.Ascending /= Before_UI.Ascending then
         Updated.Sort_Field_Value := Now.Sort;
         Updated.Sort_Ascending := Now.Ascending;
      end if;
      if Now.Info /= Before_UI.Info then
         Updated.Info_Pane_Open := Now.Info;
      end if;
      if Files.Settings.Same_Content (Updated, Settings) then
         return False;
      end if;

      declare
         Accepted : Boolean;
      begin
         Files.Controller.Commit_Settings (Model, Settings, Updated, Settings_Path, Accepted);
         return Accepted;
      end;
   end Sync_Global_UI_State;

   procedure Adopt_Shared_Settings
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model;
      Shared   : Files.Settings.Settings_Model)
   is
      Before : constant Files.Settings.Settings_Model := Settings;
   begin
      Settings := Shared;
      Files.Controller.Take_In_Settings (Model, Before, Settings);
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
      Before_UI         : UI_State;
      Observe           : Boolean;
      Result            : in out Interaction_Result) is
   begin
      if Observe then
         Observe_Settings_Command (Before, Settings, Result);
      end if;
      if Files.Commands.Persists_Global_Ui_State (Command)
        and then Sync_Global_UI_State (Model, Settings, Settings_Path, Before_UI)
      then
         Result.Settings_Changed := True;
      end if;
      Files.Controller.Refresh_Open_Pane (Model, Before, Settings);
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
      Before_UI     : UI_State;
      Result        : in out Interaction_Result;
      Ran           : out Boolean)
   is
      Outcome : constant Files.Controller.Controller_Result :=
        Files.Controller.Complete_Settings_Command (Reported, Model, Settings, Settings_Path);
   begin
      Ran := Ran_Settings_Command (Outcome.Command, Outcome, Before, Settings);
      Observe_Controller_Outcome (Outcome, Result);
      Finish_Settings_Command
        (Model, Settings, Settings_Path, Outcome.Command, Before, Before_UI, Observe => Ran, Result => Result);
   end Conclude;

   procedure Execute_Command
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Command           : Files.Commands.Command_Id;
      Modifiers         : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result            : out Interaction_Result)
   is
      Before    : constant Files.Settings.Settings_Model := Settings;
      Before_UI : constant UI_State := UI_State_Of (Model);
      Ran       : Boolean;
   begin
      Result := (others => <>);
      --  The controller refuses a disabled command (it reports why) and
      --  reports a settings command, which Conclude applies with the path.
      Conclude
        (Model, Settings, Settings_Path,
         Files.Controller.Execute_Non_Settings_Command (Command, Model, Settings, Modifiers), Before, Before_UI,
         Result, Ran);
      Result.Command := Command;
   end Execute_Command;

   --  What every key and action dispatch ends with: any item opened folded
   --  into the recent list, and the selected item's lazily computed extra
   --  info. The folder-size targets follow on the window's poll
   --  (Poll_Window_Workers), which retargets once the items or the selection
   --  have moved.
   procedure Finish_Dispatch
     (Model                 : in out Files.Model.Window_Model;
      Settings              : in out Files.Settings.Settings_Model;
      Settings_Path         : String;
      Result                : in out Interaction_Result) is
   begin
      Persist_Recent_Opens (Model, Settings, Settings_Path, Result);
      Files.Refresh.Ensure_Selected_Item_Extra (Model, Settings.Show_Hidden_Files);
   end Finish_Dispatch;

   procedure Handle_Key
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Key               : Guikit.Input.Key_Code;
      Modifiers         : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Result            : out Interaction_Result;
      Tree_Page_Rows    : Natural := 0) is separate;

   procedure Append_Text
     (Model  : in out Files.Model.Window_Model;
      Text   : String;
      Result : out Interaction_Result)
   is
      Outcome : constant Files.Controller.Controller_Result := Files.Controller.Append_Focused_Text (Model, Text);
   begin
      --  A character runs no command: the edit or the type-ahead move is in
      --  the model, which the next frame draws.
      Result := (Status => Outcome.Status, others => <>);
   end Append_Text;

   procedure Import_Drops
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Source        : in out Files.Drop_Events.Drop_Event_Source;
      Result        : out Interaction_Result) is
   begin
      Result := (others => <>);
      if Files.Drop_Events.Take_Overflow (Source) then
         Files.Model.Set_Error (Model, "error.drop.failed");
         return;
      end if;
      Files.Controller.Import_Pending_Drops (Model, Settings, Source);
      Persist_Recent_Opens (Model, Settings, Settings_Path, Result);
   end Import_Drops;

   procedure Apply_Input_Action
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Action            : Files.Input_Actions.Input_Action;
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
      use type Files.UI_Types.Input_Overlay;
      Offered : Boolean := Command = Files.Commands.No_Command;
      Top     : Files.Model.Input_Overlay;
   begin
      Result := (others => <>);

      --  A row's command is resolved from a frame and applied later (a queued
      --  click, a screen-reader request). Reject it if its menu has already
      --  closed, is no longer on top, or its command does not belong to the
      --  menu open now; otherwise a delayed item-menu click could execute
      --  against a newer empty/header menu or selection.
      if not Files.Model.Context_Menu.Is_Open (Model)
        or else not Files.Model.Topmost_Overlay (Model, Top)
        or else Top /= Files.UI_Types.Context_Menu_Overlay
      then
         return;
      end if;

      if not Offered then
         declare
            Rows : constant Files.Commands.Context_Menus.Context_Menu_Rows :=
              Files.Commands.Context_Menus.Context_Menu_Rows_For
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
         --  An item opened through the menu's Open entry joins the recent list
         --  in the caller's Finish_Dispatch, as for every other dispatch.
         Execute_Command
           (Model, Settings, Settings_Path, Command,
            Modifiers, Result);
      end if;
   end Apply_Context_Menu_Command;

   procedure Apply_Right_Click
     (Model      : in out Files.Model.Window_Model;
      Settings   : Files.Settings.Settings_Model;
      Target     : Files.Input_Actions.Right_Click_Target;
      Item_Index : Natural;
      X          : Natural;
      Y          : Natural;
      Result     : out Interaction_Result)
   is
      use type Files.Input_Actions.Right_Click_Target;
      --  Any input-owning overlay must swallow the click exactly as left-clicks
      --  are suppressed behind these overlays. Otherwise a right-click in the
      --  grid region behind the modal would open a context menu on top and the
      --  next left-click would execute file commands from a state where they
      --  should be unreachable. An open context menu does not count:
      --  right-clicking elsewhere replaces it with a new menu.
      Overlay_Open : constant Boolean :=
        Files.Model.Other_Input_Owning_Overlay_Is_Open (Model, Except => Files.UI_Types.Context_Menu_Overlay);
   begin
      Result := (others => <>);
      if Target = Files.Input_Actions.On_Context_Menu and then Files.Model.Context_Menu.Is_Open (Model) then
         return;
      elsif Target = Files.Input_Actions.On_Details_Header and then not Overlay_Open then
         --  A right-click on the details-view column header opens the column
         --  configuration menu regardless of any item under the header band.
         Files.Model.Context_Menu.Open (Model, X, Y, Files.UI_Types.Context_Menu_Header);
      elsif Target = Files.Input_Actions.On_Main_View and then not Overlay_Open then
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
            Files.Model.Context_Menu.Open (Model, X, Y, Files.UI_Types.Context_Menu_Item);
         else
            Files.Model.Context_Menu.Open (Model, X, Y, Files.UI_Types.Context_Menu_Empty);
         end if;
      else
         Files.Model.Context_Menu.Close (Model);
      end if;
   end Apply_Right_Click;

   procedure Apply_Column_Resize
     (Model        : in out Files.Model.Window_Model;
      Settings     : in out Files.Settings.Settings_Model;
      Column       : Files.Preference_Types.Detail_Column;
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
   begin
      Result := (others => <>);
      --  In memory only (End_Column_Resize writes the file once).
      Files.Controller.Resize_Column (Model, Settings, Column, New_Width, Changed => Result.Settings_Changed);
   end Apply_Column_Resize;

   procedure End_Column_Resize
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
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
      Column        : Files.Preference_Types.Detail_Column;
      To_Index      : Files.Preference_Types.Detail_Column_Index;
      Result        : out Interaction_Result)
   is
   begin
      Result := (others => <>);
      Files.Controller.Reorder_Column
        (Model, Settings, Settings_Path, Column, To_Index, Accepted => Result.Settings_Changed);
   end Apply_Column_Reorder;

   function Marquee_Base
     (Model : Files.Model.Window_Model)
      return Files.Types.String_Vectors.Vector is
     (Files.Model.Selection.Selected_Paths (Model));

   function Marquee_Base_Rows
     (Model : Files.Model.Window_Model;
      Base  : Files.Types.String_Vectors.Vector)
      return Marquee_Rows
   is
      Base_Paths : Files.Settings.Path_References.Path_Sets.Set;
      Base_Rows  : Marquee_Rows;
      Position   : Natural := 0;

      procedure Note (Item : Files.Items.Directory_Item; Item_Index : Natural; Selected : Boolean) is
         pragma Unreferenced (Item_Index, Selected);
      begin
         Position := Position + 1;
         if Base_Paths.Contains (To_String (Item.Full_Path)) then
            Base_Rows.Append (Position);
         end if;
      end Note;
   begin
      if not Base.Is_Empty then
         for Path of Base loop
            Base_Paths.Include (To_String (Path));
         end loop;
         --  Where the base's items are now: one pass over the rows.
         Files.Model.For_Each_Visible_Row (Model, Note'Access);
      end if;
      return Base_Rows;
   end Marquee_Base_Rows;

   procedure Apply_Marquee_Selection
     (Model     : in out Files.Model.Window_Model;
      Hits      : Marquee_Rows;
      Additive  : Boolean;
      Base_Rows : Marquee_Rows)
   is
      Rows : Files.Model.Selection.Visible_Index_List;
   begin
      --  The base's rows (when additive), then the hits; the model drops
      --  repeats.
      if Additive then
         Rows.Reserve_Capacity (Ada.Containers."+" (Base_Rows.Length, Hits.Length));
         for Row of Base_Rows loop
            Rows.Append (Row);
         end loop;
      else
         Rows.Reserve_Capacity (Hits.Length);
      end if;
      for Row of Hits loop
         Rows.Append (Row);
      end loop;
      Files.Model.Selection.Select_Visible_Set (Model, Rows);
   end Apply_Marquee_Selection;

   procedure Apply_Marquee_Selection
     (Model    : in out Files.Model.Window_Model;
      Hits     : Marquee_Rows;
      Additive : Boolean;
      Base     : Files.Types.String_Vectors.Vector) is
   begin
      Apply_Marquee_Selection
        (Model,
         Hits,
         Additive,
         Base_Rows =>
           (if Additive then Marquee_Base_Rows (Model, Base)
            else Guikit.Item_Grid.Visible_Index_Vectors.Empty_Vector));
   end Apply_Marquee_Selection;

end Files.Interaction;
