--  The colour-label picker overlay and its keyboard highlight.
package Files.Model.Label_Picker is

   --  Open the color-label swatch picker overlay. The chosen label is applied to
   --  the current selection by the interaction reducer when a swatch is clicked.
   --
   --  @param Model Model to update.
   procedure Open
     (Model : in out Window_Model);

   --  Close the color-label swatch picker overlay.
   --
   --  @param Model Model to update.
   procedure Close
     (Model : in out Window_Model);

   --  Return whether the color-label swatch picker overlay is open.
   --
   --  @param Model Model to inspect.
   --  @return True when the label picker is active.
   function Is_Open
     (Model : Window_Model)
      return Boolean;

   --  Move the keyboard highlight across the label picker's swatches (one per
   --  real color, then Files.Types.Clear_Swatch), clamped to
   --  1 .. Files.Types.Swatch_Count.
   --
   --  @param Model Model to update.
   --  @param Delta_Value Signed number of swatches to move.
   procedure Move_Highlight
     (Model : in out Window_Model;
      Delta_Value : Integer);

   --  The one-based index of the highlighted label-picker swatch, for rendering.
   --
   --  @param Model Model to inspect.
   --  @return Highlighted swatch index in 1 .. Files.Types.Swatch_Count.
   function Highlight
     (Model : Window_Model)
      return Positive;

   --  The color label the highlighted swatch chooses (No_Label for the clear
   --  swatch), for applying a keyboard confirmation.
   --
   --  @param Model Model to inspect.
   --  @return Color label under the highlight.
   function Highlight_Color
     (Model : Window_Model)
      return Files.Types.Color_Label;

end Files.Model.Label_Picker;
