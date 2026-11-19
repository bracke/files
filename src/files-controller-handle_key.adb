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

      --  The key bound to Close_Overlay_Command (Escape unless rebound): every
      --  owner that closes, cancels or hands the keyboard back answers it,
      --  never a literal Escape.
      Is_Close_Key : constant Boolean :=
        Action.Kind = Files.Events.Command_Input_Action
        and then Files.Commands."=" (Action.Command, Files.Commands.Close_Overlay_Command);

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
           Files.Model.Tree_Panel.Visible_Rows (Model);
         Target  : constant String :=
           (if Pick then Files.Model.Tree_Panel.Pick_Target (Model) else Files.Model.Tree_Panel.Cursor (Model));
         Current : Natural := 0;

         procedure Select_Row (Index : Positive) is
         begin
            if Pick then
               Files.Model.Tree_Panel.Set_Pick_Target (Model, To_String (Rows (Index).Path));
            else
               Files.Model.Tree_Panel.Set_Cursor (Model, To_String (Rows (Index).Path));
            end if;
            Files.Model.Tree_Panel.Ensure_Row_Visible (Model, Index, Tree_Page_Rows);
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
                  return Toggle_Tree_Node (Model, Settings, Rows (Current).Node_Index);
               elsif Rows (Current).Expanded
                 and then Rows (Current).Has_Children
                 and then Current < Rows.Last_Index
                 and then Rows (Current + 1).Depth > Rows (Current).Depth
               then
                  --  Into the first child; an expanded folder with none
                  --  keeps the highlight rather than handing it to the
                  --  next sibling.
                  Select_Row (Current + 1);
               end if;
            when Guikit.Input.Key_Left =>
               if Rows (Current).Expanded then
                  return Toggle_Tree_Node (Model, Settings, Rows (Current).Node_Index);
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

      --  The keyboard owners. Each sets Handled when the key is its own -- an
      --  open overlay takes every key, a focused field takes editing keys --
      --  and Result is then the whole answer; a key no owner takes falls
      --  through to the command it is bound to.
      procedure Foreground_Job_Key (Handled : out Boolean; Result : out Controller_Result) is separate;
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

      --  The key, offered to the overlay on top (Files.Model.Topmost_Overlay):
      --  only it owns the keyboard, in the order the pointer and the drawing
      --  follow too. The key bound to Close_Overlay_Command (Escape unless
      --  rebound) closes any overlay Escape closes, as the command does; a
      --  shortcut being captured in the settings pane takes it first.
      procedure Top_Overlay_Key (Handled : out Boolean; Result : out Controller_Result) is
         use type Files.Types.Input_Overlay;
         Top : Files.Model.Input_Overlay;
      begin
         Handled := False;
         Result := Make_Result (Controller_Ignored);
         if not Files.Model.Topmost_Overlay (Model, Top) then
            return;
         elsif Is_Close_Key
           and then Top in Files.Model.Escape_Closable_Overlay
           and then not (Top = Files.Types.Settings_Pane_Overlay
                         and then Files.Model.Settings_Pane.Is_Capturing (Model))
         then
            Handled := True;
            Result := Close_Top_Or_Cancel (Model);
            return;
         end if;
         case Top is
            when Files.Types.Foreground_Job_Overlay  => Foreground_Job_Key (Handled, Result);
            when Files.Types.Paste_Conflict_Overlay  => Paste_Conflict_Key (Handled, Result);
            when Files.Types.Command_Palette_Overlay => Palette_Key (Handled, Result);
            when Files.Types.Context_Menu_Overlay    => Context_Menu_Key (Handled, Result);
            when Files.Types.Root_Selector_Overlay   => Root_Selector_Key (Handled, Result);
            when Files.Types.Sort_Menu_Overlay       => Sort_Menu_Key (Handled, Result);
            when Files.Types.Label_Picker_Overlay    => Label_Picker_Key (Handled, Result);
            when Files.Types.Quick_Look_Overlay      => Quick_Look_Key (Handled, Result);
            when Files.Types.Tree_Pick_Overlay       => Tree_Pick_Key (Handled, Result);
            --  The pane's keys are its focused field's (Settings_Input_Key).
            when Files.Types.Settings_Pane_Overlay   => null;
         end case;
      end Top_Overlay_Key;

      type Key_Owner is access procedure (Handled : out Boolean; Result : out Controller_Result);

      Owners : constant array (Positive range <>) of Key_Owner :=
        [Top_Overlay_Key'Access,
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
            return Execute_Non_Settings_Command (Action.Command, Model, Settings, Modifiers);
         when Files.Events.Selection_Input_Action =>
            if Files.Model.Focus (Model) = Files.Types.Focus_None
              and then not Files.Model.Settings_Pane.Is_Open (Model)
            then
               declare
                  Old_Index : constant Natural := Files.Model.Selection.Selected_Index (Model);
                  Old_Count : constant Natural := Files.Model.Selection.Selected_Count (Model);
                  Anchor    : constant Natural :=
                    (if Action.Extend then Files.Model.Selection.Range_Anchor (Model) else Old_Index);
               begin
                  if Action.Extend
                    and then Files.Model.Selection.Move_Would_Wrap (Model, Action.Direction)
                  then
                     --  Extending a range stops at the edge: wrapping would
                     --  reach across the listing and select all between.
                     return Make_Result (Controller_Ignored);
                  end if;
                  Files.Model.Selection.Move (Model, Action.Direction);
                  if Action.Extend then
                     declare
                        New_Index : constant Natural := Files.Model.Selection.Selected_Index (Model);
                     begin
                        if Anchor > 0 and then New_Index > 0 then
                           Files.Model.Selection.Select_Visible_Range (Model, Positive (Anchor), Positive (New_Index));
                        end if;
                     end;
                  end if;
                  return
                    Changed_Result
                      (Files.Model.Selection.Selected_Index (Model) = Old_Index
                         and then Files.Model.Selection.Selected_Count (Model) = Old_Count,
                       Controller_Selection_Moved);
               end;
            end if;
         --  The wheel is pointer input (Translate_Scroll_At): no key makes it.
         when Files.Events.No_Input_Action
            | Files.Events.Scroll_Input_Action
            | Files.Events.Text_Click_Input_Action
            | Files.Events.Settings_Click_Input_Action
            | Files.Events.Item_Click_Input_Action
            | Files.Events.Item_Drop_Input_Action
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
            | Files.Events.Context_Menu_Command_Input_Action
            | Files.Events.Right_Click_Input_Action
            | Files.Events.Search_Scope_Toggle_Input_Action
            | Files.Events.Foreground_Job_Cancel_Input_Action =>
            null;
      end case;

      return Make_Result (Controller_Ignored);
   end Handle_Key;
