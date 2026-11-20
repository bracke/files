with Files.UI_Types;
with Files.Model.Support;

package body Files.Model.Settings_Pane is

   use Files.Model.Support;

   procedure Close
     (Model : in out Window_Model)
     renames Files.Model.Support.Close_Settings_Pane;

   function Is_Open
     (Model : Window_Model)
      return Boolean is
     (Model.Settings_Pane_Open);

   procedure Begin_Edit
     (Model  : in out Window_Model;
      Draft  : Files.Settings.Settings_Draft;
      Fields : Guikit.Settings_Panel.Field_Vectors.Vector) is
   begin
      Touch (Model);
      Model.Settings_Draft_Value := Draft;
      Model.Settings_Saved_Value := Draft;
      Model.Settings_Pane_Open := True;
      Claim_Overlay_Input (Model);
      Clear_Edit_State (Model);
      Clear_Root_Selector_State (Model);
      Hide_Command_Palette (Model);
      Guikit.Settings_Panel.Reset (Model.Settings_Panel_View);
      Guikit.Settings_Panel.Set_Fields (Model.Settings_Panel_View, Fields);
      Model.Focus_Value := Files.UI_Types.Focus_Settings_Input;
   end Begin_Edit;

   function Draft_Of
     (Model : Window_Model)
      return Files.Settings.Settings_Draft is
     (Model.Settings_Draft_Value);

   procedure Set_Draft
     (Model  : in out Window_Model;
      Draft  : Files.Settings.Settings_Draft;
      Fields : Guikit.Settings_Panel.Field_Vectors.Vector) is
   begin
      Touch (Model);
      Model.Settings_Draft_Value := Draft;
      Guikit.Settings_Panel.Set_Fields (Model.Settings_Panel_View, Fields);
   end Set_Draft;

   function Saved_Of
     (Model : Window_Model)
      return Files.Settings.Settings_Draft is
     (Model.Settings_Saved_Value);

   procedure Set_Saved
     (Model : in out Window_Model;
      Saved : Files.Settings.Settings_Draft) is
   begin
      Model.Settings_Saved_Value := Saved;
   end Set_Saved;

   procedure Move_Focus (Model : in out Window_Model; Delta_Rows : Integer) is
   begin
      Touch (Model);
      Guikit.Settings_Panel.Move_Focus (Model.Settings_Panel_View, Delta_Rows);
   end Move_Focus;

   procedure Cycle_Choice (Model : in out Window_Model; Forward : Boolean) is
   begin
      Touch (Model);
      Guikit.Settings_Panel.Cycle_Choice (Model.Settings_Panel_View, Forward);
   end Cycle_Choice;

   procedure Set_Focused_Value (Model : in out Window_Model; Text : String) is
   begin
      Touch (Model);
      Guikit.Settings_Panel.Set_Focused_Value (Model.Settings_Panel_View, Text);
   end Set_Focused_Value;

   procedure Scroll (Model : in out Window_Model; Lines : Integer) is
   begin
      Touch (Model);
      Guikit.Settings_Panel.Scroll (Model.Settings_Panel_View, Lines);
   end Scroll;

   function Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean is
      Clicked : constant Boolean :=
        Guikit.Settings_Panel.Click (Model.Settings_Panel_View, X, Y);
   begin
      if Clicked then
         Touch (Model);
      end if;
      return Clicked;
   end Click;

   function Take_Change (Model : in out Window_Model) return Guikit.Settings_Panel.Change is
   begin
      Touch (Model);
      return Guikit.Settings_Panel.Take_Change (Model.Settings_Panel_View);
   end Take_Change;

   function Focused_Value (Model : Window_Model) return String is
     (Guikit.Settings_Panel.Focused_Value (Model.Settings_Panel_View));

   function Focused_Kind (Model : Window_Model) return Guikit.Settings_Panel.Field_Kind is
     (Guikit.Settings_Panel.Focused_Kind (Model.Settings_Panel_View));

   function Focused_Key (Model : Window_Model) return String is
     (Guikit.Settings_Panel.Focused_Key (Model.Settings_Panel_View));

   procedure Set_Active_Section (Model : in out Window_Model; Ordinal : Natural) is
   begin
      Touch (Model);
      Guikit.Settings_Panel.Set_Active_Section (Model.Settings_Panel_View, Ordinal);
   end Set_Active_Section;

   function Section_Count (Model : Window_Model) return Natural is
     (Guikit.Settings_Panel.Section_Count (Model.Settings_Panel_View));

   function Active_Section (Model : Window_Model) return Natural is
     (Guikit.Settings_Panel.Active_Section (Model.Settings_Panel_View));

   procedure Begin_Capture (Model : in out Window_Model) is
   begin
      Touch (Model);
      Guikit.Settings_Panel.Begin_Capture (Model.Settings_Panel_View);
   end Begin_Capture;

   function Is_Capturing (Model : Window_Model) return Boolean is
     (Guikit.Settings_Panel.Is_Capturing (Model.Settings_Panel_View));

   function Capturing_Key (Model : Window_Model) return String is
     (Guikit.Settings_Panel.Capturing_Key (Model.Settings_Panel_View));

   procedure Set_Captured_Shortcut (Model : in out Window_Model; Text : String) is
   begin
      Touch (Model);
      Guikit.Settings_Panel.Set_Captured_Shortcut (Model.Settings_Panel_View, Text);
   end Set_Captured_Shortcut;

   procedure With_Panel
     (Model  : in out Window_Model;
      Config : Guikit.Settings_Panel.Configuration;
      Fields : Guikit.Settings_Panel.Field_Vectors.Vector;
      Draw   : not null access procedure (Panel : in out Guikit.Settings_Panel.Panel)) is
   begin
      Guikit.Settings_Panel.Set_Configuration (Model.Settings_Panel_View, Config);
      Guikit.Settings_Panel.Set_Fields (Model.Settings_Panel_View, Fields);
      Draw (Model.Settings_Panel_View);
   end With_Panel;

   procedure Cancel_Capture (Model : in out Window_Model) is
   begin
      Touch (Model);
      Guikit.Settings_Panel.Cancel_Capture (Model.Settings_Panel_View);
   end Cancel_Capture;

end Files.Model.Settings_Pane;
