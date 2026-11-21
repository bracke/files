with Files.Commands;
with Guikit.Input;
with Files.Types;
with Files.UI_Types;

--  The input actions Files.Events translates input into and Files.Controller
--  and Files.Interaction apply: plain values, in a unit of their own so the
--  controller need not depend on event translation, nor through it on the
--  rendering snapshot.
package Files.Input_Actions is

   --  What a right click landed on, from the top of what is drawn down:
   --  the open context menu, the details view's column header, the main
   --  view (an item, or the space between), or anything else.
   type Right_Click_Target is (On_Context_Menu, On_Details_Header, On_Main_View, Elsewhere);

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
      Item_Drop_Input_Action,
      Root_Click_Input_Action,
      Breadcrumb_Click_Input_Action,
      Path_Favorite_Toggle_Input_Action,
      Tree_Click_Input_Action,
      Tree_Pick_Confirm_Input_Action,
      Command_Result_Click_Input_Action,
      Permission_Toggle_Input_Action,
      Ownership_Edit_Input_Action,
      Conflict_Click_Input_Action,
      Foreground_Job_Cancel_Input_Action,
      Search_Scope_Toggle_Input_Action,
      Label_Picker_Choice_Input_Action,
      Context_Menu_Command_Input_Action,
      Right_Click_Input_Action);

   --  The move along a list or grid a navigation key asks for: a step in a
   --  direction (an arrow), the first or the last row (Home, End), or a page
   --  (Page Up, Page Down). One mapping for every list the keys move through:
   --  the file grid, Quick Look's selection underneath and the root selector.
   type Grid_Move is (No_Grid_Move, Grid_Step, Grid_First, Grid_Last, Grid_Page_Up, Grid_Page_Down);

   type Grid_Navigation is record
      Move      : Grid_Move := No_Grid_Move;
      --  The step's direction; meaningful for Grid_Step only.
      Direction : Guikit.Input.Navigation_Direction := Guikit.Input.Move_Down;
   end record;

   --  The grid move Key names, ignoring modifiers.
   --
   --  @param Key Key pressed.
   --  @return Its move, or No_Grid_Move for a key that is no navigation key.
   function Grid_Navigation_Of (Key : Guikit.Input.Key_Code) return Grid_Navigation is
     (case Key is
         when Guikit.Input.Key_Left      => (Grid_Step, Guikit.Input.Move_Left),
         when Guikit.Input.Key_Right     => (Grid_Step, Guikit.Input.Move_Right),
         when Guikit.Input.Key_Up        => (Grid_Step, Guikit.Input.Move_Up),
         when Guikit.Input.Key_Down      => (Grid_Step, Guikit.Input.Move_Down),
         when Guikit.Input.Key_Home      => (Move => Grid_First, others => <>),
         when Guikit.Input.Key_End       => (Move => Grid_Last, others => <>),
         when Guikit.Input.Key_Page_Up   => (Move => Grid_Page_Up, others => <>),
         when Guikit.Input.Key_Page_Down => (Move => Grid_Page_Down, others => <>),
         when others                     => (others => <>));

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

   --  The region a wheel step or a scrollbar drag moves. No_Scroll_Target is
   --  over no scrollable region, and for the window's drag state, no drag.
   type Scroll_Target is
     (No_Scroll_Target,
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
            Scroll_Area        : Scroll_Target := No_Scroll_Target;
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
            Focus_Target    : Files.UI_Types.Focus_Target := Files.UI_Types.Focus_None;
            Cursor_Position : Natural := 0;
            --  The item whose rename field was clicked (0 for another field).
            Field_Item      : Natural := 0;
         when Settings_Click_Input_Action | Command_Result_Click_Input_Action =>
            --  Where the click landed, for the component's own hit test.
            Click_X : Integer := 0;
            Click_Y : Integer := 0;
         when Item_Click_Input_Action =>
            --  Which modifiers toggle or extend the selection is the
            --  controller's (Handle_Item_Click), read from the click's own.
            Item_Index      : Natural := 0;
            Activate        : Boolean := False;
         when Item_Drop_Input_Action =>
            --  The item a drag of the selection was released on; the
            --  release's Ctrl copies, otherwise the selection moves.
            Drop_Target : Natural := 0;
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
         when Context_Menu_Command_Input_Action =>
            --  The command of the context-menu row clicked.
            Menu_Command : Files.Commands.Command_Id := Files.Commands.No_Command;
         when Right_Click_Input_Action =>
            --  Where the context menu opens, what lies there, and the item
            --  drawn there in the snapshot (0 for none).
            Menu_X      : Natural := 0;
            Menu_Y      : Natural := 0;
            Clicked_On  : Right_Click_Target := Elsewhere;
            Target_Item : Natural := 0;
         when No_Input_Action
            | Path_Favorite_Toggle_Input_Action
            | Tree_Pick_Confirm_Input_Action
            | Foreground_Job_Cancel_Input_Action
            | Search_Scope_Toggle_Input_Action =>
            null;
      end case;
   end record;

end Files.Input_Actions;
