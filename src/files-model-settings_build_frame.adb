separate (Files.Model)
   procedure Settings_Build_Frame
     (Model         : in out Window_Model;
      Region_X      : Natural;
      Region_Y      : Natural;
      Region_Width  : Natural;
      Region_Height : Natural;
      Clip_Width    : Natural;
      Clip_Height   : Natural;
      Line_Height   : Positive;
      Focused       : Boolean;
      Hover_X       : Integer := -1;
      Hover_Y       : Integer := -1;
      Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector)
   is
      Config : Guikit.Settings_Panel.Configuration;
   begin
      Model.Revision_Value := Model.Revision_Value + 1;
      Config.Line_Height := Line_Height;
      Config.Title := To_Unbounded_String (Files.Localization.Text ("settings.title"));
      Config.Switch_Tooltip := To_Unbounded_String (Files.Localization.Text ("settings.tabs.hint"));
      if Guikit.Settings_Panel.Is_Capturing (Model.Settings_Panel_View) then
         --  While a chord is being captured, the footer prompts for input
         --  instead of showing any pending validation error.
         Config.Status := To_Unbounded_String (Files.Localization.Text ("settings.shortcut.capturing"));
      elsif not Model.Settings_Draft_Value.Valid
        and then Length (Model.Settings_Draft_Value.Error_Key) > 0
      then
         Config.Status :=
           To_Unbounded_String (Files.Localization.Text (To_String (Model.Settings_Draft_Value.Error_Key)));
         Config.Status_Is_Error := True;
      end if;
      Guikit.Settings_Panel.Set_Configuration (Model.Settings_Panel_View, Config);
      Guikit.Settings_Panel.Set_Fields (Model.Settings_Panel_View, Files.Settings_Form.Fields (Model));
      Guikit.Settings_Panel.Build_Frame
        (P             => Model.Settings_Panel_View,
         Region_X      => Region_X,
         Region_Y      => Region_Y,
         Region_Width  => Region_Width,
         Region_Height => Region_Height,
         Clip_Width    => Clip_Width,
         Clip_Height   => Clip_Height,
         Focused       => Focused,
         Hover_X       => Hover_X,
         Hover_Y       => Hover_Y,
         Rectangles    => Rectangles,
         Text          => Text,
         Accessibility => Accessibility);
   end Settings_Build_Frame;
