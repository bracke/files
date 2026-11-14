with Files.Model.Support;

package body Files.Model.Settings_Pane is

   use Ada.Strings.Unbounded;
   use Files.Model.Support;

   --  The number of complete key/value pairs across two parallel lists (the
   --  shorter of the two lengths).
   --
   --  @param Keys Key list.
   --  @param Values Value list.
   --  @return Min of the two list lengths.
   function Pair_Count
     (Keys   : Files.Types.String_Vectors.Vector;
      Values : Files.Types.String_Vectors.Vector)
      return Natural is
   begin
      return Natural'Min (Natural (Keys.Length), Natural (Values.Length));
   end Pair_Count;

   --  Truncate Values to at most Count entries.
   --
   --  @param Values List to truncate in place.
   --  @param Count Maximum number of entries to keep.
   procedure Trim_To_Count
     (Values : in out Files.Types.String_Vectors.Vector;
      Count  : Natural) is
   begin
      while Natural (Values.Length) > Count loop
         Values.Delete (Natural (Values.Length));
      end loop;
   end Trim_To_Count;

   --  Bring a settings draft into a consistent state: pair up its parallel
   --  key/value mapping lists to equal length and clamp each selection index.
   --
   --  @param Draft Settings draft to normalize in place.
   procedure Normalize_Settings_Draft
     (Draft : in out Files.Settings.Settings_Draft)
   is
      procedure Normalize_Pair
        (Keys          : in out Files.Types.String_Vectors.Vector;
         Values        : in out Files.Types.String_Vectors.Vector;
         Index         : in out Natural;
         Selected_Key   : out Unbounded_String;
         Selected_Value : out Unbounded_String)
      is
         Count : constant Natural := Pair_Count (Keys, Values);
      begin
         Trim_To_Count (Keys, Count);
         Trim_To_Count (Values, Count);
         if Count = 0 then
            Index := 0;
            Selected_Key := Null_Unbounded_String;
            Selected_Value := Null_Unbounded_String;
         else
            if Index = 0 or else Index > Count then
               Index := 1;
            end if;
            Selected_Key := Keys.Element (Index);
            Selected_Value := Values.Element (Index);
         end if;
      end Normalize_Pair;
   begin
      Normalize_Pair
        (Draft.Filetype_Keys,
         Draft.Filetype_Values,
         Draft.Filetype_Index,
         Draft.Filetype_Extension,
         Draft.Filetype_Value);
      Normalize_Pair
        (Draft.Icon_Keys,
         Draft.Icon_Values,
         Draft.Icon_Index,
         Draft.Icon_Filetype,
         Draft.Icon_Value);
      Normalize_Pair
        (Draft.Open_Action_Keys,
         Draft.Open_Action_Commands,
         Draft.Open_Action_Index,
         Draft.Open_Action_Token,
         Draft.Open_Action_Command);
   end Normalize_Settings_Draft;

   procedure Toggle
     (Model : in out Window_Model)
     renames Files.Model.Support.Toggle_Settings_Pane;

   function Is_Open
     (Model : Window_Model)
      return Boolean is
     (Model.Settings_Pane_Open);

   procedure Begin_Edit
     (Model : in out Window_Model;
      Draft : Files.Settings.Settings_Draft)
   is
      Normalized_Draft : Files.Settings.Settings_Draft := Draft;
   begin
      Touch (Model);
      Normalize_Settings_Draft (Normalized_Draft);
      Model.Settings_Draft_Value := Normalized_Draft;
      Model.Settings_Pane_Open := True;
      Claim_Overlay_Input (Model);
      Clear_Edit_State (Model);
      Clear_Root_Selector_State (Model);
      Model.Command_Palette.Open := False;
      Guikit.Command_Palette.Reset (Model.Command_Palette.View);
      Reset_Settings_Panel (Model);
      Model.Focus_Value := Files.Types.Focus_Settings_Input;
   end Begin_Edit;

   function Draft_Of
     (Model : Window_Model)
      return Files.Settings.Settings_Draft is
     (Model.Settings_Draft_Value);

   procedure Set_Draft
     (Model : in out Window_Model;
      Draft : Files.Settings.Settings_Draft)
   is
      Normalized_Draft : Files.Settings.Settings_Draft := Draft;
   begin
      Touch (Model);
      Normalize_Settings_Draft (Normalized_Draft);
      Model.Settings_Draft_Value := Normalized_Draft;
   end Set_Draft;

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

   procedure Visit
     (Model  : in out Window_Model;
      Config : Guikit.Settings_Panel.Configuration;
      Fields : Guikit.Settings_Panel.Field_Vectors.Vector;
      Draw   : not null access procedure (Panel : in out Guikit.Settings_Panel.Panel)) is
   begin
      Guikit.Settings_Panel.Set_Configuration (Model.Settings_Panel_View, Config);
      Guikit.Settings_Panel.Set_Fields (Model.Settings_Panel_View, Fields);
      Draw (Model.Settings_Panel_View);
   end Visit;

   function Panel_Capturing (Model : Window_Model) return Boolean is
     (Guikit.Settings_Panel.Is_Capturing (Model.Settings_Panel_View));

   procedure Cancel_Capture (Model : in out Window_Model) is
   begin
      Touch (Model);
      Guikit.Settings_Panel.Cancel_Capture (Model.Settings_Panel_View);
   end Cancel_Capture;

end Files.Model.Settings_Pane;
