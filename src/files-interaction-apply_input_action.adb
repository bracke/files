with Files.Settings.Path_References;
separate (Files.Interaction)
   procedure Apply_Input_Action
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Action            : Files.Events.Input_Action;
      Modifiers         : Guikit.Input.Modifier_Set;
      Result            : out Interaction_Result)
   is
      Before  : constant Files.Settings.Settings_Model := Settings;
      --  What a controller entry answered, when one was asked (Asked).
      Outcome : Files.Controller.Controller_Result;
      Asked   : Boolean := False;
   begin
      --  Callers reuse this record across input events. Reset every field before
      --  applying the branch-specific observations so a prior command's follow-up
      --  flags can never leak into an unrelated click or no-op.
      Result := (others => <>);

      case Action.Kind is
         when Files.Events.Command_Input_Action =>
            --  Through Execute_Command, so a runtime view / sort / info change
            --  (e.g. from the bottom bar) is synced to the settings and, for
            --  sort, the listing is re-loaded to match the new order.
            if Command_Action_Is_Current (Model, Action.Command) then
               Execute_Command
                 (Model, Settings, Settings_Path, Action.Command,
                  Modifiers, Result);
            end if;
         when Files.Events.Item_Click_Input_Action =>
            Asked := True;
            Outcome :=
              Files.Controller.Handle_Item_Click
                (Model         => Model,
                 Settings      => Settings,
                 Visible_Index => Action.Item_Index,
                 Activate      => Action.Activate,
                 Modifiers     => Modifiers);
         when Files.Events.Root_Click_Input_Action =>
            Asked := True;
            Outcome :=
              Files.Controller.Handle_Root_Click
                (Model, Settings, Action.Root_Index);
         when Files.Events.Breadcrumb_Click_Input_Action =>
            Asked := True;
            Outcome :=
              Files.Controller.Handle_Breadcrumb_Click
                (Model, Settings, Action.Segment_Index);
         when Files.Events.Right_Click_Input_Action =>
            Apply_Right_Click
              (Model             => Model,
               Settings          => Settings,
               In_Main           => Action.In_Main_View,
               Item_Index        => Action.Target_Item,
               X                 => Action.Menu_X,
               Y                 => Action.Menu_Y,
               Result            => Result,
               In_Details_Header => Action.On_Header,
               On_Context_Menu   => Action.Over_Menu);
         when Files.Events.Label_Picker_Choice_Input_Action =>
            --  Apply the chosen color label to every selected item and persist
            --  through the same settings-write seam the favorite toggle uses,
            --  then close the picker. No_Label clears the label.
            if Files.Model.Label_Picker.Is_Open (Model) then
               Apply_Label (Model, Settings, Settings_Path, Action.Label, Result);
            end if;
         when Files.Events.Path_Favorite_Toggle_Input_Action =>
            --  Toggle the current directory's favorite state directly by path,
            --  independent of the selection, under the policy every settings
            --  change has (Commit_Settings). The recent view has no path.
            if not Files.Model.Input_Owning_Overlay_Is_Open (Model)
              and then Files.Model.Current_Path (Model) /= ""
            then
               declare
                  Updated : Files.Settings.Settings_Model := Settings;
               begin
                  Files.Settings.Path_References.Toggle_Favorite_Path (Updated, Files.Model.Current_Path (Model));
                  Files.Controller.Commit_Settings
                    (Model, Settings, Updated, Settings_Path, Accepted => Result.Settings_Changed);
               end;
            end if;
         when Files.Events.Tree_Click_Input_Action =>
            Asked := True;
            Outcome :=
              Files.Controller.Handle_Tree_Click
                (Model, Settings, Action.Tree_Node, Action.Expander);
         when Files.Events.Tree_Pick_Confirm_Input_Action =>
            --  As Enter in the picker does: a paste that does not start leaves
            --  its error on the error line and the picker open for correction.
            Asked := True;
            Outcome := Files.Controller.Confirm_Tree_Pick (Model, Settings);
         when Files.Events.Command_Result_Click_Input_Action =>
            --  The palette hit-tests the click and selects the row, which is
            --  then activated as Enter activates it.
            if Files.Model.Command_Palette.Is_Open (Model)
              and then Files.Model.Command_Palette.Click (Model, Action.Click_X, Action.Click_Y)
            then
               Asked := True;
               Outcome := Files.Controller.Activate_Palette_Command (Model, Settings, Modifiers);
            end if;
         when Files.Events.Text_Click_Input_Action =>
            Asked := True;
            Outcome :=
              Files.Controller.Handle_Text_Click
                (Model           => Model,
                 Target          => Action.Focus_Target,
                 Cursor_Position => Action.Cursor_Position,
                 Item_Index      => Action.Field_Item);
         when Files.Events.Settings_Click_Input_Action =>
            --  A change that auto-saves comes back as a save to complete
            --  (Conclude, below).
            Asked := True;
            Outcome :=
              Files.Controller.Handle_Settings_Click
                (Model => Model,
                 X     => Action.Click_X,
                 Y     => Action.Click_Y);
         when Files.Events.Permission_Toggle_Input_Action =>
            Asked := True;
            Outcome := Files.Controller.Handle_Permission_Toggle (Model, Settings, Action.Bit);
         when Files.Events.Ownership_Edit_Input_Action =>
            --  Open the info-pane ownership editor prefilled with the current
            --  owner or group id; typing then Enter commits the change.
            Asked := True;
            Outcome := Files.Controller.Handle_Ownership_Edit (Model, Group => Action.Edit_Group);
         when Files.Events.Conflict_Click_Input_Action =>
            case Action.Conflict_Button is
               when Files.Events.Conflict_Button_Apply_All =>
                  Asked := True;
                  Outcome := Files.Controller.Handle_Conflict_Apply_All_Toggle (Model);
               when Files.Events.Conflict_Button_Replace =>
                  Asked := True;
                  Outcome := Files.Controller.Handle_Conflict_Choice (Model, Settings, Files.Operations.Choice_Replace);
               when Files.Events.Conflict_Button_Skip =>
                  Asked := True;
                  Outcome := Files.Controller.Handle_Conflict_Choice (Model, Settings, Files.Operations.Choice_Skip);
               when Files.Events.Conflict_Button_Rename =>
                  Asked := True;
                  Outcome := Files.Controller.Handle_Conflict_Choice (Model, Settings, Files.Operations.Choice_Rename);
               when Files.Events.Conflict_Button_Cancel =>
                  Asked := True;
                  Outcome := Files.Controller.Handle_Conflict_Choice (Model, Settings, Files.Operations.Choice_Cancel);
               when Files.Events.No_Conflict_Button =>
                  Outcome := (others => <>);
            end case;
         when Files.Events.Paste_Cancel_Input_Action =>
            --  Request cancellation of the in-flight paste, then finalize over
            --  the items completed so far (already-copied files are kept).
            Asked := True;
            Outcome := Files.Controller.Handle_Paste_Cancel (Model, Settings);
         when Files.Events.Search_Scope_Toggle_Input_Action =>
            --  Clicking the filter-bar scope chip cycles the search scope and
            --  re-runs the shared query in the new scope, replacing the view with
            --  (or restoring it from) recursive search results.
            Asked := True;
            Outcome := Files.Controller.Handle_Search_Scope_Toggle (Model, Settings);
         when Files.Events.Scroll_Input_Action =>
            Asked := True;
            Outcome :=
              Files.Controller.Handle_Targeted_Scroll
                (Model, Action.Scroll_Area, Action.Scroll_Lines);
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

      --  What a controller entry above answered, completed and observed.
      if Asked then
         declare
            use type Files.Events.Input_Action_Kind;
            Ran : Boolean;
         begin
            Conclude (Model, Settings, Settings_Path, Outcome, Before, Result, Ran);
            --  A settings-pane change saved by its click drops any parallel
            --  character event, as a key that saves does.
            Result.Clear_Pending_Text :=
              Ran and then Action.Kind = Files.Events.Settings_Click_Input_Action;
         end;
      end if;
      Finish_Dispatch (Model, Settings, Settings_Path, Result);
   end Apply_Input_Action;
