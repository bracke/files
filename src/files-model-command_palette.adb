with Files.Model.Support;
with Files.Command_Palette;

package body Files.Model.Command_Palette is
   use Files.Model.Support;
   use type Files.Types.Focus_Target;

   procedure Focus_Command_Palette_Input
     (Model : in out Window_Model) is
   begin
      if Model.Command_Palette_Open then
         Reset_Type_Ahead (Model);
         Model.Focus_Value := Files.Types.Focus_Command_Palette;
      end if;
   end Focus_Command_Palette_Input;

   procedure Open_Command_Palette
     (Model : in out Window_Model) is
   begin
      Model.Command_Palette_Open := True;
      Model.Command_Palette_Mode := Palette_Commands;
      Model.Open_With_Targets_Value.Clear;
      Guikit.Command_Palette.Set_Configuration
        (Model.Command_Palette_View, Palette_Config (20, Palette_Commands));
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Guikit.Command_Palette.Set_Commands
        (Model.Command_Palette_View, Files.Command_Palette.Commands (Model));
      Model.Focus_Value := Files.Types.Focus_Command_Palette;
   end Open_Command_Palette;

   procedure Close_Command_Palette
     (Model : in out Window_Model) is
   begin
      Model.Command_Palette_Open := False;
      Model.Command_Palette_Mode := Palette_Commands;
      Model.Open_With_Targets_Value.Clear;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      if Model.Focus_Value = Files.Types.Focus_Command_Palette then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
   end Close_Command_Palette;

   procedure Toggle_Command_Palette
     (Model : in out Window_Model) is
   begin
      if Model.Command_Palette_Open then
         Close_Command_Palette (Model);
      else
         Open_Command_Palette (Model);
      end if;
   end Toggle_Command_Palette;

   function Command_Palette_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Command_Palette_Open;
   end Command_Palette_Is_Open;

   function Palette_Query (Model : Window_Model) return String is
   begin
      return Guikit.Command_Palette.Query (Model.Command_Palette_View);
   end Palette_Query;

   procedure Palette_Set_Query (Model : in out Window_Model; Text : String) is
   begin
      Guikit.Command_Palette.Set_Query (Model.Command_Palette_View, Text);
   end Palette_Set_Query;

   procedure Palette_Move_Selection (Model : in out Window_Model; Delta_Rows : Integer) is
   begin
      Guikit.Command_Palette.Move_Selection (Model.Command_Palette_View, Delta_Rows);
   end Palette_Move_Selection;

   procedure Palette_Select_First (Model : in out Window_Model) is
   begin
      Guikit.Command_Palette.Select_First (Model.Command_Palette_View);
   end Palette_Select_First;

   procedure Palette_Select_Last (Model : in out Window_Model) is
   begin
      Guikit.Command_Palette.Select_Last (Model.Command_Palette_View);
   end Palette_Select_Last;

   procedure Palette_Page (Model : in out Window_Model; Down : Boolean) is
   begin
      Guikit.Command_Palette.Page (Model.Command_Palette_View, Down);
   end Palette_Page;

   function Palette_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean is
   begin
      return Guikit.Command_Palette.Click (Model.Command_Palette_View, X, Y);
   end Palette_Click;

   function Palette_Selected_Id (Model : Window_Model) return Natural is
   begin
      return Guikit.Command_Palette.Selected_Id (Model.Command_Palette_View);
   end Palette_Selected_Id;

   function Palette_Result_Count (Model : Window_Model) return Natural is
   begin
      return Guikit.Command_Palette.Result_Count (Model.Command_Palette_View);
   end Palette_Result_Count;

   procedure Palette_Build_Frame
     (Model         : in out Window_Model;
      Region_X      : Natural;
      Region_Y      : Natural;
      Region_Width  : Natural;
      Region_Height : Natural;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Line_Height   : Positive;
      Focused       : Boolean;
      Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
      Icons         : out Guikit.Draw.Icon_Command_Vectors.Vector;
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector) is
   begin
      --  Refresh the config (line height) and the command list (fresh enablement)
      --  each frame; the component preserves the query and selection.
      Guikit.Command_Palette.Set_Configuration
        (Model.Command_Palette_View, Palette_Config (Line_Height, Model.Command_Palette_Mode));
      Guikit.Command_Palette.Set_Commands
        (Model.Command_Palette_View, Files.Command_Palette.Commands (Model));
      Guikit.Command_Palette.Build_Frame
        (P             => Model.Command_Palette_View,
         Region_X      => Region_X,
         Region_Y      => Region_Y,
         Region_Width  => Region_Width,
         Region_Height => Region_Height,
         Clip_Width    => Clip_Width,
         Clip_Height   => Clip_Height,
         Focused       => Focused,
         Hover_X       => -1,
         Hover_Y       => -1,
         Rectangles    => Rectangles,
         Text          => Text,
         Icons         => Icons,
         Accessibility => Accessibility);
   end Palette_Build_Frame;

   function Command_Palette_Mode_Of
     (Model : Window_Model)
      return Palette_Mode is
   begin
      return Model.Command_Palette_Mode;
   end Command_Palette_Mode_Of;

   procedure Set_Command_Palette_Mode
     (Model : in out Window_Model;
      Mode  : Palette_Mode) is
   begin
      Model.Command_Palette_Mode := Mode;
      --  The command list is mode-specific; reload it and reset the query.
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Guikit.Command_Palette.Set_Commands
        (Model.Command_Palette_View, Files.Command_Palette.Commands (Model));
   end Set_Command_Palette_Mode;

end Files.Model.Command_Palette;
