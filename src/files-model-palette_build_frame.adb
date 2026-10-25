with Files.Command_Palette;
separate (Files.Model)
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
   --  Refresh the config (line height) each frame, and the command list (its
   --  enablement) after any model change; the component preserves the query
   --  and selection.
   Guikit.Command_Palette.Set_Configuration
     (Model.Command_Palette_View, Palette_Config (Line_Height, Model.Command_Palette_Mode));
   if Model.Palette_Listed_Revision /= Model.Revision_Value then
      Guikit.Command_Palette.Set_Commands
        (Model.Command_Palette_View, Files.Command_Palette.Commands (Model));
      Model.Palette_Listed_Revision := Model.Revision_Value;
   end if;
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
