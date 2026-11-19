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
     Files.Types.Real_Color_Label'Pos (Files.Types.Real_Color_Label'Last)
     - Files.Types.Real_Color_Label'Pos (Files.Types.Real_Color_Label'First) + 2;

   --  The label picker's clear (No_Label) swatch: the last one.
   Clear_Swatch : constant := Swatch_Count;

   --  The label picker's swatches in order: one per real color, then the
   --  clear swatch (No_Label). The one mapping the renderer, the hit-test
   --  and the model's keyboard highlight share.
   --
   --  @param Index One-based swatch index.
   --  @return The label that swatch sets.
   function Label_For_Swatch (Index : Positive) return Files.Types.Color_Label is
     (if Index <= Files.Types.Real_Color_Label'Pos (Files.Types.Real_Color_Label'Last)
      then Files.Types.Color_Label'Val (Index)
      else Files.Types.No_Label);

end Files.UI_Types;
