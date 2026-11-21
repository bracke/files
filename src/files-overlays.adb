with Files.Settings_Form;

with Guikit.Command_Palette;

with Files.Command_Palette;
with Files.Localization;
with Files.Settings;
with Files.Model.Command_Palette;
with Files.Model.Settings_Pane;

package body Files.Overlays is

   use Ada.Strings.Unbounded;
   use type Files.Model.Palette_Mode;

   procedure Build_Palette_Frame
     (Model         : in out Files.Model.Window_Model;
      Region        : Overlay_Region;
      Focused       : Boolean;
      Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
      Icons         : out Guikit.Draw.Icon_Command_Vectors.Vector;
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector)
   is
      procedure Draw (Palette : in out Guikit.Command_Palette.Palette) is
      begin
         Guikit.Command_Palette.Build_Frame
           (P             => Palette,
            Region_X      => Region.X,
            Region_Y      => Region.Y,
            Region_Width  => Region.Width,
            Region_Height => Region.Height,
            Clip_Width    => Region.Clip_Width,
            Clip_Height   => Region.Clip_Height,
            Focused       => Focused,
            Hover_X       => -1,
            Hover_Y       => -1,
            Rectangles    => Rectangles,
            Text          => Text,
            Icons         => Icons,
            Accessibility => Accessibility);
      end Draw;
   begin
      --  An out vector keeps what it held (it is passed by reference): the
      --  frame replaces the previous one, it is not added to it.
      Rectangles.Clear;
      Text.Clear;
      Icons.Clear;
      Accessibility.Clear;
      --  The commands in the current language, listed here: the model does
      --  not localize.
      Files.Command_Palette.Ensure_Listed (Model);
      Files.Model.Command_Palette.With_Panel
        (Model,
         Region.Line_Height,
         Title       =>
           Files.Localization.Text
             (if Files.Model.Command_Palette.Mode_Of (Model) = Files.Model.Palette_Open_With
              then "command_palette.title.open_with"
              else "command_palette.title"),
         Empty_State => Files.Localization.Text ("command.palette.empty"),
         Close_Label => Files.Localization.Text ("command.action.close"),
         Draw        => Draw'Access);
   end Build_Palette_Frame;

   --  The settings frame drawn from Fields.
   procedure Draw_Settings_Frame
     (Model         : in out Files.Model.Window_Model;
      Region        : Overlay_Region;
      Focused       : Boolean;
      Hover_X       : Integer;
      Hover_Y       : Integer;
      Fields        : Guikit.Settings_Panel.Field_Vectors.Vector;
      Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector)
   is
      Config : Guikit.Settings_Panel.Configuration;
      Draft  : constant Files.Settings.Settings_Draft := Files.Model.Settings_Pane.Draft_Of (Model);

      procedure Draw (Panel : in out Guikit.Settings_Panel.Panel) is
      begin
         Guikit.Settings_Panel.Build_Frame
           (P             => Panel,
            Region_X      => Region.X,
            Region_Y      => Region.Y,
            Region_Width  => Region.Width,
            Region_Height => Region.Height,
            Clip_Width    => Region.Clip_Width,
            Clip_Height   => Region.Clip_Height,
            Focused       => Focused,
            Hover_X       => Hover_X,
            Hover_Y       => Hover_Y,
            Rectangles    => Rectangles,
            Text          => Text,
            Accessibility => Accessibility);
      end Draw;
   begin
      --  An out vector keeps what it held (it is passed by reference): the
      --  frame replaces the previous one, it is not added to it.
      Rectangles.Clear;
      Text.Clear;
      Accessibility.Clear;
      Config.Line_Height := Region.Line_Height;
      Config.Title := To_Unbounded_String (Files.Localization.Text ("settings.title"));
      Config.Switch_Tooltip := To_Unbounded_String (Files.Localization.Text ("settings.tabs.hint"));
      Config.Close_Label := To_Unbounded_String (Files.Localization.Text ("command.action.close"));
      if Files.Model.Settings_Pane.Is_Capturing (Model) then
         --  While a chord is being captured, the footer prompts for input
         --  instead of showing any pending validation error.
         Config.Status := To_Unbounded_String (Files.Localization.Text ("settings.shortcut.capturing"));
      elsif not Draft.Valid and then Length (Draft.Error_Key) > 0 then
         Config.Status := To_Unbounded_String (Files.Localization.Text (To_String (Draft.Error_Key)));
         Config.Status_Is_Error := True;
      end if;
      Files.Model.Settings_Pane.With_Panel
        (Model, Config, Fields, Draw'Access);
   end Draw_Settings_Frame;

   procedure Build_Settings_Frame
     (Model         : in out Files.Model.Window_Model;
      Region        : Overlay_Region;
      Focused       : Boolean;
      Hover_X       : Integer := -1;
      Hover_Y       : Integer := -1;
      Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector) is
   begin
      Draw_Settings_Frame
        (Model, Region, Focused, Hover_X, Hover_Y,
         Files.Settings_Form.Fields (Files.Model.Settings_Pane.Draft_Of (Model)),
         Rectangles, Text, Accessibility);
   end Build_Settings_Frame;

   procedure Build_Settings_Frame
     (Model         : in out Files.Model.Window_Model;
      Region        : Overlay_Region;
      Focused       : Boolean;
      Hover_X       : Integer;
      Hover_Y       : Integer;
      Fields        : in out Settings_Fields_Cache;
      Rectangles    : out Guikit.Draw.Rectangle_Command_Vectors.Vector;
      Text          : out Guikit.Draw.Text_Command_Vectors.Vector;
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector)
   is
      Model_Revision    : constant Natural := Files.Model.Revision (Model);
      Settings_Revision : constant Natural := Files.Model.Settings_Revision (Model);
      Locale            : constant String := Files.Localization.System_Locale;
   begin
      if not Fields.Known
        or else Fields.Model_Revision /= Model_Revision
        or else Fields.Settings_Revision /= Settings_Revision
        or else To_String (Fields.Locale) /= Locale
      then
         Fields.Fields := Files.Settings_Form.Fields (Files.Model.Settings_Pane.Draft_Of (Model));
         Fields.Model_Revision := Model_Revision;
         Fields.Settings_Revision := Settings_Revision;
         Fields.Locale := To_Unbounded_String (Locale);
         Fields.Known := True;
         Fields.Build_Count := Fields.Build_Count + 1;
      end if;
      Draw_Settings_Frame
        (Model, Region, Focused, Hover_X, Hover_Y, Fields.Fields, Rectangles, Text, Accessibility);
   end Build_Settings_Frame;

end Files.Overlays;
