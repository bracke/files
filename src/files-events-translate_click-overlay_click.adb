with Files.Commands.Overlay_Buttons;
with Files.Rendering.Layouts;
separate (Files.Events.Translate_Click)
--  The overlay on top (Files.Rendering.Topmost_Overlay_Position, the order
--  the keyboard and the drawing follow too) takes a click it can use and
--  swallows the rest, so nothing behind it reacts. The sort menu and the
--  tree pick have regions of their own further on.
procedure Overlay_Click (Handled : out Boolean; Result : out Input_Action) is

   Position : constant Natural := Files.Rendering.Topmost_Overlay_Position (Snapshot);

   --  What the top overlay's close button, or a click outside it, runs:
   --  the command the interaction layer admits for it
   --  (Files.Commands.Overlay_Buttons).
   function Dismiss return Input_Action is
     (Command_Action (Files.Commands.Overlay_Buttons.Dismiss_Command (Files.UI_Types.Overlay_Stack (Position))));

   --  The paste-progress overlay is a modal-lite top-most panel: while a long
   --  copy/move runs, a click either hits its Cancel button or is swallowed.
   function Progress_Click return Input_Action is
      use type Files.Rendering.Dialog_Hit_Kind;
   begin
      if Files.Rendering.Hit.Dialog_Hit_At (Frame, X, Y).Kind = Files.Rendering.Dialog_Hit_Progress_Cancel then
         return Foreground_Job_Cancel_Action;
      end if;
      return No_Action;
   end Progress_Click;

   --  The paste-conflict dialog consumes every click, either resolving to one
   --  of its controls or being swallowed.
   function Conflict_Click return Input_Action is
   begin
      case Files.Rendering.Hit.Dialog_Hit_At (Frame, X, Y).Kind is
         when Files.Rendering.Dialog_Hit_Replace =>
            return Conflict_Action (Conflict_Button_Replace);
         when Files.Rendering.Dialog_Hit_Skip =>
            return Conflict_Action (Conflict_Button_Skip);
         when Files.Rendering.Dialog_Hit_Rename =>
            return Conflict_Action (Conflict_Button_Rename);
         when Files.Rendering.Dialog_Hit_Cancel | Files.Rendering.Dialog_Hit_Conflict_Close =>
            return Conflict_Action (Conflict_Button_Cancel);
         when Files.Rendering.Dialog_Hit_Apply_All =>
            return Conflict_Action (Conflict_Button_Apply_All);
         when Files.Rendering.Dialog_Hit_None
            | Files.Rendering.Dialog_Hit_Progress_Cancel =>
            return No_Action;
      end case;
   end Conflict_Click;

   --  Quick Look: a click on its close button or anywhere outside the panel
   --  toggles it shut, and a click inside the panel body is swallowed.
   function Quick_Look_Click return Input_Action is
      QL : constant Files.Rendering.Layouts.Quick_Look_Layout :=
        Files.Rendering.Layouts.Calculate_Quick_Look_Layout (Layout, Line_Height);
   begin
      if Close_Button_Hit (QL.Close_Button)
        or else not (Within (X, QL.X, QL.Width) and then Within (Y, QL.Y, QL.Height))
      then
         return Dismiss;
      end if;
      return No_Action;
   end Quick_Look_Click;

   --  The color-label picker: a swatch click chooses that label, the close
   --  button or a click outside the panel closes it, and a click inside the
   --  body is swallowed.
   function Label_Picker_Click return Input_Action is
      Picker : constant Files.Rendering.Layouts.Label_Picker_Layout :=
        Files.Rendering.Layouts.Calculate_Label_Picker_Layout (Layout, Line_Height);
   begin
      for Index in Picker.Swatches'Range loop
         declare
            Swatch : constant Files.Rendering.Layouts.Label_Swatch_Bounds := Picker.Swatches (Index);
         begin
            if Within (X, Swatch.X, Swatch.Width) and then Within (Y, Swatch.Y, Swatch.Height) then
               return Label_Choice_Action (Files.UI_Types.Label_For_Swatch (Index));
            end if;
         end;
      end loop;
      if Close_Button_Hit (Picker.Close_Button)
        or else not (Within (X, Picker.X, Picker.Width) and then Within (Y, Picker.Y, Picker.Height))
      then
         return Dismiss;
      end if;
      return No_Action;
   end Label_Picker_Click;

   --  The palette: its close button closes it; any other click inside it
   --  becomes a palette click carrying the coordinates, which
   --  Guikit.Command_Palette hit-tests (a search-box or gap click resolves to
   --  no row). Clicks outside dismiss nothing.
   function Palette_Click return Input_Action is
      Palette_Layout : constant Files.Rendering.Layouts.Command_Palette_Layout :=
        Files.Rendering.Layouts.Calculate_Command_Palette_Layout (Layout, Line_Height);
   begin
      if Close_Button_Hit (Palette_Layout.X, Palette_Layout.Y, Palette_Layout.Width, Palette_Layout.Height) then
         return Dismiss;
      elsif Within (X, Palette_Layout.X, Palette_Layout.Width)
        and then Within (Y, Palette_Layout.Y, Palette_Layout.Height)
      then
         return (Kind => Command_Result_Click_Input_Action, Click_X => X, Click_Y => Y);
      end if;
      return No_Action;
   end Palette_Click;

   --  The settings pane: its close button closes it; any other click inside
   --  it becomes a settings click carrying the coordinates, which
   --  Guikit.Settings_Panel hit-tests (focusing, toggling, choosing, stepping
   --  or pressing a button); one outside is swallowed.
   function Settings_Pane_Click return Input_Action is
      Settings_Pane : constant Guikit.Layout.Settings_Pane_Layout :=
        Files.Rendering.Layouts.Settings_Pane_Region (Layout, Line_Height);
   begin
      if Close_Button_Hit (Settings_Pane.X, Settings_Pane.Y, Settings_Pane.Width, Settings_Pane.Height) then
         return Dismiss;
      elsif Within (X, Settings_Pane.X, Settings_Pane.Width) and then Within (Y, Settings_Pane.Y, Settings_Pane.Height)
      then
         return (Kind => Settings_Click_Input_Action, Click_X => X, Click_Y => Y);
      end if;
      return No_Action;
   end Settings_Pane_Click;

   --  The root selector: its close button closes it, a row opens that root,
   --  the toolbar's drive button toggles it, a click elsewhere inside it is
   --  swallowed, and one outside it closes it.
   function Root_Selector_Click return Input_Action is
      Root_Layout : constant Files.Rendering.Layouts.Root_Selector_Layout :=
        Files.Rendering.Layouts.Calculate_Root_Selector_Layout (Snapshot, Layout, Line_Height);
      Root_Index  : constant Natural :=
        Files.Rendering.Hit.Root_Path_At
          (Files.Rendering.Layouts.Calculate_Root_Path_Layout (Snapshot, Root_Layout), X, Y);
   begin
      if Close_Button_Hit (Root_Layout.Close_Button) then
         return Dismiss;
      elsif Root_Index /= 0 then
         return (Kind => Root_Click_Input_Action, Root_Index => Root_Index);
      elsif Files.Rendering.Hit.Toolbar_Command_At (X, Y, Width, Line_Height)
        = Files.Commands.Select_Drive_Command
      then
         return Command_Action (Files.Commands.Select_Drive_Command);
      elsif Within (X, Root_Layout.X, Root_Layout.Width) and then Within (Y, Root_Layout.Y, Root_Layout.Height) then
         return No_Action;
      end if;
      return Dismiss;
   end Root_Selector_Click;

   --  The context menu: a row runs its command, a click on its padding or a
   --  separator is swallowed, and one outside it closes it.
   function Context_Menu_Click return Input_Action is
      Menu : constant Files.Rendering.Layouts.Context_Menu_Layout :=
        Files.Rendering.Layouts.Calculate_Context_Menu_Layout (Snapshot, Width, Height, Line_Height);
      Row  : constant Natural := Files.Rendering.Hit.Context_Menu_Row_At (Menu, X, Y);
   begin
      if Row in 1 .. Menu.Row_Count then
         return (Kind => Context_Menu_Command_Input_Action, Menu_Command => Menu.Rows (Row).Command);
      elsif Files.Rendering.Hit.Context_Menu_Contains (Menu, X, Y) then
         return No_Action;
      end if;
      return Dismiss;
   end Context_Menu_Click;
begin
   Handled := Position /= 0;
   Result := No_Action;
   if not Handled then
      return;
   end if;
   case Files.UI_Types.Overlay_Stack (Position) is
      when Files.UI_Types.Foreground_Job_Overlay  => Result := Progress_Click;
      when Files.UI_Types.Paste_Conflict_Overlay  => Result := Conflict_Click;
      when Files.UI_Types.Command_Palette_Overlay => Result := Palette_Click;
      when Files.UI_Types.Settings_Pane_Overlay   => Result := Settings_Pane_Click;
      when Files.UI_Types.Root_Selector_Overlay   => Result := Root_Selector_Click;
      when Files.UI_Types.Label_Picker_Overlay    => Result := Label_Picker_Click;
      when Files.UI_Types.Quick_Look_Overlay      => Result := Quick_Look_Click;
      when Files.UI_Types.Context_Menu_Overlay    => Result := Context_Menu_Click;
      when Files.UI_Types.Sort_Menu_Overlay
         | Files.UI_Types.Tree_Pick_Overlay       =>
         Handled := False;
   end case;
end Overlay_Click;
