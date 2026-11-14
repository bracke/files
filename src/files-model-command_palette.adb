with Files.Command_Palette;
with Guikit.Layout;
with Files.Model.Support;

package body Files.Model.Command_Palette is

   use Ada.Strings.Unbounded;
   use Files.Model.Support;

   --  The presentation config for the command palette (overlay with shortcuts,
   --  the component owns the filtering).
   --
   --  @param Line_Height Row height in pixels.
   --  @param Title The heading, in the current language ("" for none yet:
   --    Files.Overlays supplies it when it draws).
   --  @param Empty_State What shows when no command matches.
   --  @param Close_Label The close button's accessible name, in the current
   --    language ("" for none yet: Files.Overlays supplies it when it draws).
   --  @return Command-palette component configuration.
   function Palette_Config
     (Line_Height : Positive;
      Title       : String := "";
      Empty_State : String := "";
      Close_Label : String := "") return Guikit.Command_Palette.Configuration is
     (Line_Height    => Line_Height,
      Show_Icons     => False,
      Show_Shortcuts => True,
      Overlay        => True,
      Wrap_Selection => True,
      Placeholder    => Null_Unbounded_String,
      Empty_State    => To_Unbounded_String (Empty_State),
      Title          => To_Unbounded_String (Title),
      Close_Label    => To_Unbounded_String (Close_Label));

   procedure Open
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      Model.Command_Palette.Open := True;
      Model.Command_Palette.Mode := Palette_Commands;
      Model.Command_Palette.Open_With_Targets.Clear;
      Model.Command_Palette.Open_With_Applications.Clear;
      Claim_Overlay_Input (Model);
      --  At the reference line height; Visit sets the window's
      --  real one.
      Guikit.Command_Palette.Set_Configuration
        (Model.Command_Palette.View, Palette_Config (Guikit.Layout.Reference_Line_Height));
      Guikit.Command_Palette.Reset (Model.Command_Palette.View);
      Guikit.Command_Palette.Set_Commands
        (Model.Command_Palette.View, Files.Command_Palette.Commands (Model));
      Model.Focus_Value := Files.Types.Focus_Command_Palette;
   end Open;

   procedure Close
     (Model : in out Window_Model)
     renames Files.Model.Support.Close_Command_Palette;

   procedure Toggle
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      if Model.Command_Palette.Open then
         Close (Model);
      else
         Open (Model);
      end if;
   end Toggle;

   function Is_Open
     (Model : Window_Model)
      return Boolean is
     (Model.Command_Palette.Open);

   function Query (Model : Window_Model) return String is
     (Guikit.Command_Palette.Query (Model.Command_Palette.View));

   procedure Set_Query (Model : in out Window_Model; Text : String) is
   begin
      Touch (Model);
      Guikit.Command_Palette.Set_Query (Model.Command_Palette.View, Text);
   end Set_Query;

   procedure Move_Selection (Model : in out Window_Model; Delta_Rows : Integer) is
   begin
      Touch (Model);
      Guikit.Command_Palette.Move_Selection (Model.Command_Palette.View, Delta_Rows);
   end Move_Selection;

   procedure Select_First (Model : in out Window_Model) is
   begin
      Touch (Model);
      Guikit.Command_Palette.Select_First (Model.Command_Palette.View);
   end Select_First;

   procedure Select_Last (Model : in out Window_Model) is
   begin
      Touch (Model);
      Guikit.Command_Palette.Select_Last (Model.Command_Palette.View);
   end Select_Last;

   procedure Page (Model : in out Window_Model; Down : Boolean) is
   begin
      Touch (Model);
      Guikit.Command_Palette.Page (Model.Command_Palette.View, Down);
   end Page;

   function Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean is
      Clicked : constant Boolean :=
        Guikit.Command_Palette.Click (Model.Command_Palette.View, X, Y);
   begin
      if Clicked then
         Touch (Model);
      end if;
      return Clicked;
   end Click;

   function Selected_Id (Model : Window_Model) return Natural is
     (Guikit.Command_Palette.Selected_Id (Model.Command_Palette.View));

   function Result_Count (Model : Window_Model) return Natural is
     (Guikit.Command_Palette.Result_Count (Model.Command_Palette.View));

   function Mode_Of
     (Model : Window_Model)
      return Palette_Mode is
     (Model.Command_Palette.Mode);

   procedure Set_Mode
     (Model : in out Window_Model;
      Mode  : Palette_Mode) is
   begin
      Touch (Model);
      Model.Command_Palette.Mode := Mode;
      --  The command list is mode-specific; reload it and reset the query.
      Guikit.Command_Palette.Reset (Model.Command_Palette.View);
      Guikit.Command_Palette.Set_Commands
        (Model.Command_Palette.View, Files.Command_Palette.Commands (Model));
   end Set_Mode;

   procedure Set_Open_With_Targets
     (Model   : in out Window_Model;
      Targets : Files.Types.String_Vectors.Vector) is
   begin
      Touch (Model);
      Model.Command_Palette.Open_With_Targets := Targets;
   end Set_Open_With_Targets;

   function Open_With_Targets
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
     (Model.Command_Palette.Open_With_Targets);

   procedure Set_Open_With_Applications
     (Model        : in out Window_Model;
      Applications : Files.Desktop_Applications.Application_Vectors.Vector) is
   begin
      Touch (Model);
      Model.Command_Palette.Open_With_Applications := Applications;
   end Set_Open_With_Applications;

   function Open_With_Applications
     (Model : Window_Model)
      return Files.Desktop_Applications.Application_Vectors.Vector is
     (Model.Command_Palette.Open_With_Applications);

   procedure Focus_Input
     (Model : in out Window_Model) is
   begin
      Touch (Model);
      if Model.Command_Palette.Open then
         Reset_Type_Ahead (Model);
         Model.Focus_Value := Files.Types.Focus_Command_Palette;
      end if;
   end Focus_Input;

   procedure Visit
     (Model       : in out Window_Model;
      Line_Height : Positive;
      Title       : String;
      Empty_State : String;
      Close_Label : String;
      Draw        : not null access procedure (Palette : in out Guikit.Command_Palette.Palette)) is
   begin
      --  The component keeps the query and selection across these.
      Guikit.Command_Palette.Set_Configuration
        (Model.Command_Palette.View, Palette_Config (Line_Height, Title, Empty_State, Close_Label));
      if Model.Command_Palette.Listed_Revision /= Model.Revision_Value then
         Guikit.Command_Palette.Set_Commands
           (Model.Command_Palette.View, Files.Command_Palette.Commands (Model));
         Model.Command_Palette.Listed_Revision := Model.Revision_Value;
      end if;
      Draw (Model.Command_Palette.View);
   end Visit;

end Files.Model.Command_Palette;
