--  The label picker state of Files.Model, extracted into a
--  concern child. A private child; the parent renames these to keep the
--  public API stable.
private package Files.Model.Label_Picker is

   --  Replace the stored "Open With" target paths.
   --
   --  @param Model Model to update.
   --  @param Targets Full paths the chosen application should open.
   procedure Set_Open_With_Targets
     (Model   : in out Window_Model;
      Targets : Files.Types.String_Vectors.Vector);

   --  Return the stored "Open With" target paths.
   --
   --  @param Model Model to inspect.
   --  @return Full paths captured for the "Open With" picker.
   function Open_With_Targets
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector;

   --  Open the color-label swatch picker overlay. The chosen label is applied to
   --  the current selection by the interaction reducer when a swatch is clicked.
   --
   --  @param Model Model to update.
   procedure Open_Label_Picker
     (Model : in out Window_Model);

   --  Close the color-label swatch picker overlay.
   --
   --  @param Model Model to update.
   procedure Close_Label_Picker
     (Model : in out Window_Model);

   --  Return whether the color-label swatch picker overlay is open.
   --
   --  @param Model Model to inspect.
   --  @return True when the label picker is active.
   function Label_Picker_Is_Open
     (Model : Window_Model)
      return Boolean;

end Files.Model.Label_Picker;
