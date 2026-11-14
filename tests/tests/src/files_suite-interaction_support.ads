with Files.Commands;
with Files.Interaction;
with Files.Model;
with Files.Settings;
with Guikit.Input;

--  Headless coverage of the interaction reducer (Files.Interaction) and the
--  sections split from it (Context_Menu, Drags, Tree, Keyboard, Text_Input):
--  each test drives the REAL pipeline the GLFW shell drives -- Sample_Model ->
--  Build_Snapshot -> Build_Frame_Commands -> a layout/hit-test function ->
--  Files.Events.Translate_* -> Files.Interaction.Apply_* -> assert -- without
--  any GPU/GLFW dependency. This package holds what those sections share.
--
--  Anti-fragility rules (the whole point of this seam):
--
--  a. Derive every coordinate from a layout/hit-test function -- never hardcode
--     a pixel (Item_At, Context_Menu_Row_At, Settings_Hit_At, Calculate_Layout;
--     center = Cell.X + Cell.Width/2, ...).
--  b. Assert semantic outcomes only -- Command_Id identity, Model/Settings
--     fields, menu-open/selection state, Interaction_Result flags; prefer
--     Frame_Commands.Accessibility nodes (Role/Selected/Focused/Enabled) over
--     rectangle/color geometry.
--  c. No framebuffer/pixel-hash, no exact-color, no exact-coordinate assertions
--     (geometry is a hit-test input, never an assertion target).
--  d. Exercise the real dispatch functions (Translate_* ->
--     Files.Interaction.Apply_*); never reimplement dispatch or shortcut to a
--     Controller leaf -- that is what lets tests drift.
--  e. Do not copy Has_Rectangle_Colored (Frame, Selection_Color) (rendering
--     test, color identity); use the accessibility-node boolean instead
--     (theme-proof).
package Files_Suite.Interaction_Support is

   --  The window the tests lay out and click in, and its line height.
   Window_W   : constant Natural  := 1000;
   Window_H   : constant Natural  := 800;
   Line       : constant Positive := 20;

   --  The compact window of the targeted-scroll tests: small enough that both
   --  the info pane and the detail view overflow.
   Target_W : constant Natural := 600;
   Target_H : constant Natural := 180;

   Ctrl : constant Guikit.Input.Modifier_Set :=
     [Guikit.Input.Control_Key => True, others => False];

   Shift : constant Guikit.Input.Modifier_Set :=
     [Guikit.Input.Shift_Key => True, others => False];

   Alt : constant Guikit.Input.Modifier_Set :=
     [Guikit.Input.Alt_Key => True, others => False];

   Ctrl_Shift : constant Guikit.Input.Modifier_Set :=
     [Guikit.Input.Control_Key => True, Guikit.Input.Shift_Key => True, others => False];

   --  Center of the cell laid out for visible item Index, derived from the real
   --  item layout (rule a). Returns whether the cell was found.
   --
   --  @param Model The window model.
   --  @param Index The visible item index.
   --  @param X Horizontal position in pixels.
   --  @param Y Vertical position in pixels.
   --  @param Found Whether it was found.
   procedure Item_Center
     (Model  : Files.Model.Window_Model;
      Index  : Positive;
      X      : out Natural;
      Y      : out Natural;
      Found  : out Boolean);

   --  Number of grid-item accessibility nodes currently marked Selected. With no
   --  overlay and the info pane closed these are exactly the main-view items, so
   --  this is a theme-proof proxy for the selection state (rules b and e).
   --
   --  @param Model The window model.
   --  @return The selected items' accessibility nodes.
   function Selected_Item_Nodes (Model : Files.Model.Window_Model) return Natural;

   --  Apply the input action a click at (X, Y) translates to, exactly as the
   --  shell does (rule d).
   --
   --  @param Model The window model.
   --  @param Settings The window settings.
   --  @param X Horizontal position in pixels.
   --  @param Y Vertical position in pixels.
   --  @param Modifiers The modifier keys held.
   --  @param Result What the dispatch did.
   procedure Click
     (Model     : in out Files.Model.Window_Model;
      Settings  : in out Files.Settings.Settings_Model;
      X         : Natural;
      Y         : Natural;
      Modifiers : Guikit.Input.Modifier_Set;
      Result    : out Files.Interaction.Interaction_Result);

   --  Scroll down (negative GLFW offset) at (X, Y) through the real translator.
   --
   --  @param Model The window model.
   --  @param Settings The window settings.
   --  @param X Horizontal position in pixels.
   --  @param Y Vertical position in pixels.
   procedure Scroll_Down_At
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model;
      X        : Natural;
      Y        : Natural);

   --  The targeted-scroll fixture: detail view, Gamma.md selected, info pane open.
   --
   --  @param Model The window model.
   procedure Open_Targeted_Scroll_Fixture (Model : in out Files.Model.Window_Model);

   --  Vertical centre of the main view in the compact targeted-scroll window.
   --
   --  @param Model The window model.
   --  @param Settings The window settings.
   --  @return The vertical position inside the main view.
   function Targeted_Main_Y
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model) return Natural;

   --  Reproduce the model state Test_Scroll_Targets_Pane_Under_Cursor leaves
   --  behind: the fixture, one wheel step over the info pane and one over the
   --  main view, then the main view returned to its top.
   --
   --  @param Model The window model.
   --  @param Settings The window settings.
   procedure Replay_Targeted_Scroll
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model);

   --  Load a real on-disk directory into a fresh window model, exactly as the
   --  controller does when navigating, so disk-backed menu commands operate on
   --  genuine items.
   --
   --  @param Directory The folder to load.
   --  @return The model holding the folder's items.
   function Loaded_Model (Directory : String) return Files.Model.Window_Model;

   --  Position of Name in the displayed order (1-based), or 0 when absent:
   --  Build_Snapshot is the display-order oracle.
   --
   --  @param Model The window model.
   --  @param Settings The window settings.
   --  @param Name The item name.
   --  @return The 1-based display position, or 0.
   function Display_Position_Of
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Name     : String)
      return Natural;

   --  Return the first visible item index currently reported Selected, or zero.
   --
   --  @param Model The window model.
   --  @return The first selected visible index, or 0.
   function First_Selected_Visible (Model : Files.Model.Window_Model) return Natural;

   --  Open the item context menu by right-clicking the cell of the first
   --  selected item, deriving the coordinate from the real item layout (rule a)
   --  and driving the real Apply_Right_Click (rule d).
   --
   --  @param Model The window model.
   --  @param Settings The window settings.
   --  @param Result What the dispatch did.
   procedure Open_Item_Context_Menu
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Result   : out Files.Interaction.Interaction_Result);

   --  Open the empty-area context menu by right-clicking the center of the main
   --  view, which is item-free in the directories these tests build.
   --
   --  @param Model The window model.
   --  @param Settings The window settings.
   --  @param Result What the dispatch did.
   procedure Open_Empty_Context_Menu
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Result   : out Files.Interaction.Interaction_Result);

   --  Resolve a command from the live context-menu layout (rule a), assert the
   --  derived coordinate hit-tests back to that row, then click it through the
   --  real Files.Events.Translate_Click and Interaction.Apply_Input_Action
   --  (rule d). Found is false when the open menu does not offer the command.
   --
   --  @param Model The window model.
   --  @param Settings The window settings.
   --  @param Settings_Path Where settings are saved.
   --  @param Command The command.
   --  @param Result What the dispatch did.
   --  @param Found Whether it was found.
   procedure Dispatch_Menu_Command
     (Model         : in out Files.Model.Window_Model;
      Settings      : in out Files.Settings.Settings_Model;
      Settings_Path : String;
      Command       : Files.Commands.Command_Id;
      Result        : out Files.Interaction.Interaction_Result;
      Found         : out Boolean);

   --  Whether the currently open context menu lists Command in its real
   --  Calculate_Context_Menu_Layout rows (rule a: contents come from the live
   --  layout, never a hardcoded row index).
   --
   --  @param Model The window model.
   --  @param Settings The window settings.
   --  @param Command The command.
   --  @return Whether the open menu offers Command.
   function Menu_Offers
     (Model    : Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model;
      Command  : Files.Commands.Command_Id)
      return Boolean;

   --  Commit the active focused text (rename / create) with Enter through the
   --  controller's key handling (Files.Controller.Handle_Key, which the shell's
   --  Files.Interaction.Handle_Key calls), not a direct Commit_Rename call.
   --
   --  @param Model The window model.
   --  @param Settings The window settings.
   procedure Commit_Focused_Text
     (Model    : in out Files.Model.Window_Model;
      Settings : Files.Settings.Settings_Model);

   --  Dispatch Command through the reducer's command branch -- the same entry the
   --  shell uses for menu-bar and shortcut-less commands (e.g. Undo).
   --
   --  @param Model The window model.
   --  @param Settings The window settings.
   --  @param Command The command.
   --  @param Result What the dispatch did.
   procedure Dispatch_Command
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model;
      Command  : Files.Commands.Command_Id;
      Result   : out Files.Interaction.Interaction_Result);

   --  True when Path is present in the persisted favorites list.
   --
   --  @param Settings The window settings.
   --  @param Path The path.
   --  @return Whether Path is a favorite.
   function Has_Favorite
     (Settings : Files.Settings.Settings_Model;
      Path     : String)
      return Boolean;

   --  Drive the real Select_Drive command through the reducer so the root
   --  selector opens seeded with the platform roots plus the persisted
   --  favorites (each carrying its star label token).
   --
   --  @param Model The window model.
   --  @param Settings The window settings.
   procedure Open_Favorites_Selector
     (Model    : in out Files.Model.Window_Model;
      Settings : in out Files.Settings.Settings_Model);

   --  Click the open selector's row whose root path equals Target_Path, deriving
   --  the coordinate from the real root-path layout (rule a). Found reports
   --  whether such a row existed.
   --
   --  @param Model The window model.
   --  @param Settings The window settings.
   --  @param Target_Path The root path to click.
   --  @param Found Whether it was found.
   --  @param Result What the dispatch did.
   procedure Click_Root_Row
     (Model       : in out Files.Model.Window_Model;
      Settings    : in out Files.Settings.Settings_Model;
      Target_Path : String;
      Found       : out Boolean;
      Result      : out Files.Interaction.Interaction_Result);

end Files_Suite.Interaction_Support;
