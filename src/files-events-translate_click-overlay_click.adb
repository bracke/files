separate (Files.Events.Translate_Click)
--  The modal overlays, top-most first: each takes a click it can use and swallows the rest.
procedure Overlay_Click (Handled : out Boolean; Result : out Input_Action) is
begin
   Handled := True;
   --  The paste-progress overlay is a modal-lite top-most panel: while a long
   --  copy/move runs, a click either hits its Cancel button or is swallowed so
   --  nothing behind it reacts.
   if Snapshot.Paste_Progress_Open then
      declare
         use type Files.Rendering.Conflict_Hit_Kind;
         Hit : constant Files.Rendering.Conflict_Hit_Region :=
           Files.Rendering.Hit.Conflict_Hit_At (Frame, X, Y);
      begin
         if Hit.Kind = Files.Rendering.Conflict_Hit_Progress_Cancel then
            Result := Paste_Cancel_Action (Activate);
            return;
         end if;
         Result := No_Action (Activate);
         return;
      end;
   end if;

   --  The paste-conflict dialog is a top-most modal: while it is open it
   --  consumes every click, either resolving to one of its controls or being
   --  swallowed so nothing behind it reacts.
   if Snapshot.Paste_Conflict_Open then
      declare
         use type Files.Rendering.Conflict_Hit_Kind;
         Hit    : constant Files.Rendering.Conflict_Hit_Region :=
           Files.Rendering.Hit.Conflict_Hit_At (Frame, X, Y);
         Dialog : constant Files.Rendering.Conflict_Dialog_Layout :=
           Files.Rendering.Calculate_Conflict_Dialog_Layout (Snapshot, Layout, Line_Height);
      begin
         case Hit.Kind is
            when Files.Rendering.Conflict_Hit_Replace =>
               Result := Conflict_Action (Conflict_Button_Replace, Activate);
               return;
            when Files.Rendering.Conflict_Hit_Skip =>
               Result := Conflict_Action (Conflict_Button_Skip, Activate);
               return;
            when Files.Rendering.Conflict_Hit_Rename =>
               Result := Conflict_Action (Conflict_Button_Rename, Activate);
               return;
            when Files.Rendering.Conflict_Hit_Cancel =>
               Result := Conflict_Action (Conflict_Button_Cancel, Activate);
               return;
            when Files.Rendering.Conflict_Hit_Apply_All =>
               Result := Conflict_Action (Conflict_Button_Apply_All, Activate);
               return;
            when Files.Rendering.Conflict_Hit_None
               | Files.Rendering.Conflict_Hit_Progress_Cancel =>
               if Close_Button_Hit (Dialog.X, Dialog.Y, Dialog.Width, Dialog.Height) then
                  Result := Conflict_Action (Conflict_Button_Cancel, Activate);
                  return;
               end if;
               Result := No_Action (Activate);
               return;
         end case;
      end;
   end if;

   --  The Quick Look overlay is a modal-lite top-most panel: a click on its
   --  close button or anywhere outside the panel toggles it shut, and a click
   --  inside the panel body is swallowed so nothing behind it reacts.
   if Snapshot.Quick_Look_Open then
      declare
         QL : constant Files.Rendering.Quick_Look_Layout :=
           Files.Rendering.Calculate_Quick_Look_Layout (Layout, Line_Height);
      begin
         if Close_Button_Hit (QL.X, QL.Y, QL.Width, QL.Height)
           or else not (Within (X, QL.X, QL.Width) and then Within (Y, QL.Y, QL.Height))
         then
            Result := Command_Action (Files.Commands.Toggle_Quick_Look_Command, Activate);
            return;
         end if;
         Result := No_Action (Activate);
         return;
      end;
   end if;

   --  The color-label picker is a modal-lite top-most panel: a swatch click
   --  chooses that label, the close button or a click outside the panel closes
   --  it, and a click inside the body is swallowed.
   if Snapshot.Label_Picker_Open then
      declare
         Picker : constant Files.Rendering.Label_Picker_Layout :=
           Files.Rendering.Calculate_Label_Picker_Layout (Layout, Line_Height);
      begin
         for Index in Picker.Swatches'Range loop
            declare
               Swatch : constant Files.Rendering.Label_Swatch_Bounds :=
                 Picker.Swatches (Index);
            begin
               if Within (X, Swatch.X, Swatch.Width)
                 and then Within (Y, Swatch.Y, Swatch.Height)
               then
                  Result := Label_Choice_Action
                    (Files.Types.Color_Label'Pos
                       (Files.Rendering.Label_For_Swatch (Index)),
                     Activate);
                  return;
               end if;
            end;
         end loop;
         if Close_Button_Hit (Picker.X, Picker.Y, Picker.Width, Picker.Height)
           or else not (Within (X, Picker.X, Picker.Width)
                        and then Within (Y, Picker.Y, Picker.Height))
         then
            Result := Command_Action (Files.Commands.Close_Command_Palette_Command, Activate);
            return;
         end if;
         Result := No_Action (Activate);
         return;
      end;
   end if;

   --  Route and contain panels in visual ownership order. A modal overlay
   --  must get first refusal before any lower panel's close button, rows, or
   --  chrome are tested; otherwise a click can mutate a surface behind it.
   if Snapshot.Command_Palette_Open
     and then Close_Button_Hit
       (Palette_Layout.X, Palette_Layout.Y, Palette_Layout.Width, Palette_Layout.Height)
   then
      Result := Command_Action (Files.Commands.Close_Command_Palette_Command, Activate);
      return;
   end if;

   --  Any click inside the open palette becomes a palette click carrying the
   --  coordinates; Guikit.Command_Palette hit-tests it (a search-box or gap
   --  click resolves to no row). Clicks outside dismiss nothing here.
   if Snapshot.Command_Palette_Open then
      if Within (X, Palette_Layout.X, Palette_Layout.Width)
        and then Within (Y, Palette_Layout.Y, Palette_Layout.Height)
      then
         Result :=
           (Kind     => Command_Result_Click_Input_Action,
            Click_X  => X,
            Click_Y  => Y,
            Activate => Activate,
            others   => <>);
         return;
      else
         Result := No_Action (Activate);
         return;
      end if;
   end if;

   if Snapshot.Settings_Pane_Open
     and then Close_Button_Hit
       (Settings_Pane.X, Settings_Pane.Y, Settings_Pane.Width, Settings_Pane.Height)
   then
      Result := Command_Action (Files.Commands.Toggle_Settings_Pane_Command, Activate);
      return;
   end if;

   declare
      Hit : constant Input_Action := Settings_Click_Hit;
   begin
      if Hit.Kind /= No_Input_Action then
         Result := Hit;
         return;
      elsif Snapshot.Settings_Pane_Open then
         Result := No_Action (Activate);
         return;
      end if;
   end;

   if Snapshot.Root_Selector_Open
     and then Close_Button_Hit
       (Root_Layout.X, Root_Layout.Y, Root_Layout.Width, Root_Layout.Height)
   then
      Result := Command_Action (Files.Commands.Close_Command_Palette_Command, Activate);
      return;
   end if;

   if Root_Index /= 0 then
      Result :=
        (Kind       => Root_Click_Input_Action,
         Root_Index => Root_Index,
         Activate   => Activate,
         others     => <>);
      return;
   elsif Snapshot.Root_Selector_Open then
      declare
         Root_Command : constant Files.Commands.Command_Id :=
           Files.Rendering.Hit.Toolbar_Command_At (X, Y, Width, Line_Height);
      begin
         if Root_Command = Files.Commands.Select_Drive_Command then
            Result := Command_Action (Root_Command, Activate);
            return;
         elsif Within (X, Root_Layout.X, Root_Layout.Width)
           and then Within (Y, Root_Layout.Y, Root_Layout.Height)
         then
            Result := No_Action (Activate);
            return;
         end if;
      end;
      Result := Command_Action (Files.Commands.Close_Command_Palette_Command, Activate);
      return;
   end if;
   Handled := False;
   Result := No_Action (Activate);
end Overlay_Click;
