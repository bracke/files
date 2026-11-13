with Files.Model.Support;

package body Files.Model.Label_Picker is

   use Files.Model.Support;

   procedure Open
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Claim_Overlay_Input (Model);
      --  Start the keyboard highlight on the clear swatch; the item's current
      --  label lives in the settings, which this model operation does not see.
      Model.Label_Picker := (Open => True, Swatch => Files.Types.Clear_Swatch);
   end Open;

   procedure Close
     (Model : in out Window_Model)
     renames Files.Model.Support.Close_Label_Picker;

   function Is_Open
     (Model : Window_Model)
      return Boolean is
     (Model.Label_Picker.Open);

   procedure Move_Highlight
     (Model : in out Window_Model;
      Delta_Value : Integer) is
   begin
      Touch (Model);
      Model.Label_Picker.Swatch :=
        Integer'Max (1, Integer'Min (Files.Types.Swatch_Count, Model.Label_Picker.Swatch + Delta_Value));
   end Move_Highlight;

   function Highlight
     (Model : Window_Model)
      return Positive is
     (Model.Label_Picker.Swatch);

   function Highlight_Color
     (Model : Window_Model)
      return Files.Types.Color_Label is
     (Files.Types.Label_For_Swatch (Model.Label_Picker.Swatch));

end Files.Model.Label_Picker;
