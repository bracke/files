separate (Files.Controller.Handle_Key)
--  Tab / Shift+Tab cycle keyboard focus around the main-view controls:
--  grid -> path input -> filter -> folder tree (when open) -> grid, and
--  Shift+Tab reverses. Each field
--  keeps its direct shortcut (Ctrl+L, Ctrl+F, Escape back to the grid); this
--  adds the conventional ring. Only these three focus states take part --
--  rename, palette, settings and ownership focus have their own handling,
--  and the settings pane's Ctrl+Tab is untouched (this ignores Ctrl/Alt).
procedure Focus_Ring_Key (Handled : out Boolean; Result : out Controller_Result) is
begin
   Handled := True;
   if Key = Guikit.Input.Key_Tab
     and then not Modifiers (Guikit.Input.Control_Key)
     and then not Modifiers (Guikit.Input.Alt_Key)
     and then Files.Model.Focus (Model) in
       Files.Types.Focus_None
         | Files.Types.Focus_Path_Input
         | Files.Types.Focus_Filter_Input
   then
      declare
         Backward : constant Boolean := Modifiers (Guikit.Input.Shift_Key);
         --  The tree joins the ring only while it is shown and has rows.
         Tree_Takes_Keyboard : constant Boolean :=
           Files.Model.Tree_Panel_Is_Open (Model)
           and then not Files.Model.Tree_Pick_Is_Active (Model)
           and then not Files.Model.Tree_Visible_Rows (Model).Is_Empty;
      begin
         case Files.Model.Focus (Model) is
            when Files.Types.Focus_None =>
               if Files.Model.Tree_Has_Keyboard (Model) then
                  if Backward then
                     Files.Model.Focus_Filter_Input (Model);
                  else
                     Files.Model.Take_Tree_Keyboard (Model);
                  end if;
               elsif Backward then
                  if Tree_Takes_Keyboard then
                     Files.Model.Give_Tree_Keyboard (Model);
                  else
                     Files.Model.Focus_Filter_Input (Model);
                  end if;
               else
                  Files.Model.Focus_Path_Input (Model);
               end if;
            when Files.Types.Focus_Path_Input =>
               if Backward then
                  Files.Model.Cancel_Focus_Or_Edit (Model);
               else
                  Files.Model.Focus_Filter_Input (Model);
               end if;
            when Files.Types.Focus_Filter_Input =>
               if Backward then
                  Files.Model.Focus_Path_Input (Model);
               else
                  Files.Model.Cancel_Focus_Or_Edit (Model);
                  if Tree_Takes_Keyboard then
                     Files.Model.Give_Tree_Keyboard (Model);
                  end if;
               end if;
            when others =>
               null;
         end case;
         Result := Make_Result (Controller_Text_Updated);
         return;
      end;
   end if;
   Handled := False;
   Result := Make_Result (Controller_Ignored);
end Focus_Ring_Key;
