with Ada.Strings.Unbounded;

with Guikit.Command_Palette;
with Guikit.Settings_Panel;

with Files.Localization;
with Files.Settings;
with Files.Settings_Form;

package body Files.Overlays is

   use Ada.Strings.Unbounded;
   use type Files.Model.Palette_Mode;

   procedure Build_Palette_Frame
     (Model         : in out Files.Model.Window_Model;
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
      Accessibility : out Guikit.Draw.Accessibility_Node_Vectors.Vector)
   is
      procedure Draw (Palette : in out Guikit.Command_Palette.Palette) is
      begin
         Guikit.Command_Palette.Build_Frame
           (P             => Palette,
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
      end Draw;
   begin
      Files.Model.Visit_Command_Palette
        (Model,
         Line_Height,
         Title       =>
           Files.Localization.Text
             (if Files.Model.Command_Palette_Mode_Of (Model) = Files.Model.Palette_Open_With
              then "command_palette.title.open_with"
              else "command_palette.title"),
         Empty_State => Files.Localization.Text ("command.palette.empty"),
         Visit       => Draw'Access);
   end Build_Palette_Frame;

   procedure Build_Settings_Frame
     (Model         : in out Files.Model.Window_Model;
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
      Draft  : constant Files.Settings.Settings_Draft := Files.Model.Settings_Draft_Of (Model);

      procedure Draw (Panel : in out Guikit.Settings_Panel.Panel) is
      begin
         Guikit.Settings_Panel.Build_Frame
           (P             => Panel,
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
      end Draw;
   begin
      Config.Line_Height := Line_Height;
      Config.Title := To_Unbounded_String (Files.Localization.Text ("settings.title"));
      Config.Switch_Tooltip := To_Unbounded_String (Files.Localization.Text ("settings.tabs.hint"));
      if Files.Model.Settings_Panel_Capturing (Model) then
         --  While a chord is being captured, the footer prompts for input
         --  instead of showing any pending validation error.
         Config.Status := To_Unbounded_String (Files.Localization.Text ("settings.shortcut.capturing"));
      elsif not Draft.Valid and then Length (Draft.Error_Key) > 0 then
         Config.Status := To_Unbounded_String (Files.Localization.Text (To_String (Draft.Error_Key)));
         Config.Status_Is_Error := True;
      end if;
      Files.Model.Visit_Settings_Panel (Model, Config, Files.Settings_Form.Fields (Model), Draw'Access);
   end Build_Settings_Frame;

end Files.Overlays;
