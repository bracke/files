separate (Files.Controller)
   function Handle_Key
     (Model     : in out Files.Model.Window_Model;
      Settings  : Files.Settings.Settings_Model;
      Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Tree_Page_Rows : Natural := 0)
      return Controller_Result
   is
      Action : constant Files.Events.Input_Action := Files.Events.Translate_Key (Key, Modifiers);

      function Control_Only return Boolean is
      begin
         return Modifiers (Guikit.Input.Control_Key)
           and then not Modifiers (Guikit.Input.Shift_Key)
           and then not Modifiers (Guikit.Input.Alt_Key)
           and then not Modifiers (Guikit.Input.Meta_Key);
      end Control_Only;

      --  Arrow keys over the visible tree rows, shared by the destination picker
      --  and the side panel when it has the keyboard; Pick says whose highlight
      --  moves. Up/Down step a row; Right expands the folder (loading its
      --  children if needed) or steps into it; Left collapses it or steps out to
      --  the parent.
      function Move_Tree_Highlight (Pick : Boolean) return Controller_Result is
         Rows    : constant Files.Folder_Tree.Visible_Row_Vectors.Vector :=
           Files.Model.Tree_Visible_Rows (Model);
         Target  : constant String :=
           (if Pick then Files.Model.Tree_Pick_Target (Model) else Files.Model.Tree_Cursor (Model));
         Current : Natural := 0;

         procedure Select_Row (Index : Positive) is
         begin
            if Pick then
               Files.Model.Set_Tree_Pick_Target (Model, To_String (Rows (Index).Path));
            else
               Files.Model.Set_Tree_Cursor (Model, To_String (Rows (Index).Path));
            end if;
            Files.Model.Ensure_Tree_Row_Visible (Model, Index, Tree_Page_Rows);
         end Select_Row;
      begin
         if Rows.Is_Empty then
            return Make_Result (Controller_Ignored);
         end if;
         for Idx in Rows.First_Index .. Rows.Last_Index loop
            if To_String (Rows (Idx).Path) = Target then
               Current := Idx;
               exit;
            end if;
         end loop;
         if Current = 0 then
            --  Nothing highlighted yet: the first arrow lands on the first row
            --  so the rest of the navigation has an anchor.
            Select_Row (Rows.First_Index);
            return Make_Result (Controller_Selection_Moved);
         end if;

         case Key is
            when Guikit.Input.Key_Up =>
               if Current > Rows.First_Index then
                  Select_Row (Current - 1);
               end if;
            when Guikit.Input.Key_Down =>
               if Current < Rows.Last_Index then
                  Select_Row (Current + 1);
               end if;
            when Guikit.Input.Key_Right =>
               if Rows (Current).Has_Children and then not Rows (Current).Expanded then
                  return Handle_Tree_Click
                    (Model, Settings, Rows (Current).Node_Index, Toggle => True);
               elsif Rows (Current).Expanded and then Current < Rows.Last_Index then
                  Select_Row (Current + 1);
               end if;
            when Guikit.Input.Key_Left =>
               if Rows (Current).Expanded then
                  return Handle_Tree_Click
                    (Model, Settings, Rows (Current).Node_Index, Toggle => True);
               else
                  for Up_Idx in reverse Rows.First_Index .. Current - 1 loop
                     if Rows (Up_Idx).Depth < Rows (Current).Depth then
                        Select_Row (Up_Idx);
                        exit;
                     end if;
                  end loop;
               end if;
            when others =>
               null;
         end case;
         return Make_Result (Controller_Selection_Moved);
      end Move_Tree_Highlight;

      --  The keyboard owners, in priority order. Each sets Handled when the key
      --  is its own -- an open overlay takes every key, a focused field takes
      --  editing keys -- and Result is then the whole answer; a key no owner
      --  takes falls through to the command it is bound to.
      procedure Paste_Progress_Key (Handled : out Boolean; Result : out Controller_Result) is separate;
      procedure Paste_Conflict_Key (Handled : out Boolean; Result : out Controller_Result) is separate;
      procedure Quick_Look_Key (Handled : out Boolean; Result : out Controller_Result) is separate;
      procedure Palette_Key (Handled : out Boolean; Result : out Controller_Result) is separate;
      procedure Root_Selector_Key (Handled : out Boolean; Result : out Controller_Result) is separate;
      procedure Label_Picker_Key (Handled : out Boolean; Result : out Controller_Result) is separate;
      procedure Context_Menu_Key (Handled : out Boolean; Result : out Controller_Result) is separate;
      procedure Sort_Menu_Key (Handled : out Boolean; Result : out Controller_Result) is separate;
      procedure Tree_Pick_Key (Handled : out Boolean; Result : out Controller_Result) is separate;
      procedure Tree_Keyboard_Key (Handled : out Boolean; Result : out Controller_Result) is separate;
      procedure Menu_Key (Handled : out Boolean; Result : out Controller_Result) is separate;
      procedure Focus_Ring_Key (Handled : out Boolean; Result : out Controller_Result) is separate;
      procedure Settings_Input_Key (Handled : out Boolean; Result : out Controller_Result) is separate;
      procedure Editing_Key (Handled : out Boolean; Result : out Controller_Result) is separate;

      type Key_Owner is access procedure (Handled : out Boolean; Result : out Controller_Result);

      Owners : constant array (Positive range <>) of Key_Owner :=
        [Paste_Progress_Key'Access,
         Paste_Conflict_Key'Access,
         Quick_Look_Key'Access,
         Palette_Key'Access,
         Root_Selector_Key'Access,
         Label_Picker_Key'Access,
         Context_Menu_Key'Access,
         Sort_Menu_Key'Access,
         Tree_Pick_Key'Access,
         Tree_Keyboard_Key'Access,
         Menu_Key'Access,
         Focus_Ring_Key'Access,
         Settings_Input_Key'Access,
         Editing_Key'Access];
   begin
      for Owner of Owners loop
         declare
            Handled : Boolean;
            Result  : Controller_Result;
         begin
            Owner (Handled, Result);
            if Handled then
               return Result;
            end if;
         end;
      end loop;

      case Action.Kind is
         when Files.Events.Command_Input_Action =>
            if Files.Model.Focus (Model) /= Files.Types.Focus_None
              and then not Files.Commands.Allowed_With_Text_Focus (Action.Command)
              --  F2 inside the rename field toggles that rename off.
              and then not (Action.Command = Files.Commands.Rename_Selected_Items_Command
                            and then Files.Model.Focus (Model) = Files.Types.Focus_Rename_Input)
            then
               --  A focused text field owns the keyboard. Space is a typed
               --  space, not Quick Look; Ctrl+V/X/C/A/Z are text editing, and
               --  Shift+Delete must never delete the selection behind the field.
               return Make_Result (Controller_Ignored);
            end if;
            return Execute_Command (Action.Command, Model, Settings, Modifiers);
         when Files.Events.Selection_Input_Action =>
            if Files.Model.Focus (Model) = Files.Types.Focus_None
              and then not Files.Model.Settings_Pane_Is_Open (Model)
            then
               declare
                  Old_Index : constant Natural := Files.Model.Selected_Index (Model);
                  Old_Count : constant Natural := Files.Model.Selected_Count (Model);
                  Anchor    : Natural := Old_Index;
               begin
                  if Action.Range_Selection and then Old_Count > 1 then
                     declare
                        First_Selected : Natural := 0;
                        Last_Selected  : Natural := 0;
                     begin
                        Files.Model.Selected_Visible_Bounds (Model, First_Selected, Last_Selected);

                        if Old_Index = Last_Selected then
                           Anchor := First_Selected;
                        elsif Old_Index = First_Selected then
                           Anchor := Last_Selected;
                        end if;
                     end;
                  end if;

                  if Action.Range_Selection
                    and then Files.Model.Selection_Move_Would_Wrap (Model, Action.Direction)
                  then
                     --  Extending a range stops at the edge: wrapping would
                     --  reach across the listing and select all between.
                     return Make_Result (Controller_Ignored);
                  end if;
                  Files.Model.Move_Selection (Model, Action.Direction);
                  if Action.Range_Selection then
                     declare
                        New_Index : constant Natural := Files.Model.Selected_Index (Model);
                     begin
                        if Anchor > 0 and then New_Index > 0 then
                           Files.Model.Select_Visible_Range (Model, Positive (Anchor), Positive (New_Index));
                        end if;
                     end;
                  end if;
                  return
                    Make_Result
                      (if Files.Model.Selected_Index (Model) = Old_Index
                         and then Files.Model.Selected_Count (Model) = Old_Count
                       then Controller_Ignored
                       else Controller_Selection_Moved);
               end;
            end if;
         when Files.Events.Scroll_Input_Action =>
            return Handle_Scroll (Model, Action.Scroll_Lines);
         when Files.Events.No_Input_Action
            | Files.Events.Text_Click_Input_Action
            | Files.Events.Settings_Click_Input_Action
            | Files.Events.Item_Click_Input_Action
            | Files.Events.Root_Click_Input_Action
            | Files.Events.Breadcrumb_Click_Input_Action
            | Files.Events.Path_Favorite_Toggle_Input_Action
            | Files.Events.Tree_Click_Input_Action
            | Files.Events.Tree_Pick_Confirm_Input_Action
            | Files.Events.Command_Result_Click_Input_Action
            | Files.Events.Scrollbar_Drag_Begin_Input_Action
            | Files.Events.Column_Resize_Begin_Input_Action
            | Files.Events.Column_Reorder_Begin_Input_Action
            | Files.Events.Marquee_Begin_Input_Action
            | Files.Events.Permission_Toggle_Input_Action
            | Files.Events.Ownership_Edit_Input_Action
            | Files.Events.Conflict_Click_Input_Action
            | Files.Events.Label_Picker_Choice_Input_Action
            | Files.Events.Search_Scope_Toggle_Input_Action
            | Files.Events.Paste_Cancel_Input_Action =>
            null;
      end case;

      return Make_Result (Controller_Ignored);
   end Handle_Key;
