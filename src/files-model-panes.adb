with Files.Model.Support;
with Files.Localization;
with Files.Settings_Form;

package body Files.Model.Panes is
   use Files.Model.Support;
   use type Files.Types.Focus_Target;
   use Ada.Strings.Unbounded;

   procedure Toggle_Info_Pane
     (Model : in out Window_Model) is
   begin
      Model.Info_Pane_Open := not Model.Info_Pane_Open;
      Model.Info_Pane_Scroll := 0;
   end Toggle_Info_Pane;

   procedure Ensure_Selected_Item_Extra
     (Model : in out Window_Model)
   is
      Idx : constant Natural := Model.Selected_Item_Index;
   begin
      if not Model.Info_Pane_Open
        or else Idx = 0
        or else Idx > Natural (Model.Items.Length)
      then
         return;
      end if;
      declare
         Item : Files.File_System.Directory_Item := Model.Items.Element (Idx);
      begin
         if Length (Item.Filetype_Extra) = 0 then
            Item.Filetype_Extra :=
              To_Unbounded_String
                (Files.File_System.Extra_Info_Token
                   (To_String (Item.Full_Path), Item.Kind, To_String (Item.Filetype)));
            Model.Items.Replace_Element (Idx, Item);
         end if;
      end;
   end Ensure_Selected_Item_Extra;

   function Info_Pane_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Info_Pane_Open;
   end Info_Pane_Is_Open;

   procedure Toggle_Settings_Pane
     (Model : in out Window_Model) is
   begin
      Model.Settings_Pane_Open := not Model.Settings_Pane_Open;
      if Model.Settings_Pane_Open then
         Clear_Edit_State (Model);
         Clear_Root_Selector_State (Model);
         Model.Command_Palette_Open := False;
         Guikit.Command_Palette.Reset (Model.Command_Palette_View);
         Reset_Settings_Panel (Model);
         Model.Focus_Value := Files.Types.Focus_Settings_Input;
      elsif Model.Focus_Value = Files.Types.Focus_Settings_Input then
         Model.Focus_Value := Files.Types.Focus_None;
      end if;
   end Toggle_Settings_Pane;

   function Settings_Pane_Is_Open
     (Model : Window_Model)
      return Boolean is
   begin
      return Model.Settings_Pane_Open;
   end Settings_Pane_Is_Open;

   procedure Begin_Settings_Edit
     (Model : in out Window_Model;
      Draft : Files.Settings.Settings_Draft)
   is
      Normalized_Draft : Files.Settings.Settings_Draft := Draft;
   begin
      Normalize_Settings_Draft (Normalized_Draft);
      Model.Settings_Draft_Value := Normalized_Draft;
      Model.Settings_Pane_Open := True;
      Clear_Edit_State (Model);
      Clear_Root_Selector_State (Model);
      Model.Command_Palette_Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette_View);
      Reset_Settings_Panel (Model);
      Model.Focus_Value := Files.Types.Focus_Settings_Input;
   end Begin_Settings_Edit;

   function Settings_Draft_Of
     (Model : Window_Model)
      return Files.Settings.Settings_Draft is
   begin
      return Model.Settings_Draft_Value;
   end Settings_Draft_Of;

   procedure Set_Settings_Draft
     (Model : in out Window_Model;
      Draft : Files.Settings.Settings_Draft)
   is
      Normalized_Draft : Files.Settings.Settings_Draft := Draft;
   begin
      Normalize_Settings_Draft (Normalized_Draft);
      Model.Settings_Draft_Value := Normalized_Draft;
   end Set_Settings_Draft;

   procedure Settings_Move_Focus (Model : in out Window_Model; Delta_Rows : Integer) is
   begin
      Guikit.Settings_Panel.Move_Focus (Model.Settings_Panel_View, Delta_Rows);
   end Settings_Move_Focus;

   procedure Settings_Cycle_Choice (Model : in out Window_Model; Forward : Boolean) is
   begin
      Guikit.Settings_Panel.Cycle_Choice (Model.Settings_Panel_View, Forward);
   end Settings_Cycle_Choice;

   procedure Settings_Set_Focused_Value (Model : in out Window_Model; Text : String) is
   begin
      Guikit.Settings_Panel.Set_Focused_Value (Model.Settings_Panel_View, Text);
   end Settings_Set_Focused_Value;

   procedure Settings_Scroll (Model : in out Window_Model; Lines : Integer) is
   begin
      Guikit.Settings_Panel.Scroll (Model.Settings_Panel_View, Lines);
   end Settings_Scroll;

   function Settings_Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean is
   begin
      return Guikit.Settings_Panel.Click (Model.Settings_Panel_View, X, Y);
   end Settings_Click;

   function Settings_Take_Change (Model : in out Window_Model) return Guikit.Settings_Panel.Change is
   begin
      return Guikit.Settings_Panel.Take_Change (Model.Settings_Panel_View);
   end Settings_Take_Change;

   function Settings_Focused_Value (Model : Window_Model) return String is
   begin
      return Guikit.Settings_Panel.Focused_Value (Model.Settings_Panel_View);
   end Settings_Focused_Value;

   procedure Settings_Set_Active_Section (Model : in out Window_Model; Ordinal : Natural) is
   begin
      Guikit.Settings_Panel.Set_Active_Section (Model.Settings_Panel_View, Ordinal);
   end Settings_Set_Active_Section;

   function Settings_Section_Count (Model : Window_Model) return Natural is
   begin
      return Guikit.Settings_Panel.Section_Count (Model.Settings_Panel_View);
   end Settings_Section_Count;

   function Settings_Active_Section (Model : Window_Model) return Natural is
   begin
      return Guikit.Settings_Panel.Active_Section (Model.Settings_Panel_View);
   end Settings_Active_Section;

   procedure Settings_Begin_Capture (Model : in out Window_Model) is
   begin
      Guikit.Settings_Panel.Begin_Capture (Model.Settings_Panel_View);
   end Settings_Begin_Capture;

   function Settings_Is_Capturing (Model : Window_Model) return Boolean is
   begin
      return Guikit.Settings_Panel.Is_Capturing (Model.Settings_Panel_View);
   end Settings_Is_Capturing;

   function Settings_Capturing_Key (Model : Window_Model) return String is
   begin
      return Guikit.Settings_Panel.Capturing_Key (Model.Settings_Panel_View);
   end Settings_Capturing_Key;

   procedure Settings_Set_Captured_Shortcut (Model : in out Window_Model; Text : String) is
   begin
      Guikit.Settings_Panel.Set_Captured_Shortcut (Model.Settings_Panel_View, Text);
   end Settings_Set_Captured_Shortcut;

   procedure Settings_Cancel_Capture (Model : in out Window_Model) is
   begin
      Guikit.Settings_Panel.Cancel_Capture (Model.Settings_Panel_View);
   end Settings_Cancel_Capture;

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

   procedure Scroll_Info_Pane
     (Model : in out Window_Model;
      Lines : Integer) is
   begin
      if not Model.Info_Pane_Open or else Lines = 0 then
         return;
      elsif Lines < 0 then
         declare
            Step : constant Natural := Scroll_Step (Lines);
         begin
            if Step >= Model.Info_Pane_Scroll then
               Model.Info_Pane_Scroll := 0;
            else
               Model.Info_Pane_Scroll := Model.Info_Pane_Scroll - Step;
            end if;
         end;
      else
         Model.Info_Pane_Scroll := Saturating_Add (Model.Info_Pane_Scroll, Scroll_Step (Lines));
      end if;
   end Scroll_Info_Pane;

   function Info_Pane_Scroll_Lines
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Info_Pane_Scroll;
   end Info_Pane_Scroll_Lines;

   procedure Set_Info_Pane_Scroll_Lines
     (Model : in out Window_Model;
      Lines : Natural) is
   begin
      Model.Info_Pane_Scroll := Lines;
   end Set_Info_Pane_Scroll_Lines;

   procedure Set_Main_View_Scroll_Lines
     (Model : in out Window_Model;
      Lines : Natural) is
   begin
      Model.Main_View_Scroll := Lines;
   end Set_Main_View_Scroll_Lines;

   procedure Scroll_Main_View
     (Model : in out Window_Model;
      Lines : Integer) is
   begin
      if Lines = 0 then
         return;
      elsif Lines < 0 then
         declare
            Step : constant Natural := Scroll_Step (Lines);
         begin
            if Step >= Model.Main_View_Scroll then
               Model.Main_View_Scroll := 0;
            else
               Model.Main_View_Scroll := Model.Main_View_Scroll - Step;
            end if;
         end;
      else
         Model.Main_View_Scroll := Saturating_Add (Model.Main_View_Scroll, Scroll_Step (Lines));
      end if;
   end Scroll_Main_View;

   function Main_View_Scroll_Lines
     (Model : Window_Model)
      return Natural is
   begin
      return Model.Main_View_Scroll;
   end Main_View_Scroll_Lines;

end Files.Model.Panes;
