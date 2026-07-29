separate (Files.Model)
package body Label_Picker is

   procedure Set_Open_With_Targets
     (Model   : in out Window_Model;
      Targets : Files.Types.String_Vectors.Vector) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Open_With_Targets_Value := Targets;
   end Set_Open_With_Targets;

   function Open_With_Targets
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
   begin
      return Model.Open_With_Targets_Value;
   end Open_With_Targets;

   --  Swatch 8 is the clear/None swatch; swatches 1 .. 7 are Color_Label'Val
   --  1 .. 7 (Red .. Gray). Mirrors Files.Rendering.Label_For_Swatch.
   procedure Open_Label_Picker
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Label_Picker_Active := True;
      --  Start the keyboard highlight on the clear swatch; the item's current
      --  label lives in the settings, which this model operation does not see.
      Model.Label_Picker_Swatch_Value := 8;
   end Open_Label_Picker;

   procedure Move_Label_Picker_Highlight
     (Model : in out Window_Model;
      Delta_Value : Integer) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Label_Picker_Swatch_Value :=
        Integer'Max (1, Integer'Min (8, Model.Label_Picker_Swatch_Value + Delta_Value));
   end Move_Label_Picker_Highlight;

   function Label_Picker_Highlight
     (Model : Window_Model)
      return Positive is
   begin
      return Model.Label_Picker_Swatch_Value;
   end Label_Picker_Highlight;

   function Label_Picker_Highlight_Color
     (Model : Window_Model)
      return Files.Types.Color_Label is
   begin
      if Model.Label_Picker_Swatch_Value in 1 .. 7 then
         return Files.Types.Color_Label'Val (Model.Label_Picker_Swatch_Value);
      else
         return Files.Types.No_Label;
      end if;
   end Label_Picker_Highlight_Color;

   procedure Close_Label_Picker
     (Model : in out Window_Model) is
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Model.Label_Picker_Active := False;
   end Close_Label_Picker;

   function Label_Picker_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Label_Picker_Active;
   end Label_Picker_Is_Open;

end Label_Picker;
