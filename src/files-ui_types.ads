with Files.Preference_Types;
with Files.Types;

--  Window-state value types that only the model, input and rendering layers
--  use: which text field has the keyboard, which overlays own input and how
--  they stack, which context menu is open, and the label picker's swatches.
--  Kept apart from Files.Types, which the I/O layer shares, so a change to
--  the interface's state never recompiles the units that read and write disk.
package Files.UI_Types is

   --  Which text field of a window takes typed text and the caret, or none.
   type Focus_Target is
     (Focus_None,
      Focus_Path_Input,
      Focus_Filter_Input,
      Focus_Rename_Input,
      Focus_Command_Palette,
      Focus_Settings_Input,
      Focus_Ownership_Input);

   --  The transient surfaces that own window input while open. A new overlay
   --  is added here, to Overlay_Stack, to Files.Model.Overlay_Is_Open and to
   --  Files.Rendering.Overlay_Open (the snapshot's view of the same flags);
   --  the compiler then asks for it in every case over this type.
   type Input_Overlay is
     (Settings_Pane_Overlay,
      Command_Palette_Overlay,
      Root_Selector_Overlay,
      Sort_Menu_Overlay,
      Context_Menu_Overlay,
      Label_Picker_Overlay,
      Quick_Look_Overlay,
      Tree_Pick_Overlay,
      Paste_Conflict_Overlay,
      Foreground_Job_Overlay);

   --  Overlays listed in some order.
   type Overlay_Order is array (Positive range <>) of Input_Overlay;

   --  Every overlay, top to bottom as they stack: the paste dialogs over
   --  everything, then the window layer's palette over its settings pane,
   --  then the frame's popups in the reverse of their drawing order, and the
   --  tree pick, which is part of the frame itself. The one order the model
   --  (Files.Model.Topmost_Overlay), the keyboard and the pointer all follow.
   Overlay_Stack : constant Overlay_Order :=
     [Foreground_Job_Overlay, Paste_Conflict_Overlay, Command_Palette_Overlay, Settings_Pane_Overlay,
      Context_Menu_Overlay, Root_Selector_Overlay, Sort_Menu_Overlay, Label_Picker_Overlay,
      Quick_Look_Overlay, Tree_Pick_Overlay];

   --  Which right-click context menu is open: on an item, on the empty area
   --  of a folder, on a column header -- or none.
   type Context_Menu_Target is
     (Context_Menu_None,
      Context_Menu_Item,
      Context_Menu_Empty,
      Context_Menu_Header);

   --  The label picker's swatch count: one per real color, then the clear
   --  swatch.
   Swatch_Count : constant :=
     Files.Preference_Types.Real_Color_Label'Pos (Files.Preference_Types.Real_Color_Label'Last)
     - Files.Preference_Types.Real_Color_Label'Pos (Files.Preference_Types.Real_Color_Label'First) + 2;

   --  The label picker's clear (No_Label) swatch: the last one.
   Clear_Swatch : constant := Swatch_Count;

   --  The label picker's swatches in order: one per real color, then the
   --  clear swatch (No_Label). The one mapping the renderer, the hit-test
   --  and the model's keyboard highlight share.
   --
   --  @param Index One-based swatch index.
   --  @return The label that swatch sets.
   function Label_For_Swatch (Index : Positive) return Files.Preference_Types.Color_Label is
     (if Index <= Files.Preference_Types.Real_Color_Label'Pos (Files.Preference_Types.Real_Color_Label'Last)
      then Files.Preference_Types.Color_Label'Val (Index)
      else Files.Preference_Types.No_Label);

   --  The sort menu's rows: one per sort field (Files.Types.Sort_Field), in
   --  declaration order. The model's keyboard highlight and the layout's
   --  rows both go through these, so a field added is a row added everywhere.
   Sort_Menu_Rows : constant Positive := Files.Types.Sort_Field'Pos (Files.Types.Sort_Field'Last) + 1;

   --  @param Field A sort field.
   --  @return Its one-based sort-menu row.
   function Sort_Menu_Row (Field : Files.Types.Sort_Field) return Positive is (Files.Types.Sort_Field'Pos (Field) + 1);

   --  @param Row A one-based sort-menu row.
   --  @return The field that row stands for.
   function Sort_Menu_Field (Row : Positive) return Files.Types.Sort_Field is (Files.Types.Sort_Field'Val (Row - 1))
     with Pre => Row <= Sort_Menu_Rows;

   --  Scope the shared filter-bar query applies to. Filter_Here live-filters the
   --  current directory by name (the default), Search_Names replaces the view
   --  with a recursive name search of the subtree, and Search_Contents replaces
   --  it with a recursive content (grep) search. All three reuse one query text.
   type Search_Scope is
     (Filter_Here,
      Search_Names,
      Search_Contents);

   --  The scopes that search the tree below the current folder, replacing
   --  the view with what they find.
   subtype Tree_Search_Scope is Search_Scope range Search_Names .. Search_Contents;

   --  Return the search scope reached by cycling one step forward, wrapping from
   --  Search_Contents back to Filter_Here.
   --
   --  @param Scope Current search scope.
   --  @return Next search scope in the cycle.
   function Next_Scope (Scope : Search_Scope) return Search_Scope is
     (case Scope is
         when Filter_Here     => Search_Names,
         when Search_Names    => Search_Contents,
         when Search_Contents => Filter_Here);

end Files.UI_Types;
