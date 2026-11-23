with Files.Text_Case;
with Files.UI_Types;
with Guikit.Layout;
with Files.Model.Support;

package body Files.Model.Command_Palette is

   use Ada.Strings.Unbounded;
   use Files.Model.Support;

   function Is_Listed
     (Model : Window_Model)
      return Boolean is
     (Model.Command_Palette.Listed_Revision = Model.Revision_Value);

   procedure List
     (Model    : in out Window_Model;
      Commands : Guikit.Command_Palette.Command_Vectors.Vector) is
   begin
      Guikit.Command_Palette.Set_Commands (Model.Command_Palette.View, Commands);
      Model.Command_Palette.Listed_Revision := Model.Revision_Value;
   end List;

   function Selected_Command
     (Model : Window_Model)
      return Files.Commands.Command_Id
   is
      Id : constant Natural := Guikit.Command_Palette.Selected_Id (Model.Command_Palette.View);
   begin
      if Model.Command_Palette.Mode /= Palette_Commands
        or else Id > Files.Commands.Command_Id'Pos (Files.Commands.Command_Id'Last)
      then
         return Files.Commands.No_Command;
      end if;
      return Files.Commands.Command_Id'Val (Id);
   end Selected_Command;

   procedure Relist
     (Model : in out Window_Model) is
   begin
      --  A new revision is not the one listed (Is_Listed), and the window
      --  layer rebuilds an overlay whose model moved.
      Touch_Header (Model);
   end Relist;

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
      Touch_Header (Model);
      Model.Command_Palette.Open := True;
      Model.Command_Palette.Mode := Palette_Commands;
      Model.Command_Palette.Open_With_Targets.Clear;
      Model.Command_Palette.Open_With_Applications.Clear;
      Claim_Overlay_Input (Model);
      --  At the reference line height; With_Panel sets the window's
      --  real one.
      Guikit.Command_Palette.Set_Configuration
        (Model.Command_Palette.View, Palette_Config (Guikit.Layout.Reference_Line_Height));
      Guikit.Command_Palette.Reset (Model.Command_Palette.View);
      --  Every script's letters, as the filter bar folds them: guikit's own
      --  folding knows ASCII and Latin-1 only.
      Guikit.Command_Palette.Set_Folding (Model.Command_Palette.View, Files.Text_Case.Fold_Case'Access);
      --  Nothing from an earlier opening -- another mode's rows -- stays
      --  listed: a choice is resolved only against a list handed over
      --  since (List).
      Guikit.Command_Palette.Set_Commands
        (Model.Command_Palette.View, Guikit.Command_Palette.Command_Vectors.Empty_Vector);
      Model.Focus_Value := Files.UI_Types.Focus_Command_Palette;
   end Open;

   procedure Close
     (Model : in out Window_Model)
     renames Files.Model.Support.Close_Command_Palette;

   procedure Toggle
     (Model : in out Window_Model) is
   begin
      Touch_Header (Model);
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
      Touch_Overlay (Model);
      Guikit.Command_Palette.Set_Query (Model.Command_Palette.View, Text);
   end Set_Query;

   procedure Move_Selection (Model : in out Window_Model; Delta_Rows : Integer) is
   begin
      Touch_Overlay (Model);
      Guikit.Command_Palette.Move_Selection (Model.Command_Palette.View, Delta_Rows);
   end Move_Selection;

   procedure Select_First (Model : in out Window_Model) is
   begin
      Touch_Overlay (Model);
      Guikit.Command_Palette.Select_First (Model.Command_Palette.View);
   end Select_First;

   procedure Select_Last (Model : in out Window_Model) is
   begin
      Touch_Overlay (Model);
      Guikit.Command_Palette.Select_Last (Model.Command_Palette.View);
   end Select_Last;

   procedure Page (Model : in out Window_Model; Down : Boolean) is
   begin
      Touch_Overlay (Model);
      Guikit.Command_Palette.Page (Model.Command_Palette.View, Down);
   end Page;

   function Click (Model : in out Window_Model; X : Integer; Y : Integer) return Boolean is
      Clicked : constant Boolean :=
        Guikit.Command_Palette.Click (Model.Command_Palette.View, X, Y);
   begin
      if Clicked then
         Touch_Overlay (Model);
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

   procedure Open_With
     (Model        : in out Window_Model;
      Targets      : Files.Types.String_Vectors.Vector;
      Applications : Files.Desktop_Application_Types.Application_Vectors.Vector) is
   begin
      --  Open resets the mode and the stored lists: set them after it.
      Open (Model);
      Model.Command_Palette.Mode := Palette_Open_With;
      Model.Command_Palette.Open_With_Targets := Targets;
      Model.Command_Palette.Open_With_Applications := Applications;
   end Open_With;

   function Open_With_Targets
     (Model : Window_Model)
      return Files.Types.String_Vectors.Vector is
     (Model.Command_Palette.Open_With_Targets);

   function Open_With_Applications
     (Model : Window_Model)
      return Files.Desktop_Application_Types.Application_Vectors.Vector is
     (Model.Command_Palette.Open_With_Applications);

   procedure Focus_Input
     (Model : in out Window_Model) is
   begin
      Touch_Header (Model);
      if Model.Command_Palette.Open then
         Reset_Type_Ahead (Model);
         Model.Focus_Value := Files.UI_Types.Focus_Command_Palette;
      end if;
   end Focus_Input;

   procedure With_Panel
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
      Draw (Model.Command_Palette.View);
   end With_Panel;

end Files.Model.Command_Palette;
