with Ada.Containers;
with Files.Model.Selection;
with Files.Commands.Context_Menus;
with Files.Events;
with Files.UI_Types;
with Files.Operation_Results;
with Files.Items;
with Ada.Strings.Unbounded;

with Guikit.Layout;
with Guikit.Mirroring;
with Guikit.Settings_Panel;

with Files.Model.Context_Menu;
with Files.Model.Label_Picker;
with Files.Model.Settings_Pane;
with Files.Commands.Overlay_Buttons;

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
      Save_Now      : Boolean;
      Result        : in out Interaction_Result)
   is
      Accepted : Boolean;
   begin
      Files.Controller.Set_Font_Size (Model, Settings, Settings_Path, New_Size, Save_Now, Accepted);
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

   subtype UI_State is Files.Controller.UI_State;
   function UI_State_Of (Model : Files.Model.Window_Model) return UI_State renames Files.Controller.UI_State_Of;

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
      if Files.Commands.Persists_Global_Ui_State (Command) then
         declare
            Accepted : Boolean;
         begin
            Files.Controller.Persist_UI_State (Model, Settings, Settings_Path, Before_UI, Accepted);
            if Accepted then
               Result.Settings_Changed := True;
            end if;
         end;
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

   --  What every key, action and drop dispatch ends with
   --  (Controller.Finish_Dispatch). The folder-size targets follow on the window's poll
   --  (Poll_Window_Workers), which retargets once the items or the selection
   --  have moved.
   procedure Finish_Dispatch
     (Model                 : in out Files.Model.Window_Model;
      Settings              : in out Files.Settings.Settings_Model;
      Settings_Path         : String;
      Result                : in out Interaction_Result)
   is
      Accepted : Boolean;
   begin
      Files.Controller.Finish_Dispatch (Model, Settings, Settings_Path, Accepted);
      Result.Settings_Changed := Result.Settings_Changed or else Accepted;
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
      Files.Controller.Import_Pending_Drops (Model, Settings, Source);
      Finish_Dispatch (Model, Settings, Settings_Path, Result);
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

      Files.Controller.Close_Context_Menu (Model);
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
      Outcome : constant Files.Controller.Controller_Result :=
        Files.Controller.Handle_Right_Click (Model, Settings, Target, Item_Index, X, Y);
   begin
      Result := (others => <>);
      Observe_Controller_Outcome (Outcome, Result);
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
      Base_Paths : Files.Types.String_Sets.Set;
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
      Files.Controller.Select_Marquee_Rows (Model, Rows);
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
