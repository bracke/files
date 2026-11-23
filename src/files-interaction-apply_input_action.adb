with Files.Input_Actions;
separate (Files.Interaction)
   procedure Apply_Input_Action
     (Model             : in out Files.Model.Window_Model;
      Settings          : in out Files.Settings.Settings_Model;
      Settings_Path     : String;
      Action            : Files.Input_Actions.Input_Action;
      Modifiers         : Guikit.Input.Modifier_Set;
      Result            : out Interaction_Result)
   is
      use type Files.Input_Actions.Conflict_Button_Kind;

      Before    : constant Files.Settings.Settings_Model := Settings;
      Before_UI : constant UI_State := UI_State_Of (Model);
      --  What a controller entry answered, when one was asked (Asked).
      Outcome : Files.Controller.Controller_Result;
      Asked   : Boolean := False;

      --  The path bar's star: the current folder, whatever is selected.
      procedure Toggle_Current_Favorite is
      begin
         Files.Controller.Toggle_Folder_Favorite (Model, Settings, Settings_Path, Accepted => Result.Settings_Changed);
      end Toggle_Current_Favorite;

      --  The actions a controller entry always answers.
      subtype Controller_Action is Files.Input_Actions.Input_Action_Kind
        with Static_Predicate =>
          Controller_Action in Files.Input_Actions.Item_Click_Input_Action
            | Files.Input_Actions.Item_Drop_Input_Action
            | Files.Input_Actions.Root_Click_Input_Action
            | Files.Input_Actions.Breadcrumb_Click_Input_Action
            | Files.Input_Actions.Tree_Click_Input_Action
            | Files.Input_Actions.Tree_Pick_Confirm_Input_Action
            | Files.Input_Actions.Text_Click_Input_Action
            | Files.Input_Actions.Settings_Click_Input_Action
            | Files.Input_Actions.Permission_Toggle_Input_Action
            | Files.Input_Actions.Ownership_Edit_Input_Action
            | Files.Input_Actions.Foreground_Job_Cancel_Input_Action
            | Files.Input_Actions.Search_Scope_Toggle_Input_Action
            | Files.Input_Actions.Scroll_Input_Action;

      --  The controller entry an action goes to, and its answer.
      function Ask_Controller (Kind : Controller_Action) return Files.Controller.Controller_Result is
      begin
         case Kind is
            when Files.Input_Actions.Item_Click_Input_Action =>
               return
                 Files.Controller.Handle_Item_Click
                   (Model         => Model,
                    Settings      => Settings,
                    Visible_Index => Action.Item_Index,
                    Activate      => Action.Activate,
                    Modifiers     => Modifiers);
            when Files.Input_Actions.Item_Drop_Input_Action =>
               return Files.Controller.Handle_Item_Drop (Model, Settings, Action.Drop_Target, Modifiers);
            when Files.Input_Actions.Root_Click_Input_Action =>
               return
                 Files.Controller.Handle_Root_Click
                   (Model, Settings, Action.Root_Index);
            when Files.Input_Actions.Breadcrumb_Click_Input_Action =>
               return
                 Files.Controller.Handle_Breadcrumb_Click
                   (Model, Settings, Action.Segment_Index);
            when Files.Input_Actions.Tree_Click_Input_Action =>
               return
                 (if Action.Expander
                  then Files.Controller.Toggle_Tree_Node (Model, Settings, Action.Tree_Node)
                  else Files.Controller.Activate_Tree_Node (Model, Settings, Action.Tree_Node));
            when Files.Input_Actions.Tree_Pick_Confirm_Input_Action =>
               --  As Enter in the picker does: a paste that does not start leaves
               --  its error on the error line and the picker open for correction.
               return Files.Controller.Confirm_Tree_Pick (Model, Settings);
            when Files.Input_Actions.Text_Click_Input_Action =>
               return
                 Files.Controller.Handle_Text_Click
                   (Model           => Model,
                    Target          => Action.Focus_Target,
                    Cursor_Position => Action.Cursor_Position,
                    Item_Index      => Action.Field_Item);
            when Files.Input_Actions.Settings_Click_Input_Action =>
               --  A change that auto-saves comes back as a save to complete
               --  (Conclude, below).
               return
                 Files.Controller.Handle_Settings_Click
                   (Model => Model,
                    X     => Action.Click_X,
                    Y     => Action.Click_Y);
            when Files.Input_Actions.Permission_Toggle_Input_Action =>
               return Files.Controller.Handle_Permission_Toggle (Model, Settings, Action.Bit);
            when Files.Input_Actions.Ownership_Edit_Input_Action =>
               --  Open the info-pane ownership editor prefilled with the current
               --  owner or group id; typing then Enter commits the change.
               return Files.Controller.Handle_Ownership_Edit (Model, Group => Action.Edit_Group);
            when Files.Input_Actions.Foreground_Job_Cancel_Input_Action =>
               --  Request cancellation of the foreground job (a paste or an
               --  operation), then finalize over what is done (copies are kept).
               return Files.Controller.Handle_Foreground_Job_Cancel (Model, Settings);
            when Files.Input_Actions.Search_Scope_Toggle_Input_Action =>
               --  Clicking the filter-bar scope chip cycles the search scope and
               --  re-runs the shared query in the new scope, replacing the view with
               --  (or restoring it from) recursive search results.
               return Files.Controller.Handle_Search_Scope_Toggle (Model, Settings);
            when Files.Input_Actions.Scroll_Input_Action =>
               return
                 Files.Controller.Handle_Targeted_Scroll
                   (Model, Action.Scroll_Area, Action.Scroll_Lines);
         end case;
      end Ask_Controller;

   begin
      --  Callers reuse this record across input events. Reset every field before
      --  applying the branch-specific observations so a prior command's follow-up
      --  flags can never leak into an unrelated click or no-op.
      Result := (others => <>);

      case Action.Kind is
         when Controller_Action =>
            Asked := True;
            Outcome := Ask_Controller (Action.Kind);
         when Files.Input_Actions.Command_Input_Action =>
            --  Through Execute_Command, so a runtime view / sort / info change
            --  (e.g. from the bottom bar) is synced to the settings; a sort
            --  re-orders the items in memory, with no new read.
            if Command_Action_Is_Current (Model, Action.Command) then
               Execute_Command
                 (Model, Settings, Settings_Path, Action.Command,
                  Modifiers, Result);
            end if;
         when Files.Input_Actions.Right_Click_Input_Action =>
            Apply_Right_Click
              (Model      => Model,
               Settings   => Settings,
               Target     => Action.Clicked_On,
               Item_Index => Action.Target_Item,
               X          => Action.Menu_X,
               Y          => Action.Menu_Y,
               Result     => Result);
         when Files.Input_Actions.Label_Picker_Choice_Input_Action =>
            --  Apply the chosen color label to every selected item and persist
            --  through the same settings-write seam the favorite toggle uses,
            --  then close the picker. No_Label clears the label.
            if Files.Model.Label_Picker.Is_Open (Model) then
               Apply_Label (Model, Settings, Settings_Path, Action.Label, Result);
            end if;
         when Files.Input_Actions.Context_Menu_Command_Input_Action =>
            --  A row of the context menu: its command runs, the menu closes.
            Apply_Context_Menu_Command
              (Model, Settings, Settings_Path, Action.Menu_Command, Modifiers, Result);
         when Files.Input_Actions.Path_Favorite_Toggle_Input_Action =>
            Toggle_Current_Favorite;
         when Files.Input_Actions.Command_Result_Click_Input_Action =>
            --  The palette hit-tests the click and selects the row, which is
            --  then activated as Enter activates it.
            Outcome :=
              Files.Controller.Click_Palette_Row (Model, Settings, Action.Click_X, Action.Click_Y, Modifiers);
            Asked := Files.Controller."/=" (Outcome.Status, Files.Controller.Controller_Ignored);
         when Files.Input_Actions.Conflict_Click_Input_Action =>
            Asked := Action.Conflict_Button /= Files.Input_Actions.No_Conflict_Button;
            Outcome := Files.Controller.Handle_Conflict_Button (Model, Settings, Action.Conflict_Button);
         when Files.Input_Actions.Scrollbar_Drag_Begin_Input_Action
            | Files.Input_Actions.Column_Resize_Begin_Input_Action
            | Files.Input_Actions.Column_Reorder_Begin_Input_Action
            | Files.Input_Actions.Marquee_Begin_Input_Action
            | Files.Input_Actions.No_Input_Action
            | Files.Input_Actions.Selection_Input_Action =>
            --  Scrollbar-drag, column-resize, column-reorder, and marquee begin
            --  all update runtime drag state owned by the shell (applied through
            --  Apply_Column_Resize / Apply_Column_Reorder on drop, or
            --  Apply_Marquee_Selection per frame); a selection move comes
            --  through Handle_Key, and the no-op is ignored.
            null;
      end case;

      --  What a controller entry above answered, completed and observed.
      if Asked then
         declare
            use type Files.Input_Actions.Input_Action_Kind;
            Ran : Boolean;
         begin
            Conclude (Model, Settings, Settings_Path, Outcome, Before, Before_UI, Result, Ran);
            --  A settings-pane change saved by its click drops any parallel
            --  character event, as a key that saves does.
            Result.Clear_Pending_Text :=
              Ran and then Action.Kind = Files.Input_Actions.Settings_Click_Input_Action;
         end;
      end if;
      Finish_Dispatch (Model, Settings, Settings_Path, Result);
   end Apply_Input_Action;
