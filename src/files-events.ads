with Files.Commands;
with Files.Rendering;
with Guikit.Input;
with Files.Types;

--  GLFW-style input translation into internal command and selection events.
package Files.Events is

   type Input_Action_Kind is
     (No_Input_Action,
      Command_Input_Action,
      Selection_Input_Action,
      Scroll_Input_Action,
      Scrollbar_Drag_Begin_Input_Action,
      Column_Resize_Begin_Input_Action,
      Column_Reorder_Begin_Input_Action,
      Marquee_Begin_Input_Action,
      Text_Click_Input_Action,
      Settings_Click_Input_Action,
      Item_Click_Input_Action,
      Root_Click_Input_Action,
      Breadcrumb_Click_Input_Action,
      Path_Favorite_Toggle_Input_Action,
      Tree_Click_Input_Action,
      Tree_Pick_Confirm_Input_Action,
      Command_Result_Click_Input_Action,
      Permission_Toggle_Input_Action,
      Ownership_Edit_Input_Action,
      Conflict_Click_Input_Action,
      Paste_Cancel_Input_Action,
      Search_Scope_Toggle_Input_Action,
      Label_Picker_Choice_Input_Action);

   --  Which paste-conflict-dialog control a Conflict_Click_Input_Action hit.
   type Conflict_Button_Kind is
     (No_Conflict_Button,
      Conflict_Button_Replace,
      Conflict_Button_Skip,
      Conflict_Button_Rename,
      Conflict_Button_Cancel,
      Conflict_Button_Apply_All);

   --  A permission bit as the info pane's grid numbers them: 0 is others'
   --  execute, 8 the owner's read.
   subtype Permission_Bit is Natural range 0 .. 8;

   type Scroll_Target is
     (Scroll_Auto,
      Scroll_Main_View,
      Scroll_Info_Pane,
      Scroll_Tree_Panel,
      Scroll_Settings_Pane,
      Scroll_Command_Palette);

   --  Translated input action: a kind, and only the fields that kind carries.
   type Input_Action (Kind : Input_Action_Kind := No_Input_Action) is record
      case Kind is
         when Command_Input_Action =>
            Command : Files.Commands.Command_Id := Files.Commands.No_Command;
         when Selection_Input_Action =>
            Direction : Guikit.Input.Navigation_Direction := Guikit.Input.Move_Right;
            --  Shift held: the selection extends from its anchor.
            Extend    : Boolean := False;
         when Scroll_Input_Action | Scrollbar_Drag_Begin_Input_Action =>
            Scroll_Lines       : Integer := 0;
            Scroll_Area        : Scroll_Target := Scroll_Auto;
            --  Where on the thumb a scrollbar drag took hold.
            Scroll_Drag_Anchor : Integer := 0;
         when Column_Resize_Begin_Input_Action | Column_Reorder_Begin_Input_Action | Marquee_Begin_Input_Action =>
            --  Where the drag began (framebuffer pixels); for a column drag
            --  the column, and for a resize its width when it began; for a
            --  marquee, whether it adds to the selection (Ctrl or Shift).
            Origin_X     : Natural := 0;
            Origin_Y     : Natural := 0;
            Column       : Files.Types.Optional_Detail_Column := Files.Types.Optional_Detail_Column'First;
            Column_Width : Natural := 0;
            Additive     : Boolean := False;
            --  A reorder press that ends without crossing the drag threshold
            --  is a click on the column: this sort.
            Sort_Command : Files.Commands.Command_Id := Files.Commands.No_Command;
         when Text_Click_Input_Action =>
            Focus_Target    : Files.Types.Focus_Target := Files.Types.Focus_None;
            Cursor_Position : Natural := 0;
            --  The item whose rename field was clicked (0 for another field).
            Field_Item      : Natural := 0;
         when Settings_Click_Input_Action | Command_Result_Click_Input_Action =>
            --  Where the click landed, for the component's own hit test.
            Click_X : Integer := 0;
            Click_Y : Integer := 0;
         when Item_Click_Input_Action =>
            Item_Index      : Natural := 0;
            Activate        : Boolean := False;
            Toggle_Item     : Boolean := False;
            Range_Selection : Boolean := False;
         when Root_Click_Input_Action =>
            Root_Index : Natural := 0;
         when Breadcrumb_Click_Input_Action =>
            Segment_Index : Natural := 0;
         when Tree_Click_Input_Action =>
            Tree_Node : Natural := 0;
            --  The click hit the node's expander, not its name.
            Expander  : Boolean := False;
         when Permission_Toggle_Input_Action =>
            Bit : Permission_Bit := 0;
         when Ownership_Edit_Input_Action =>
            --  The group is edited, else the owner.
            Edit_Group : Boolean := False;
         when Conflict_Click_Input_Action =>
            Conflict_Button : Conflict_Button_Kind := No_Conflict_Button;
         when Label_Picker_Choice_Input_Action =>
            --  The chosen swatch (No_Label clears).
            Label : Files.Types.Color_Label := Files.Types.No_Label;
         when No_Input_Action
            | Path_Favorite_Toggle_Input_Action
            | Tree_Pick_Confirm_Input_Action
            | Paste_Cancel_Input_Action
            | Search_Scope_Toggle_Input_Action =>
            null;
      end case;
   end record;

   --  Translate a key and modifier state into an internal input action.
   --
   --  @param Key Key code.
   --  @param Modifiers Active modifier set.
   --  @return Internal input action.
   function Translate_Key
     (Key       : Guikit.Input.Key_Code;
      Modifiers : Guikit.Input.Modifier_Set)
      return Input_Action;

   --  Translate a window click into an internal input action.
   --
   --  @param Snapshot Immutable view snapshot used for overlay and item hit tests.
   --  @param Frame Frame commands used to resolve overlay hit regions.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Activate True when the click should activate the target.
   --  @param Modifiers Active modifier keys for selection behavior.
   --  @param Line_Height Text line height in pixels.
   --  @return Internal input action.
   function Translate_Click
     (Snapshot    : Files.Rendering.View_Snapshot;
      Frame       : Files.Rendering.Frame_Commands;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Activate    : Boolean := False;
      Modifiers   : Guikit.Input.Modifier_Set := Guikit.Input.No_Modifiers;
      Line_Height : Positive)
      return Input_Action;

   --  Translate a vertical scroll-wheel offset at a window coordinate.
   --
   --  @param Snapshot Immutable view snapshot used for overlay and pane hit tests.
   --  @param X Horizontal window coordinate.
   --  @param Y Vertical window coordinate.
   --  @param Width Window width in pixels.
   --  @param Height Window height in pixels.
   --  @param Y_Offset Positive GLFW-style wheel offsets scroll up; negative values scroll down.
   --  @param Line_Height Text line height in pixels.
   --  @return Internal scroll input action with a concrete target, or no action outside scrollable regions.
   function Translate_Scroll_At
     (Snapshot    : Files.Rendering.View_Snapshot;
      X           : Natural;
      Y           : Natural;
      Width       : Natural;
      Height      : Natural;
      Y_Offset    : Integer;
      Line_Height : Positive)
      return Input_Action;

end Files.Events;
